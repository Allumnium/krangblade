extends Node
## Persistent ENet session. All RPC endpoints live here, not on changing scenes.
## The host is authoritative for lobby, load barrier, and territory ownership.

signal phase_changed
signal roster_changed
signal chat_changed
signal status_changed
signal owners_changed
signal economy_changed

const RULES = preload("res://scripts/lobby_rules.gd")
const ECONOMY = preload("res://scripts/economy_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")
const SIM_STEP: float = 0.1
const SNAPSHOT_INTERVAL: float = 0.2
const PORT: int = 24567
const MAX_CHAT: int = 250
const CHAT_HISTORY: int = 100
const LOAD_TIMEOUT_SECONDS: float = 20.0

var phase: String = "offline" # offline / connecting / lobby / loading / match
var status: String = ""
var display_name: String = "Player"
var players: Dictionary = {}
var history: Array[Dictionary] = []
var last_message: Dictionary = {}
var owners: Array[int] = []
var economy: Dictionary = {}
var is_solo: bool = false
var round_id: int = 0
var loaded: Dictionary = {}
var load_timer: Timer
var economy_timer: Timer
var snapshot_elapsed: float = 0.0
var resource_history: Dictionary = {}

func _ready() -> void:
    multiplayer.peer_connected.connect(_peer_connected)
    multiplayer.peer_disconnected.connect(_peer_disconnected)
    multiplayer.connected_to_server.connect(_connected)
    multiplayer.connection_failed.connect(_connection_failed)
    multiplayer.server_disconnected.connect(_server_disconnected)
    load_timer = Timer.new()
    load_timer.one_shot = true
    load_timer.wait_time = LOAD_TIMEOUT_SECONDS
    load_timer.timeout.connect(_load_timed_out)
    add_child(load_timer)
    economy_timer = Timer.new()
    economy_timer.wait_time = SIM_STEP
    economy_timer.timeout.connect(_economy_tick)
    add_child(economy_timer)

func _set_phase(value: String) -> void:
    if phase != value:
        phase = value
        phase_changed.emit()

func _status(value: String) -> void:
    status = value
    status_changed.emit()

func _sanitize_name(value: String) -> String:
    var clean: String = value.replace("\n", " ").replace("\r", " ").strip_edges().substr(0, 24)
    return clean if not clean.is_empty() else "Player"

## Solo runs the same authoritative match simulation as a host, with no ENet peer.
func start_solo(team: int = 1, opponent_teams: Array = []) -> bool:
    if phase != "offline":
        return false
    if not RULES.valid_team(team) or opponent_teams.size() > RULES.MAX_PLAYERS - 1:
        return false
    for opponent_team in opponent_teams:
        if not RULES.valid_team(int(opponent_team)):
            return false
    is_solo = true
    players = {1: {"name": _sanitize_name(display_name), "team": team, "ready": true}}
    for i in range(opponent_teams.size()):
        players[i + 2] = {"name": "AI %d" % (i + 1), "team": int(opponent_teams[i]), "ready": true, "ai": true}
    history.clear()
    last_message.clear()
    round_id = 1
    _activate_match(players, int(randi()))
    get_tree().call_deferred("change_scene_to_file", "res://scenes/match.tscn")
    return true

func leave_solo() -> void:
    if not is_solo or phase != "match":
        return
    _reset_network()
    _status("")
    get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func host_game(wanted_name: String) -> bool:
    if phase != "offline":
        return false
    var peer := ENetMultiplayerPeer.new()
    var err: int = peer.create_server(PORT, RULES.MAX_PLAYERS - 1, 2)
    if err != OK:
        _status("Could not host (error %d). Check UDP %d." % [err, PORT])
        return false
    multiplayer.multiplayer_peer = peer
    is_solo = false
    display_name = _sanitize_name(wanted_name)
    players = {1: {"name": display_name, "team": 1, "ready": true}}
    history.clear()
    last_message.clear()
    round_id = 0
    owners.clear()
    _set_phase("lobby")
    _status("Waiting for players (2–8 required to start).")
    roster_changed.emit()
    chat_changed.emit()
    return true

func join_game(wanted_name: String, address: String) -> bool:
    if phase != "offline":
        return false
    var ip: String = address.strip_edges()
    if ip.is_empty():
        _status("Enter the host IP address.")
        return false
    var peer := ENetMultiplayerPeer.new()
    var err: int = peer.create_client(ip, PORT, 2)
    if err != OK:
        _status("Could not connect (error %d)." % err)
        return false
    multiplayer.multiplayer_peer = peer
    is_solo = false
    display_name = _sanitize_name(wanted_name)
    players.clear()
    history.clear()
    last_message.clear()
    round_id = 0
    owners.clear()
    _set_phase("connecting")
    _status("Connecting to %s:%d..." % [ip, PORT])
    return true

func leave_session() -> void:
    if phase == "offline":
        return
    _reset_network()
    _status("Disconnected.")

func _reset_network() -> void:
    load_timer.stop()
    economy_timer.stop()
    is_solo = false
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    players.clear()
    history.clear()
    last_message.clear()
    loaded.clear()
    owners.clear()
    economy.clear()
    round_id = 0
    _set_phase("offline")
    roster_changed.emit()
    chat_changed.emit()
    owners_changed.emit()
    economy_changed.emit()

func _connected() -> void:
    if phase == "connecting":
        _rpc_register.rpc_id(1, display_name)
        _status("Connected. Joining lobby...")

func _connection_failed() -> void:
    if phase != "offline":
        _reset_network()
        _status("Connection failed. Check the host IP and UDP %d." % PORT)
        get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _server_disconnected() -> void:
    if phase != "offline":
        _reset_network()
        _status("Host disconnected. Returned to menu.")
        get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _peer_connected(peer_id: int) -> void:
    if not multiplayer.is_server():
        return
    if phase != "lobby" or players.size() >= RULES.MAX_PLAYERS:
        var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
        if peer != null:
            peer.disconnect_peer(peer_id)

func _peer_disconnected(peer_id: int) -> void:
    if not multiplayer.is_server() or not players.has(peer_id):
        return
    var name: String = str((players[peer_id] as Dictionary).get("name", "Player"))
    players.erase(peer_id)
    loaded.erase(peer_id)
    last_message.erase(peer_id)
    _send_roster()
    _system_message("%s disconnected." % name)
    if phase == "loading":
        if players.size() < 2:
            _abort_loading("Not enough players to start. Returned to lobby.")
        else:
            _maybe_start_match()
    elif phase == "lobby":
        _status("Waiting for players.")
    elif phase == "match":
        _status("%s disconnected; their territory remains on the map." % name)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_register(wanted_name: String) -> void:
    if not multiplayer.is_server():
        return
    var sender: int = multiplayer.get_remote_sender_id()
    if phase != "lobby" or not multiplayer.get_peers().has(sender):
        return
    if not players.has(sender) and players.size() >= RULES.MAX_PLAYERS:
        return
    if players.has(sender):
        return
    var used_teams: Array[int] = []
    for entry in players.values():
        used_teams.append(int((entry as Dictionary).get("team", 1)))
    var team: int = 1
    while used_teams.has(team) and team < RULES.MAX_PLAYERS:
        team += 1
    var name: String = _sanitize_name(wanted_name)
    players[sender] = {"name": name, "team": team, "ready": false}
    _rpc_history.rpc_id(sender, history)
    _send_roster()
    _system_message("%s joined." % name)
    _status("Waiting for players to ready up.")

func _send_roster() -> void:
    if not multiplayer.is_server():
        return
    _rpc_roster.rpc(players.duplicate(true))
    roster_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rpc_roster(snapshot: Dictionary) -> void:
    if phase == "offline":
        return
    players = snapshot.duplicate(true)
    if phase == "connecting":
        _set_phase("lobby")
        _status("Connected to lobby.")
    roster_changed.emit()

func toggle_ready() -> void:
    if phase != "lobby" or multiplayer.is_server():
        return
    var mine: Dictionary = players.get(multiplayer.get_unique_id(), {})
    if not mine.is_empty():
        _rpc_ready.rpc_id(1, not bool(mine.get("ready", false)))

@rpc("any_peer", "call_remote", "reliable")
func _rpc_ready(value: bool) -> void:
    if not multiplayer.is_server() or phase != "lobby":
        return
    var id: int = multiplayer.get_remote_sender_id()
    if not players.has(id):
        return
    var entry: Dictionary = players[id]
    entry["ready"] = value
    players[id] = entry
    _send_roster()

func choose_team(peer_id: int, team: int) -> void:
    if phase != "lobby" or not RULES.valid_team(team):
        return
    if multiplayer.is_server():
        _change_team(peer_id, team)
    elif peer_id == multiplayer.get_unique_id():
        _rpc_team.rpc_id(1, team)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_team(team: int) -> void:
    if multiplayer.is_server() and phase == "lobby":
        _change_team(multiplayer.get_remote_sender_id(), team)

func _change_team(id: int, team: int) -> void:
    if not players.has(id) or not RULES.valid_team(team):
        return
    var entry: Dictionary = players[id]
    if int(entry.get("team", 0)) == team:
        return
    entry["team"] = team
    players[id] = entry
    RULES.reset_guest_ready(players)
    _send_roster()
    _status("Teams changed; guests must ready up again.")

func send_chat(value: String) -> void:
    if phase != "lobby":
        return
    if multiplayer.is_server():
        _accept_chat(1, value)
    else:
        _rpc_chat_request.rpc_id(1, value)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_chat_request(value: String) -> void:
    if multiplayer.is_server() and phase == "lobby":
        _accept_chat(multiplayer.get_remote_sender_id(), value)

func _accept_chat(sender: int, value: String) -> void:
    if not players.has(sender):
        return
    var now: int = Time.get_ticks_msec()
    if now - int(last_message.get(sender, -100000)) < 650:
        return
    var message: String = value.replace("\n", " ").replace("\r", " ").strip_edges().substr(0, MAX_CHAT)
    if message.is_empty():
        return
    last_message[sender] = now
    var name: String = str((players[sender] as Dictionary).get("name", "Player"))
    _add_chat("%s: %s" % [name, message])

func _system_message(message: String) -> void:
    _add_chat("• " + message)

func _add_chat(message: String) -> void:
    var item: Dictionary = {"text": message}
    _store_chat(item)
    _rpc_chat_item.rpc(item)

func _store_chat(item: Dictionary) -> void:
    history.append(item.duplicate(true))
    if history.size() > CHAT_HISTORY:
        history.pop_front()
    chat_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rpc_chat_item(item: Dictionary) -> void:
    if phase != "offline":
        _store_chat(item)

@rpc("authority", "call_remote", "reliable")
func _rpc_history(items: Array) -> void:
    if phase == "offline":
        return
    history.clear()
    for item in items:
        if item is Dictionary:
            history.append((item as Dictionary).duplicate(true))
    while history.size() > CHAT_HISTORY:
        history.pop_front()
    chat_changed.emit()

func can_start() -> bool:
    return phase == "lobby" and multiplayer.is_server() and RULES.can_start(players)

func start_match() -> void:
    if not can_start():
        return
    round_id += 1
    loaded.clear()
    var snapshot: Dictionary = players.duplicate(true)
    _set_phase("loading")
    _status("Loading match. Waiting for all players...")
    load_timer.start()
    _rpc_prepare.rpc(round_id, snapshot)
    get_tree().call_deferred("change_scene_to_file", "res://scenes/match.tscn")

@rpc("authority", "call_remote", "reliable")
func _rpc_prepare(new_round: int, snapshot: Dictionary) -> void:
    if phase != "lobby" or new_round <= round_id:
        return
    if not snapshot.has(multiplayer.get_unique_id()):
        return
    if not RULES.can_start(snapshot):
        return
    round_id = new_round
    loaded.clear()
    players = snapshot.duplicate(true)
    _set_phase("loading")
    _status("Loading match. Waiting for players...")
    get_tree().call_deferred("change_scene_to_file", "res://scenes/match.tscn")

func match_scene_loaded() -> void:
    if phase != "loading":
        return
    if multiplayer.is_server():
        loaded[1] = true
        _maybe_start_match()
    else:
        _rpc_loaded.rpc_id(1, round_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_loaded(ack_round: int) -> void:
    if not multiplayer.is_server() or phase != "loading" or ack_round != round_id:
        return
    var id: int = multiplayer.get_remote_sender_id()
    if not players.has(id) or not multiplayer.get_peers().has(id):
        return
    loaded[id] = true
    _maybe_start_match()

func _maybe_start_match() -> void:
    if phase != "loading" or not RULES.all_loaded(players, loaded):
        return
    load_timer.stop()
    var snapshot: Dictionary = players.duplicate(true)
    var map_seed: int = int(randi())
    _rpc_begin.rpc(round_id, snapshot, map_seed)
    _activate_match(snapshot, map_seed)

@rpc("authority", "call_remote", "reliable")
func _rpc_begin(begin_round: int, snapshot: Dictionary, map_seed: int) -> void:
    if phase != "loading" or begin_round != round_id:
        return
    if not snapshot.has(multiplayer.get_unique_id()):
        return
    _activate_match(snapshot, map_seed)

func _activate_match(snapshot: Dictionary, map_seed: int) -> void:
    players = snapshot.duplicate(true)
    snapshot_elapsed = 0.0
    economy = ECONOMY.create(MAP.generate(map_seed, players.size()), players, RULES.ordered_peers(players))
    resource_history.clear()
    ECONOMY.sample_resource_rates(economy, resource_history)
    owners = ECONOMY.planet_teams(economy)
    _set_phase("match")
    _status("Match in progress")
    if is_solo or multiplayer.is_server():
        economy_timer.start()
    roster_changed.emit()
    owners_changed.emit()
    economy_changed.emit()

func _load_timed_out() -> void:
    if multiplayer.is_server() and phase == "loading":
        _abort_loading("Match loading timed out. Check disconnected or stalled players.")

func cancel_loading() -> void:
    if multiplayer.is_server() and phase == "loading":
        _abort_loading("Match start cancelled. Please ready up again.")

func _abort_loading(reason: String) -> void:
    if not multiplayer.is_server() or phase != "loading":
        return
    load_timer.stop()
    RULES.reset_guest_ready(players)
    _rpc_abort.rpc(round_id, players.duplicate(true), reason)
    _back_to_lobby(players.duplicate(true), reason)

@rpc("authority", "call_remote", "reliable")
func _rpc_abort(abort_round: int, snapshot: Dictionary, reason: String) -> void:
    if phase == "loading" and abort_round == round_id:
        _back_to_lobby(snapshot, reason)

func return_to_lobby() -> void:
    if not multiplayer.is_server() or phase != "match":
        return
    RULES.reset_guest_ready(players)
    _rpc_return.rpc(round_id, players.duplicate(true))
    _back_to_lobby(players.duplicate(true), "Returned to lobby. Ready up for another match.")

@rpc("authority", "call_remote", "reliable")
func _rpc_return(match_round: int, snapshot: Dictionary) -> void:
    if phase == "match" and match_round == round_id:
        _back_to_lobby(snapshot, "Host returned everyone to the lobby.")

func _back_to_lobby(snapshot: Dictionary, reason: String) -> void:
    players = snapshot.duplicate(true)
    loaded.clear()
    economy_timer.stop()
    owners.clear()
    economy.clear()
    _set_phase("lobby")
    _status(reason)
    roster_changed.emit()
    owners_changed.emit()
    economy_changed.emit()
    get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func request_colonize(ship_id: int, target: int) -> void:
    if phase != "match":
        return
    if is_solo or multiplayer.is_server():
        _colonize_for(1, ship_id, target)
    else:
        _rpc_colonize.rpc_id(1, ship_id, target)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_colonize(ship_id: int, target: int) -> void:
    if multiplayer.is_server():
        _colonize_for(multiplayer.get_remote_sender_id(), ship_id, target)

func _colonize_for(id: int, ship_id: int, target: int) -> void:
    if _active_player(id) and ECONOMY.send_colony(economy, id, ship_id, target):
        _publish_economy()

func request_military(kind: String, node: int, percent: int) -> void:
    if phase != "match":
        return
    if is_solo or multiplayer.is_server():
        _military_for(1, kind, node, percent)
    else:
        _rpc_military.rpc_id(1, kind, node, percent)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_military(kind: String, node: int, percent: int) -> void:
    if multiplayer.is_server():
        _military_for(multiplayer.get_remote_sender_id(), kind, node, percent)

func _military_for(id: int, kind: String, node: int, percent: int) -> void:
    if _active_player(id) and ECONOMY.set_military(economy, id, kind, node, percent):
        _publish_economy()

func _active_player(id: int) -> bool:
    return phase == "match" and players.has(id) and (id == 1 or multiplayer.get_peers().has(id))

func request_operation(index: int, kind: String, target: String = "") -> void:
    if phase != "match":
        return
    if is_solo or multiplayer.is_server():
        _operation_for(1, index, kind, target)
    else:
        _rpc_operation.rpc_id(1, index, kind, target)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_operation(index: int, kind: String, target: String) -> void:
    if multiplayer.is_server():
        _operation_for(multiplayer.get_remote_sender_id(), index, kind, target)

func _operation_for(id: int, index: int, kind: String, target: String) -> void:
    if _active_player(id) and ECONOMY.enqueue(economy, id, index, kind, target):
        _publish_economy()

func request_continuous(index: int, kind: String, enabled: bool) -> void:
    if phase != "match":
        return
    if is_solo or multiplayer.is_server():
        _continuous_for(1, index, kind, enabled)
    else:
        _rpc_continuous.rpc_id(1, index, kind, enabled)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_continuous(index: int, kind: String, enabled: bool) -> void:
    if multiplayer.is_server():
        _continuous_for(multiplayer.get_remote_sender_id(), index, kind, enabled)

func _continuous_for(id: int, index: int, kind: String, enabled: bool) -> void:
    if _active_player(id) and ECONOMY.set_continuous(economy, id, index, kind, enabled):
        _publish_economy()

func request_cancel(index: int, job_id: int) -> void:
    if phase != "match":
        return
    if is_solo or multiplayer.is_server():
        _cancel_for(1, index, job_id)
    else:
        _rpc_cancel.rpc_id(1, index, job_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_cancel(index: int, job_id: int) -> void:
    if multiplayer.is_server():
        _cancel_for(multiplayer.get_remote_sender_id(), index, job_id)

func _cancel_for(id: int, index: int, job_id: int) -> void:
    if _active_player(id) and ECONOMY.cancel(economy, id, index, job_id):
        _publish_economy()

func request_thresholds(index: int, resource: String, minimum: float, maximum: float) -> void:
    if phase != "match":
        return
    if is_solo or multiplayer.is_server():
        _thresholds_for(1, index, resource, minimum, maximum)
    else:
        _rpc_thresholds.rpc_id(1, index, resource, minimum, maximum)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_thresholds(index: int, resource: String, minimum: float, maximum: float) -> void:
    if multiplayer.is_server():
        _thresholds_for(multiplayer.get_remote_sender_id(), index, resource, minimum, maximum)

func _thresholds_for(id: int, index: int, resource: String, minimum: float, maximum: float) -> void:
    if _active_player(id) and ECONOMY.set_thresholds(economy, id, index, resource, minimum, maximum):
        _publish_economy()

func request_mining_policy(index: int, enabled: bool, metals: bool, crystals: bool) -> void:
    if phase != "match":
        return
    if is_solo or multiplayer.is_server():
        _mining_policy_for(1, index, enabled, metals, crystals)
    else:
        _rpc_mining_policy.rpc_id(1, index, enabled, metals, crystals)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_mining_policy(index: int, enabled: bool, metals: bool, crystals: bool) -> void:
    if multiplayer.is_server():
        _mining_policy_for(multiplayer.get_remote_sender_id(), index, enabled, metals, crystals)

func _mining_policy_for(id: int, index: int, enabled: bool, metals: bool, crystals: bool) -> void:
    if _active_player(id) and ECONOMY.set_mining_policy(economy, id, index, enabled, metals, crystals):
        _publish_economy()

func _economy_tick() -> void:
    if phase != "match" or not (is_solo or multiplayer.is_server()):
        return
    ECONOMY.step(economy, SIM_STEP)
    ECONOMY.sample_resource_rates(economy, resource_history)
    snapshot_elapsed += SIM_STEP
    if snapshot_elapsed >= SNAPSHOT_INTERVAL - 0.00001:
        _publish_economy()

func _publish_economy() -> void:
    snapshot_elapsed = 0.0
    owners = ECONOMY.planet_teams(economy)
    if not is_solo:
        _rpc_economy.rpc(round_id, var_to_bytes(economy).compress(FileAccess.COMPRESSION_GZIP))
    owners_changed.emit()
    economy_changed.emit()

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_economy(update_round: int, compressed: PackedByteArray) -> void:
    if phase != "match" or update_round != round_id:
        return
    var decoded: Variant = bytes_to_var(compressed.decompress_dynamic(16777216, FileAccess.COMPRESSION_GZIP))
    if not decoded is Dictionary:
        return
    var snapshot: Dictionary = decoded
    if (snapshot.get("planets", []) as Array).size() != (economy.get("planets", []) as Array).size():
        return
    economy = snapshot
    owners = ECONOMY.planet_teams(economy)
    owners_changed.emit()
    economy_changed.emit()

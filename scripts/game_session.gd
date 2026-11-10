extends Node
## Persistent ENet session. All RPC endpoints live here, not on changing scenes.
## The host is authoritative for lobby, load barrier, and territory ownership.

signal phase_changed
signal roster_changed
signal chat_changed
signal status_changed
signal owners_changed
signal state_changed

const RULES = preload("res://scripts/lobby_rules.gd")
const SIM = preload("res://scripts/match_simulation.gd")
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
var round_id: int = 0
var loaded: Dictionary = {}
var load_timer: Timer
var simulation: RefCounted
var map_data: Dictionary = {}
var match_state: Dictionary = {}
var simulation_timer: Timer
var incoming_tick: int = -1
var incoming_parts: Dictionary = {}

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
    simulation_timer = Timer.new()
    simulation_timer.wait_time = SIM.TICK
    simulation_timer.timeout.connect(_simulation_tick)
    add_child(simulation_timer)

func _set_phase(value: String) -> void:
    if value != "match":
        simulation_timer.stop()
    if phase != value:
        phase = value
        phase_changed.emit()

func _status(value: String) -> void:
    status = value
    status_changed.emit()

func _sanitize_name(value: String) -> String:
    var clean: String = value.replace("\n", " ").replace("\r", " ").strip_edges().substr(0, 24)
    return clean if not clean.is_empty() else "Player"

func host_game(wanted_name: String, port: int = PORT) -> bool:
    if phase != "offline":
        return false
    var peer := ENetMultiplayerPeer.new()
    var err: int = peer.create_server(port, RULES.MAX_PLAYERS - 1)
    if err != OK:
        _status("Could not host (error %d). Check UDP %d." % [err, port])
        return false
    multiplayer.multiplayer_peer = peer
    display_name = _sanitize_name(wanted_name)
    players = {1: {"name": display_name, "team": 1, "ready": true}}
    history.clear()
    last_message.clear()
    round_id = 0
    owners.clear()
    _set_phase("lobby")
    _status("Waiting for players (2–8 including bots required to start).")
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
    var err: int = peer.create_client(ip, PORT)
    if err != OK:
        _status("Could not connect (error %d)." % err)
        return false
    multiplayer.multiplayer_peer = peer
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
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    players.clear()
    history.clear()
    last_message.clear()
    loaded.clear()
    owners.clear()
    round_id = 0
    _clear_match()
    _set_phase("offline")
    roster_changed.emit()
    chat_changed.emit()
    owners_changed.emit()

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
    if phase == "match" and simulation != null:
        simulation.call("take_over", peer_id)
        players[peer_id]["name"] = name + " (bot)"
        _send_roster()
        _status("%s disconnected; a bot now controls their army." % name)
        return
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
        var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
        if peer != null:
            peer.disconnect_peer(sender)
        return
    if players.has(sender):
        return
    var name: String = _sanitize_name(wanted_name)
    players[sender] = {"name": name, "team": _available_team(), "ready": false}
    _rpc_history.rpc_id(sender, history)
    _send_roster()
    _system_message("%s joined." % name)
    _status("Waiting for players to ready up.")

func _available_team() -> int:
    var used_teams: Array[int] = []
    for entry in players.values():
        used_teams.append(int((entry as Dictionary).get("team", 1)))
    var team: int = 1
    while used_teams.has(team) and team < RULES.MAX_PLAYERS:
        team += 1
    return team

func add_bot() -> void:
    if phase != "lobby" or not multiplayer.is_server() or players.size() >= RULES.MAX_PLAYERS:
        return
    var id: int = -1
    while players.has(id):
        id -= 1
    var name: String = "Bot %d" % -id
    players[id] = {"name": name, "team": _available_team(), "ready": true}
    RULES.reset_guest_ready(players)
    _send_roster()
    _system_message("%s added by host." % name)
    _status("Bot added. Guests must ready up again.")

func remove_bot(id: int) -> void:
    if phase != "lobby" or not multiplayer.is_server() or not RULES.is_bot(id) or not players.has(id):
        return
    var name: String = str((players[id] as Dictionary).get("name", "Bot"))
    players.erase(id)
    RULES.reset_guest_ready(players)
    _send_roster()
    _system_message("%s removed by host." % name)
    _status("Bot removed. Guests must ready up again.")

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
    simulation = SIM.new()
    simulation.call("setup", snapshot, int(Time.get_ticks_usec() % 2147483647))
    var generated_map: Dictionary = simulation.get("map")
    var initial_state: Dictionary = simulation.call("snapshot")
    _rpc_begin.rpc(round_id, snapshot, generated_map, initial_state)
    _activate_match(snapshot, generated_map, initial_state)

@rpc("authority", "call_remote", "reliable")
func _rpc_begin(begin_round: int, snapshot: Dictionary, generated_map: Dictionary, initial_state: Dictionary) -> void:
    if phase != "loading" or begin_round != round_id:
        return
    if not snapshot.has(multiplayer.get_unique_id()):
        return
    _activate_match(snapshot, generated_map, initial_state)

func _activate_match(snapshot: Dictionary, generated_map: Dictionary, initial_state: Dictionary) -> void:
    players = snapshot.duplicate(true)
    map_data = generated_map.duplicate(true)
    match_state = initial_state.duplicate(true)
    owners.assign(match_state.owners)
    _set_phase("match")
    _status("Set a rally target with right-click, then recruit your army.")
    roster_changed.emit()
    owners_changed.emit()
    state_changed.emit()
    if multiplayer.is_server():
        simulation_timer.start()

func _simulation_tick() -> void:
    if phase != "match" or not multiplayer.is_server() or simulation == null:
        return
    var was_finished: bool = not str(match_state.get("result", "")).is_empty()
    simulation.call("step")
    match_state = simulation.call("snapshot")
    owners.assign(match_state.owners)
    var payload: PackedByteArray = var_to_bytes(match_state).compress(FileAccess.COMPRESSION_DEFLATE)
    # Final results use the reliable channel so every guest observes the freeze.
    if not str(match_state.result).is_empty() and not was_finished:
        _rpc_final_state.rpc(round_id, payload)
        simulation_timer.stop()
    else:
        # Keep each UDP packet below the MTU, including Godot's RPC overhead.
        var parts: int = ceili(float(payload.size()) / 1000.0)
        for part in range(parts):
            _rpc_state.rpc(round_id, int(match_state.tick), part, parts, payload.slice(part * 1000, (part + 1) * 1000))
    state_changed.emit()

@rpc("authority", "call_remote", "unreliable", 1)
func _rpc_state(state_round: int, state_tick: int, part: int, total: int, payload: PackedByteArray) -> void:
    if phase != "match" or state_round != round_id:
        return
    if state_tick <= int(match_state.get("tick", -1)) or state_tick < incoming_tick or total < 1 or total > 1024 or part < 0 or part >= total:
        return
    if state_tick != incoming_tick:
        incoming_tick = state_tick
        incoming_parts.clear()
    incoming_parts[part] = payload
    if incoming_parts.size() != total:
        return
    var assembled := PackedByteArray()
    for index in range(total):
        if not incoming_parts.has(index):
            return
        assembled.append_array(incoming_parts[index])
    incoming_parts.clear()
    _accept_snapshot(state_round, assembled)

func _accept_snapshot(state_round: int, payload: PackedByteArray) -> void:
    if phase != "match" or state_round != round_id:
        return
    var decoded: Variant = bytes_to_var(payload.decompress_dynamic(8388608, FileAccess.COMPRESSION_DEFLATE))
    if not decoded is Dictionary:
        return
    var snapshot: Dictionary = decoded
    if snapshot.get("tick", -1) <= match_state.get("tick", -1):
        return
    if not str(match_state.get("result", "")).is_empty():
        return
    match_state = snapshot
    owners.assign(match_state.owners)
    state_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rpc_final_state(state_round: int, payload: PackedByteArray) -> void:
    _accept_snapshot(state_round, payload)

func _clear_match() -> void:
    simulation_timer.stop()
    simulation = null
    map_data.clear()
    match_state.clear()
    incoming_tick = -1
    incoming_parts.clear()

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
    # Disconnected humans are bot-controlled only for this round.
    for id in players.keys():
        if int(id) > 1 and not multiplayer.get_peers().has(int(id)):
            players.erase(id)
    RULES.reset_guest_ready(players)
    _rpc_return.rpc(round_id, players.duplicate(true))
    _back_to_lobby(players.duplicate(true), "Returned to lobby. Ready up for another match.")

@rpc("authority", "call_remote", "reliable")
func _rpc_return(match_round: int, snapshot: Dictionary) -> void:
    if phase == "match" and match_round == round_id:
        _back_to_lobby(snapshot, "Host returned everyone to the lobby.")

func _back_to_lobby(snapshot: Dictionary, reason: String) -> void:
    _clear_match()
    players = snapshot.duplicate(true)
    loaded.clear()
    owners.clear()
    _set_phase("lobby")
    _status(reason)
    roster_changed.emit()
    owners_changed.emit()
    get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func command(action: String, value: int = 0, extra: int = 0) -> void:
    if phase != "match":
        return
    if multiplayer.is_server():
        _accept_order(1, action, value, extra)
    else:
        _rpc_order.rpc_id(1, round_id, action, value, extra)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_order(order_round: int, action: String, value: int, extra: int) -> void:
    if not multiplayer.is_server() or phase != "match" or order_round != round_id:
        return
    var sender: int = multiplayer.get_remote_sender_id()
    if not multiplayer.get_peers().has(sender):
        return
    _accept_order(sender, action, value, extra)

func _accept_order(id: int, action: String, value: int, extra: int) -> void:
    if simulation == null:
        return
    var reason: String = simulation.call("apply_command", id, action, value, extra)
    if reason.is_empty():
        reason = "Order accepted: %s." % action.replace("_", " ")
    if id == 1:
        _status(reason)
    else:
        _rpc_order_feedback.rpc_id(id, round_id, reason)

@rpc("authority", "call_remote", "reliable")
func _rpc_order_feedback(order_round: int, message: String) -> void:
    if phase == "match" and order_round == round_id:
        _status(message)

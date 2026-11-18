extends Node
## Persistent ENet session. All RPC endpoints live here, not on changing scenes.
## The host is authoritative for lobby, load barrier, and territory ownership.
signal phase_changed
signal roster_changed
signal chat_changed
signal status_changed
signal owners_changed
signal economy_changed
signal lobbies_changed

const RULES = preload("res://scripts/lobby_rules.gd")
const ECONOMY = preload("res://scripts/economy_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")
const SIM_STEP: float = 0.1
const MATCH_SPEEDS: Array[int] = [0, 1, 2, 5, 10]
const SNAPSHOT_INTERVAL: float = 0.2
const PORT: int = 24567
const DISCOVERY_PORT: int = 24568
const DISCOVERY_QUERY: String = "WARBOUND_DISCOVER_1:"
const DISCOVERY_TTL_MS: int = 6500
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
var map_layout: String = MAP.DEFAULT_LAYOUT
var lobby_map_seed: int = 0
var discovered_lobbies: Dictionary = {}
var discovery_host: PacketPeerUDP
var discovery_browser: PacketPeerUDP
var discovery_nonce: String = ""
var discovery_target: String = ""
var discovery_next: int = 0
var round_id: int = 0
var loaded: Dictionary = {}
var load_timer: Timer
var economy_timer: Timer
var snapshot_elapsed: float = 0.0
var snapshot_revision: int = 0
var snapshot_sent: Dictionary = {}
var snapshot_pending: Dictionary = {}

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
	var discovery_timer := Timer.new()
	discovery_timer.wait_time = 0.25
	discovery_timer.timeout.connect(_poll_discovery)
	add_child(discovery_timer)
	discovery_timer.start()

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
func start_solo(team: int = 1, opponent_teams: Array = [], colors: Array = [], map_seed: Variant = null, layout: String = MAP.DEFAULT_LAYOUT) -> bool:
	if phase != "offline" or not MAP.valid_layout(layout):
		return false
	if not RULES.valid_team(team) or opponent_teams.size() > RULES.MAX_PLAYERS - 1:
		return false
	for opponent_team in opponent_teams:
		if not RULES.valid_team(int(opponent_team)):
			return false
	if not colors.is_empty():
		if colors.size() != opponent_teams.size() + 1:
			return false
		var used: Dictionary = {}
		for choice in colors:
			if not choice is int or int(choice) < 1 or int(choice) > RULES.MAX_PLAYERS or used.has(choice):
				return false
			used[choice] = true
	is_solo = true
	map_layout = layout
	players = {1: {"name": _sanitize_name(display_name), "team": team, "ready": true, "color": 1 if colors.is_empty() else int(colors[0])}}
	for i in range(opponent_teams.size()):
		players[i + 2] = {"name": "AI %d" % (i + 1), "team": int(opponent_teams[i]), "ready": true, "ai": true, "color": i + 2 if colors.is_empty() else int(colors[i + 1])}
	history.clear()
	last_message.clear()
	round_id = 1
	_activate_match(players, int(randi()) if map_seed == null else int(map_seed))
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
	map_layout = MAP.DEFAULT_LAYOUT
	lobby_map_seed = int(randi())
	display_name = _sanitize_name(wanted_name)
	players = {1: {"name": display_name, "team": 1, "ready": true, "color": 1}}
	history.clear()
	last_message.clear()
	round_id = 0
	owners.clear()
	stop_lobby_browser()
	discovery_host = PacketPeerUDP.new()
	if discovery_host.bind(DISCOVERY_PORT, "0.0.0.0") != OK:
		discovery_host = null
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
	stop_lobby_browser()
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
	stop_lobby_browser()
	if discovery_host != null:
		discovery_host.close()
		discovery_host = null
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
	map_layout = MAP.DEFAULT_LAYOUT
	lobby_map_seed = 0
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
	snapshot_sent.erase(peer_id)
	snapshot_pending.erase(peer_id)
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
	players[sender] = {"name": name, "team": team, "ready": false, "color": RULES.free_color(players)}
	_rpc_history.rpc_id(sender, history)
	_send_roster()
	_system_message("%s joined." % name)
	_status("Waiting for players to ready up.")

func _connected_guests() -> Array[int]:
	var ids: Array[int] = []
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return ids
	for id in multiplayer.get_peers():
		if not players.has(id):
			continue
		var connection: ENetPacketPeer = peer.get_peer(id)
		if connection != null and connection.get_state() == ENetPacketPeer.STATE_CONNECTED:
			ids.append(id)
	return ids

func _send_roster() -> void:
	if not multiplayer.is_server():
		return
	var snapshot: Dictionary = players.duplicate(true)
	for id in _connected_guests():
		_rpc_roster.rpc_id(id, snapshot, map_layout, lobby_map_seed)
	roster_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rpc_roster(snapshot: Dictionary, layout: String, seed_value: int) -> void:
	if phase == "offline" or not MAP.valid_layout(layout):
		return
	map_layout = layout
	lobby_map_seed = seed_value
	players = snapshot.duplicate(true)
	if phase == "connecting":
		_set_phase("lobby")
		_status("Connected to lobby.")
	roster_changed.emit()

func choose_map_layout(layout: String) -> void:
	if phase != "lobby" or not multiplayer.is_server() or not MAP.valid_layout(layout) or layout == map_layout:
		return
	map_layout = layout
	RULES.reset_guest_ready(players)
	_send_roster()
	_status("Map layout changed; guests must ready up again.")

func choose_lobby_seed(seed_value: int) -> void:
	if phase != "lobby" or not multiplayer.is_server() or seed_value == lobby_map_seed:
		return
	lobby_map_seed = seed_value
	RULES.reset_guest_ready(players)
	_send_roster()
	_status("Map seed changed; guests must ready up again.")

func reroll_lobby_map() -> void:
	if phase != "lobby" or not multiplayer.is_server():
		return
	var new_seed: int = int(randi())
	if new_seed == lobby_map_seed:
		new_seed += 1
	lobby_map_seed = new_seed
	RULES.reset_guest_ready(players)
	_send_roster()
	_status("Map rerolled; guests must ready up again.")

# LAN broadcast plus a direct probe of the explicitly entered IPv4 address.
# This is not an internet matchmaking directory. Gameplay remains ENet.
func start_lobby_browser(address: String = "") -> void:
	if phase != "offline":
		return
	discovery_target = address.strip_edges()
	if discovery_browser == null:
		discovery_browser = PacketPeerUDP.new()
		if discovery_browser.bind(0, "0.0.0.0") != OK:
			discovery_browser = null
			return
		discovery_browser.set_broadcast_enabled(true)
		discovery_nonce = str(randi())
	discovery_next = 0
	_poll_discovery()

func stop_lobby_browser() -> void:
	if discovery_browser != null:
		discovery_browser.close()
		discovery_browser = null
	if not discovered_lobbies.is_empty():
		discovered_lobbies.clear()
		lobbies_changed.emit()

func _poll_discovery() -> void:
	if discovery_host != null:
		for i in range(mini(32, discovery_host.get_available_packet_count())):
			var packet: PackedByteArray = discovery_host.get_packet()
			if phase != "lobby" or players.size() >= RULES.MAX_PLAYERS or packet.size() > 64:
				continue
			var query: String = packet.get_string_from_utf8()
			if not query.begins_with(DISCOVERY_QUERY):
				continue
			var nonce: String = query.trim_prefix(DISCOVERY_QUERY)
			if not nonce.is_valid_int():
				continue
			var response: Dictionary = {"nonce": nonce, "version": str(ProjectSettings.get_setting("application/config/version")), "name": str(players.get(1, {}).get("name", "Host")), "players": players.size(), "layout": map_layout}
			if discovery_host.set_dest_address(discovery_host.get_packet_ip(), discovery_host.get_packet_port()) == OK:
				discovery_host.put_packet(JSON.stringify(response).to_utf8_buffer())
	if discovery_browser == null or phase != "offline":
		return
	var now: int = Time.get_ticks_msec()
	if now >= discovery_next:
		discovery_next = now + 2000
		var query: PackedByteArray = (DISCOVERY_QUERY + discovery_nonce).to_utf8_buffer()
		var targets: Array[String] = ["255.255.255.255", "127.0.0.1"]
		if discovery_target.is_valid_ip_address() and not discovery_target.contains(":") and not targets.has(discovery_target):
			targets.append(discovery_target)
		for target in targets:
			if discovery_browser.set_dest_address(target, DISCOVERY_PORT) == OK:
				discovery_browser.put_packet(query)
	var changed: bool = false
	for i in range(mini(64, discovery_browser.get_available_packet_count())):
		var packet: PackedByteArray = discovery_browser.get_packet()
		var address: String = discovery_browser.get_packet_ip()
		if packet.size() > 1024 or discovery_browser.get_packet_port() != DISCOVERY_PORT:
			continue
		var decoded: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if not decoded is Dictionary:
			continue
		var info: Dictionary = decoded
		if str(info.get("nonce", "")) != discovery_nonce or str(info.get("version", "")) != str(ProjectSettings.get_setting("application/config/version")):
			continue
		var count_value: Variant = info.get("players")
		if not (count_value is float or count_value is int):
			continue
		var count: int = int(count_value)
		var layout: String = str(info.get("layout", ""))
		if count < 1 or count >= RULES.MAX_PLAYERS or not MAP.valid_layout(layout):
			continue
		if discovered_lobbies.size() >= 128 and not discovered_lobbies.has(address):
			continue
		var name: String = _sanitize_name(str(info.get("name", "Host")))
		var previous: Dictionary = discovered_lobbies.get(address, {})
		changed = changed or previous.is_empty() or previous.get("name") != name or previous.get("players") != count or previous.get("layout") != layout
		discovered_lobbies[address] = {"name": name, "players": count, "layout": layout, "last_seen": now}
	for address in discovered_lobbies.keys():
		if now - int(discovered_lobbies[address]["last_seen"]) > DISCOVERY_TTL_MS:
			discovered_lobbies.erase(address)
			changed = true
	if changed:
		lobbies_changed.emit()

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
	if bool(players[id].get("ai", false)) and not multiplayer.is_server():
		return
	var entry: Dictionary = players[id]
	if int(entry.get("team", 0)) == team:
		return
	entry["team"] = team
	players[id] = entry
	RULES.reset_guest_ready(players)
	_send_roster()
	_status("Teams changed; guests must ready up again.")

func choose_color(peer_id: int, choice: int) -> void:
	if phase != "lobby" or (peer_id != multiplayer.get_unique_id() and not (multiplayer.is_server() and bool(players.get(peer_id, {}).get("ai", false)))):
		return
	if multiplayer.is_server():
		_change_color(peer_id, choice)
	else:
		_rpc_color.rpc_id(1, choice)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_color(choice: int) -> void:
	if multiplayer.is_server() and phase == "lobby":
		_change_color(multiplayer.get_remote_sender_id(), choice)

func _change_color(id: int, choice: int) -> void:
	if not players.has(id) or not RULES.color_available(players, id, choice):
		_send_roster() # Restore the authoritative selection after a racing request.
		return
	if int(players[id].get("color", 0)) == choice:
		return
	players[id]["color"] = choice
	_send_roster()

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
	for id in _connected_guests():
		_rpc_chat_item.rpc_id(id, item)

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

# AI slots are host-owned roster entries, never ENet peer IDs.
func add_lobby_ai() -> void:
	if not multiplayer.is_server() or phase != "lobby" or players.size() >= RULES.MAX_PLAYERS:
		return
	# ENet peer IDs are positive signed 32-bit integers. Allocate bots
	# above that range so they are positive empire IDs, but never peers.
	var id: int = RULES.FIRST_AI_ID
	while players.has(id):
		id += 1
	var team: int = 1
	var used: Dictionary = {}
	for entry in players.values():
		used[int(entry.get("team", 1))] = true
	while used.has(team) and team < RULES.MAX_PLAYERS:
		team += 1
	players[id] = {"name": "AI %d" % (id - RULES.FIRST_AI_ID + 1), "team": team, "ready": true, "ai": true, "color": RULES.free_color(players)}
	_send_roster()

func remove_lobby_ai(id: int) -> void:
	if not multiplayer.is_server() or phase != "lobby" or not players.has(id):
		return
	if not bool(players[id].get("ai", false)):
		return
	players.erase(id)
	_send_roster()

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
	for id in snapshot:
		if bool(snapshot[id].get("ai", false)):
			loaded[id] = true
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
	var map_seed: int = lobby_map_seed
	_rpc_begin.rpc(round_id, snapshot, map_seed, map_layout)
	_activate_match(snapshot, map_seed)

@rpc("authority", "call_remote", "reliable")
func _rpc_begin(begin_round: int, snapshot: Dictionary, map_seed: int, layout: String) -> void:
	if phase != "loading" or begin_round != round_id or not MAP.valid_layout(layout):
		return
	if not snapshot.has(multiplayer.get_unique_id()):
		return
	map_layout = layout
	_activate_match(snapshot, map_seed)

func _activate_match(snapshot: Dictionary, map_seed: int) -> void:
	lobby_map_seed = map_seed
	players = snapshot.duplicate(true)
	snapshot_elapsed = 0.0
	snapshot_revision = 0
	snapshot_sent.clear()
	snapshot_pending.clear()
	economy = ECONOMY.create(MAP.generate(map_seed, players.size(), map_layout), players, RULES.ordered_peers(players))
	economy["time_speed"] = 1
	economy["eliminated"] = []
	economy["match_result"] = {}
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

func request_fighter_move(ids: Array, target: int, move_only: bool = false) -> void:
	if phase != "match":
		return
	if is_solo or multiplayer.is_server():
		_fighter_move_for(1, ids, target, move_only)
	else:
		_rpc_fighter_move.rpc_id(1, ids, target, move_only)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_fighter_move(ids: Array, target: int, move_only: bool = false) -> void:
	if multiplayer.is_server():
		_fighter_move_for(multiplayer.get_remote_sender_id(), ids, target, move_only)

func _fighter_move_for(id: int, ids: Array, target: int, move_only: bool = false) -> void:
	if _active_player(id) and ECONOMY.command_fighters(economy, id, ids, target, move_only):
		_publish_economy()

func request_tactical_order(ids: Array, kind: String, target: int) -> void:
	if phase != "match":
		return
	if is_solo or multiplayer.is_server():
		_tactical_order_for(1, ids, kind, target)
	else:
		_rpc_tactical_order.rpc_id(1, ids, kind, target)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_tactical_order(ids: Array, kind: String, target: int) -> void:
	if multiplayer.is_server():
		_tactical_order_for(multiplayer.get_remote_sender_id(), ids, kind, target)

func _tactical_order_for(id: int, ids: Array, kind: String, target: int) -> void:
	if not _active_player(id):
		return
	var accepted: bool = false
	match kind:
		"attack":
			accepted = ECONOMY.command_attack(economy, id, ids, target)
		"patrol":
			accepted = ECONOMY.command_patrol(economy, id, ids, target)
	if accepted:
		_publish_economy()

func request_miner_assignment(ids: Array, field: int, chunk: int = -1) -> void:
	if phase != "match":
		return
	if is_solo or multiplayer.is_server():
		_miner_assignment_for(1, ids, field, chunk)
	else:
		_rpc_miner_assignment.rpc_id(1, ids, field, chunk)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_miner_assignment(ids: Array, field: int, chunk: int) -> void:
	if multiplayer.is_server():
		_miner_assignment_for(multiplayer.get_remote_sender_id(), ids, field, chunk)

func _miner_assignment_for(id: int, ids: Array, field: int, chunk: int) -> void:
	if _active_player(id) and ECONOMY.command_miners(economy, id, ids, field, chunk):
		_publish_economy()

func request_fighter_hold(ids: Array) -> void:
	if phase != "match":
		return
	if is_solo or multiplayer.is_server():
		_fighter_hold_for(1, ids)
	else:
		_rpc_fighter_hold.rpc_id(1, ids)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_fighter_hold(ids: Array) -> void:
	if multiplayer.is_server():
		_fighter_hold_for(multiplayer.get_remote_sender_id(), ids)

func _fighter_hold_for(id: int, ids: Array) -> void:
	if _active_player(id) and ECONOMY.hold_fighters(economy, id, ids):
		_publish_economy()

func request_local_position(ids: Array, node: int, point: Vector2, move_only: bool = false) -> void:
	if phase != "match":
		return
	if is_solo or multiplayer.is_server():
		_local_position_for(1, ids, node, point, move_only)
	else:
		_rpc_local_position.rpc_id(1, ids, node, point, move_only)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_local_position(ids: Array, node: int, point: Vector2, move_only: bool = false) -> void:
	if multiplayer.is_server():
		_local_position_for(multiplayer.get_remote_sender_id(), ids, node, point, move_only)

func _local_position_for(id: int, ids: Array, node: int, point: Vector2, move_only: bool = false) -> void:
	if _active_player(id) and ECONOMY.command_local_position(economy, id, ids, node, point, move_only):
		_publish_economy()

func request_salvage(ids: Array, target: int) -> void:
	if phase != "match":
		return
	if is_solo or multiplayer.is_server():
		_salvage_for(1, ids, target)
	else:
		_rpc_salvage.rpc_id(1, ids, target)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_salvage(ids: Array, target: int) -> void:
	if multiplayer.is_server():
		_salvage_for(multiplayer.get_remote_sender_id(), ids, target)

func _salvage_for(id: int, ids: Array, target: int) -> void:
	if _active_player(id) and ECONOMY.command_salvage(economy, id, ids, target):
		_publish_economy()

func request_unload_cargo(ids: Array) -> void:
	if phase != "match":
		return
	if is_solo or multiplayer.is_server():
		_unload_cargo_for(1, ids)
	else:
		_rpc_unload_cargo.rpc_id(1, ids)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_unload_cargo(ids: Array) -> void:
	if multiplayer.is_server():
		_unload_cargo_for(multiplayer.get_remote_sender_id(), ids)

func _unload_cargo_for(id: int, ids: Array) -> void:
	if _active_player(id) and ECONOMY.command_unload_cargo(economy, id, ids):
		_publish_economy()

func request_unit_hold(ids: Array, release: bool) -> void:
	if phase != "match":
		return
	if is_solo or multiplayer.is_server():
		_unit_hold_for(1, ids, release)
	else:
		_rpc_unit_hold.rpc_id(1, ids, release)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_unit_hold(ids: Array, release: bool) -> void:
	if multiplayer.is_server():
		_unit_hold_for(multiplayer.get_remote_sender_id(), ids, release)

func _unit_hold_for(id: int, ids: Array, release: bool) -> void:
	if _active_player(id) and ECONOMY.command_hold_units(economy, id, ids, release):
		_publish_economy()

func request_unit_orders(orders: Array, append: bool = false) -> void:
	if phase != "match":
		return
	if is_solo or multiplayer.is_server():
		_unit_orders_for(1, orders, append)
	else:
		_rpc_unit_orders.rpc_id(1, orders, append)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_unit_orders(orders: Array, append: bool) -> void:
	if multiplayer.is_server():
		_unit_orders_for(multiplayer.get_remote_sender_id(), orders, append)

func _unit_orders_for(id: int, orders: Array, append: bool) -> void:
	if not _active_player(id) or orders.size() > economy["ships"].size():
		return
	var changed: bool = false
	for entry in orders:
		if entry is Dictionary and entry.get("ids") is Array and entry.get("order") is Dictionary:
			changed = ECONOMY.issue_unit_order(economy, id, entry["ids"], entry["order"], append) or changed
	if changed:
		_publish_economy()

func _active_player(id: int) -> bool:
	return _match_peer(id) and economy.get("match_result", {}).is_empty() and not economy.get("eliminated", []).has(id)

func _match_peer(id: int) -> bool:
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
	if not _active_player(id) or kind == "production":
		return
	if kind == "shipyard_build":
		var parts: PackedStringArray = target.split(":")
		if parts.size() == 2 and parts[0].is_valid_int() and int(parts[0]) >= 0 and ECONOMY.SHIP_KINDS.has(parts[1]) and ECONOMY.enqueue(economy, id, index, parts[1], "", int(parts[0])):
			_publish_economy()
		return
	if ECONOMY.enqueue(economy, id, index, kind, target):
		_publish_economy()

func request_shipyard_rally(index: int, slot: int, target: int, point: Vector2) -> void:
	if phase != "match":
		return
	if is_solo or multiplayer.is_server():
		_shipyard_rally_for(1, index, slot, target, point)
	else:
		_rpc_shipyard_rally.rpc_id(1, index, slot, target, point)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_shipyard_rally(index: int, slot: int, target: int, point: Vector2) -> void:
	if multiplayer.is_server():
		_shipyard_rally_for(multiplayer.get_remote_sender_id(), index, slot, target, point)

func _shipyard_rally_for(id: int, index: int, slot: int, target: int, point: Vector2) -> void:
	if _active_player(id) and ECONOMY.set_shipyard_rally(economy, id, index, slot, target, point):
		_publish_economy()

func request_maintain(index: int, kind: String, amount: int) -> void:
	if phase != "match":
		return
	if is_solo or multiplayer.is_server():
		_maintain_for(1, index, kind, amount)
	else:
		_rpc_maintain.rpc_id(1, index, kind, amount)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_maintain(index: int, kind: String, amount: int) -> void:
	if multiplayer.is_server():
		_maintain_for(multiplayer.get_remote_sender_id(), index, kind, amount)

func _maintain_for(id: int, index: int, kind: String, amount: int) -> void:
	if _active_player(id) and ECONOMY.set_maintain(economy, id, index, kind, amount):
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
	if not kind.begins_with("production:") and _active_player(id) and ECONOMY.set_continuous(economy, id, index, kind, enabled):
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

func request_thresholds(index: int, resource: String, minimum: float, maximum: float, importing: bool = true, exporting: bool = true) -> void:
	if phase != "match":
		return
	if is_solo or multiplayer.is_server():
		_thresholds_for(1, index, resource, minimum, maximum, importing, exporting)
	else:
		_rpc_thresholds.rpc_id(1, index, resource, minimum, maximum, importing, exporting)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_thresholds(index: int, resource: String, minimum: float, maximum: float, importing: bool = true, exporting: bool = true) -> void:
	if multiplayer.is_server():
		_thresholds_for(multiplayer.get_remote_sender_id(), index, resource, minimum, maximum, importing, exporting)

func _thresholds_for(id: int, index: int, resource: String, minimum: float, maximum: float, importing: bool = true, exporting: bool = true) -> void:
	if _active_player(id) and ECONOMY.set_thresholds(economy, id, index, resource, minimum, maximum, importing, exporting):
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

# Only the local authority may change the shared speed. Guests receive it in
# the same round-scoped authoritative snapshots as the simulation state.
func request_time_speed(speed: int) -> void:
	if phase != "match" or not (is_solo or multiplayer.is_server()):
		return
	if not economy.get("match_result", {}).is_empty() or not MATCH_SPEEDS.has(speed) or int(economy.get("time_speed", 1)) == speed:
		return
	economy["time_speed"] = speed
	_publish_economy()

var diagnostic_sim_ms: float = 0.0
var diagnostic_sim_phases: Dictionary = {}
var diagnostic_encode_ms: float = 0.0
var diagnostic_snapshot_bytes: int = 0
var diagnostic_sent_bytes: int = 0
var diagnostic_received_bytes: int = 0

func _economy_tick() -> void:
	if phase != "match" or not (is_solo or multiplayer.is_server()):
		return
	var speed: int = int(economy.get("time_speed", 1))
	# Pause stops the simulation, but not accepted orders or replication.
	var started: int = Time.get_ticks_usec()
	var profile: Dictionary = {"enabled": true}
	for i in range(speed):
		ECONOMY.step(economy, SIM_STEP, profile)
		var outcome_started: int = Time.get_ticks_usec()
		var changed: bool = ECONOMY.update_match_outcome(economy)
		profile["Match outcome"] = int(profile.get("Match outcome", 0)) + Time.get_ticks_usec() - outcome_started
		if changed:
			_publish_economy()
			if not economy["match_result"].is_empty():
				break
	diagnostic_sim_ms = float(Time.get_ticks_usec() - started) / 1000.0
	profile.erase("enabled")
	diagnostic_sim_phases = profile
	snapshot_elapsed += SIM_STEP
	if snapshot_elapsed >= SNAPSHOT_INTERVAL - 0.00001:
		snapshot_elapsed = 0.0
		if speed > 0:
			_publish_economy()
		_flush_economy()

func _publish_economy() -> void:
	# Local UI stays synchronous. Coalesce remote changes on the snapshot clock.
	snapshot_revision += 1
	owners = ECONOMY.planet_teams(economy)
	owners_changed.emit()
	economy_changed.emit()

func _flush_economy() -> void:
	if is_solo:
		return
	var payload: PackedByteArray = PackedByteArray()
	for id in _connected_guests():
		if snapshot_pending.has(id) or int(snapshot_sent.get(id, -1)) == snapshot_revision:
			continue
		if payload.is_empty():
			var encode_start: int = Time.get_ticks_usec()
			payload = var_to_bytes(economy).compress(FileAccess.COMPRESSION_GZIP)
			diagnostic_encode_ms = float(Time.get_ticks_usec() - encode_start) / 1000.0
			diagnostic_snapshot_bytes = payload.size()
		# At most one reliable full snapshot in flight per guest. A slow guest
		# skips intermediate states, receiving the newest revision after ACK.
		if rpc_id(id, "_rpc_economy", round_id, snapshot_revision, payload) == OK:
			diagnostic_sent_bytes += payload.size()
			snapshot_pending[id] = snapshot_revision
			snapshot_sent[id] = snapshot_revision

@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_snapshot_ack(ack_round: int, revision: int) -> void:
	if not multiplayer.is_server() or phase != "match" or ack_round != round_id:
		return
	var id: int = multiplayer.get_remote_sender_id()
	if _match_peer(id) and int(snapshot_pending.get(id, -1)) == revision:
		snapshot_pending.erase(id)

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_economy(update_round: int, revision: int, compressed: PackedByteArray) -> void:
	if phase != "match" or update_round != round_id:
		return
	diagnostic_received_bytes += compressed.size()
	diagnostic_snapshot_bytes = compressed.size()
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
	_rpc_snapshot_ack.rpc_id(1, update_round, revision)

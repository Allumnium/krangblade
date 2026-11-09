extends Control

const PORT: int = 24567
const MAX_PLAYERS: int = 8
const RULES = preload("res://scripts/lobby_rules.gd")
const MAX_CHAT: int = 250
const BACKGROUND := Color("#121b25")
const PANEL := Color("#213041")
const TEXT := Color("#e9eef4")
const MUTED := Color("#9cabbc")

var screen: String = "menu"
var player_name: String = "Player"
var host_address: LineEdit
var name_edit: LineEdit
var chat_edit: LineEdit
var chat_log: RichTextLabel
var roster: VBoxContainer
var ready_button: Button
var start_button: Button
var status_label: Label
var status: String = ""
var players: Dictionary = {}
var history: Array[Dictionary] = []
var last_message: Dictionary = {}
var connecting: bool = false

func _ready() -> void:
    multiplayer.peer_disconnected.connect(_peer_left)
    multiplayer.connected_to_server.connect(_connected)
    multiplayer.connection_failed.connect(_connection_failed)
    multiplayer.server_disconnected.connect(_server_left)
    _menu()

func _root() -> VBoxContainer:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    var background := ColorRect.new()
    background.color = BACKGROUND
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    var margins := MarginContainer.new()
    margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for edge in ["left", "right", "top", "bottom"]:
        margins.add_theme_constant_override("margin_" + edge, 28)
    add_child(margins)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    margins.add_child(column)
    return column

func _text(value: String, font_size: int = 18, color: Color = TEXT) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label

func _button(title: String, handler: Callable) -> Button:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size = Vector2(130, 44)
    button.pressed.connect(handler)
    return button

func _panel() -> PanelContainer:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.set_corner_radius_all(8)
    style.set_content_margin_all(16)
    panel.add_theme_stylebox_override("panel", style)
    return panel

func _menu() -> void:
    screen = "menu"
    var column := _root()
    column.add_spacer(false)
    var title := _text("WARBOUND", 62)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    var subtitle := _text("TERRITORY  •  STRATEGY  •  CONQUEST", 15, MUTED)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(subtitle)
    column.add_spacer(false)
    var center := CenterContainer.new()
    column.add_child(center)
    var actions := VBoxContainer.new()
    center.add_child(actions)
    actions.add_child(_button("MULTIPLAYER", _multiplayer_menu))
    actions.add_child(_button("QUIT", func() -> void: get_tree().quit()))
    column.add_spacer(false)

func _multiplayer_menu() -> void:
    screen = "multiplayer"
    var column := _root()
    column.add_child(_text("MULTIPLAYER", 36))
    column.add_child(_text("Direct IP / Tailscale • UDP 24567", 15, MUTED))
    var panel := _panel()
    column.add_child(panel)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 12)
    panel.add_child(body)
    body.add_child(_text("DISPLAY NAME", 14, MUTED))
    name_edit = LineEdit.new()
    name_edit.max_length = 24
    name_edit.text = player_name
    body.add_child(name_edit)
    body.add_child(_text("HOST IP ADDRESS", 14, MUTED))
    host_address = LineEdit.new()
    host_address.text = "127.0.0.1"
    body.add_child(host_address)
    var actions := HBoxContainer.new()
    body.add_child(actions)
    actions.add_child(_button("HOST GAME", _host))
    actions.add_child(_button("JOIN GAME", _join))
    body.add_child(_button("BACK", _menu))
    if not status.is_empty():
        body.add_child(_text(status, 14, MUTED))

func _save_name() -> void:
    player_name = name_edit.text.strip_edges().replace("\n", " ").substr(0, 24)
    if player_name.is_empty():
        player_name = "Player"

func _host() -> void:
    _save_name()
    var peer := ENetMultiplayerPeer.new()
    var err: int = peer.create_server(PORT, MAX_PLAYERS - 1)
    if err != OK:
        status = "Host failed: error %d." % err
        _multiplayer_menu()
        return
    multiplayer.multiplayer_peer = peer
    players = {1: {"name": player_name, "ready": true, "team": 1}}
    history.clear()
    last_message.clear()
    status = "Waiting for players."
    _lobby()

func _join() -> void:
    _save_name()
    var address: String = host_address.text.strip_edges()
    if address.is_empty():
        status = "Enter the host IP."
        _multiplayer_menu()
        return
    var peer := ENetMultiplayerPeer.new()
    var err: int = peer.create_client(address, PORT)
    if err != OK:
        status = "Join failed: error %d." % err
        _multiplayer_menu()
        return
    multiplayer.multiplayer_peer = peer
    connecting = true
    status = "Connecting to %s..." % address
    _lobby()

func _lobby() -> void:
    screen = "lobby"
    var column := _root()
    var heading := HBoxContainer.new()
    column.add_child(heading)
    heading.add_child(_text("WARBOUND / LOBBY", 30))
    heading.add_spacer(false)
    heading.add_child(_button("LEAVE", _leave))
    status_label = _text(status, 14, MUTED)
    column.add_child(status_label)
    var layout := HBoxContainer.new()
    layout.add_theme_constant_override("separation", 14)
    layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(layout)
    var left := _panel()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layout.add_child(left)
    var info := VBoxContainer.new()
    info.add_theme_constant_override("separation", 12)
    left.add_child(info)
    info.add_child(_text("PLAYERS", 23))
    roster = VBoxContainer.new()
    info.add_child(roster)
    info.add_spacer(false)
    info.add_child(_text("MATCH SETTINGS", 23))
    info.add_child(_text("Territory Control • Prototype Map", 16, MUTED))
    info.add_child(_text("2–8 players • 1–8 teams • Any arrangement", 15, MUTED))
    ready_button = _button("READY", _toggle_ready)
    info.add_child(ready_button)
    start_button = _button("START MATCH", _start)
    info.add_child(start_button)
    var right := _panel()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layout.add_child(right)
    var chat_box := VBoxContainer.new()
    right.add_child(chat_box)
    chat_box.add_child(_text("LOBBY CHAT", 23))
    chat_log = RichTextLabel.new()
    chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
    chat_log.scroll_following = true
    chat_box.add_child(chat_log)
    var chat_row := HBoxContainer.new()
    chat_box.add_child(chat_row)
    chat_edit = LineEdit.new()
    chat_edit.placeholder_text = "Message (Enter to send)"
    chat_edit.max_length = MAX_CHAT
    chat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chat_edit.text_submitted.connect(func(_value: String) -> void: _send_chat())
    chat_row.add_child(chat_edit)
    chat_row.add_child(_button("SEND", _send_chat))
    _refresh()

func _refresh() -> void:
    if screen != "lobby":
        return
    for child in roster.get_children():
        roster.remove_child(child)
        child.queue_free()
    for id in RULES.ordered_peers(players):
        var data: Dictionary = players[id]
        var role: String = "HOST" if id == 1 else "GUEST"
        var state: String = "READY" if bool(data.get("ready", false)) else "NOT READY"
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        roster.add_child(row)
        var title := _text("%s  •  %s" % [str(data.get("name", "Player")), role], 15)
        title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        title.clip_text = true
        row.add_child(title)
        var selector := OptionButton.new()
        selector.custom_minimum_size.x = 96
        for team in range(1, MAX_PLAYERS + 1):
            selector.add_item("Team %d" % team)
        selector.select(clampi(int(data.get("team", 1)) - 1, 0, MAX_PLAYERS - 1))
        selector.disabled = connecting or (not multiplayer.is_server() and id != multiplayer.get_unique_id())
        selector.item_selected.connect(_team_selected.bind(id))
        row.add_child(selector)
        var flag := _text(state, 12, MUTED)
        flag.custom_minimum_size.x = 80
        row.add_child(flag)
    for _slot in range(MAX_PLAYERS - players.size()):
        roster.add_child(_text("EMPTY SLOT", 14, MUTED))
    status_label.text = status
    ready_button.visible = not multiplayer.is_server() and not connecting
    var self_data: Dictionary = players.get(multiplayer.get_unique_id(), {})
    ready_button.text = "UNREADY" if bool(self_data.get("ready", false)) else "READY"
    start_button.visible = multiplayer.is_server()
    start_button.disabled = not _can_start()
    chat_edit.editable = not connecting
    _refresh_chat()

func _refresh_chat() -> void:
    if chat_log == null:
        return
    chat_log.clear()
    for item in history:
        chat_log.add_text(str(item.get("text", "")) + "\n")

func _can_start() -> bool:
    return multiplayer.is_server() and RULES.can_start(players)

func _team_selected(index: int, id: int) -> void:
    var team: int = index + 1
    if not RULES.valid_team(team):
        return
    if multiplayer.is_server():
        _change_team(id, team)
    elif not connecting and id == multiplayer.get_unique_id():
        _request_team.rpc_id(1, team)

@rpc("any_peer", "call_remote", "reliable")
func _request_team(team: int) -> void:
    if not multiplayer.is_server():
        return
    var sender: int = multiplayer.get_remote_sender_id()
    _change_team(sender, team)

func _change_team(id: int, team: int) -> void:
    if not multiplayer.is_server() or not players.has(id) or not RULES.valid_team(team):
        return
    var data: Dictionary = players[id]
    if int(data.get("team", 1)) == team:
        return
    data["team"] = team
    players[id] = data
    # Any team change invalidates previous ready confirmations.
    for peer_id in players.keys():
        if int(peer_id) == 1:
            continue
        var entry: Dictionary = players[peer_id]
        entry["ready"] = false
        players[peer_id] = entry
    status = "Teams changed. Players must ready up again."
    _broadcast_roster()

func _connected() -> void:
    connecting = false
    status = "Connected to host."
    _register.rpc_id(1, player_name)
    _refresh()

func _peer_left(id: int) -> void:
    if not multiplayer.is_server():
        return
    var data: Dictionary = players.get(id, {})
    players.erase(id)
    last_message.erase(id)
    status = "Waiting for a player."
    _broadcast_roster()
    if not data.is_empty():
        _system_chat("%s left." % str(data.get("name", "Player")))

func _connection_failed() -> void:
    _disconnect()
    status = "Could not connect. Check the host IP and UDP 24567."
    _multiplayer_menu()

func _server_left() -> void:
    _disconnect()
    status = "Host disconnected."
    _multiplayer_menu()

func _disconnect() -> void:
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    connecting = false
    players.clear()
    history.clear()
    last_message.clear()
    get_node("/root/MatchSession").call("clear_roster")

func _leave() -> void:
    _disconnect()
    status = ""
    _multiplayer_menu()

@rpc("any_peer", "call_remote", "reliable")
func _register(wanted_name: String) -> void:
    if not multiplayer.is_server():
        return
    var sender: int = multiplayer.get_remote_sender_id()
    if not multiplayer.get_peers().has(sender) or (not players.has(sender) and players.size() >= MAX_PLAYERS):
        return
    var clean: String = wanted_name.replace("\n", " ").replace("\r", " ").strip_edges().substr(0, 24)
    if clean.is_empty():
        clean = "Player"
    var team: int = 1
    var taken: Array[int] = []
    for entry in players.values():
        taken.append(int(entry.get("team", 1)))
    while taken.has(team):
        team += 1
    players[sender] = {"name": clean, "ready": false, "team": team}
    status = "Waiting for all players to be ready."
    _broadcast_roster()
    _sync_history.rpc_id(sender, history)
    _system_chat("%s joined." % clean)

func _broadcast_roster() -> void:
    _receive_roster.rpc(players)
    _refresh()

@rpc("authority", "call_remote", "reliable")
func _receive_roster(value: Dictionary) -> void:
    players = value.duplicate(true)
    status = "Waiting for players to ready up."
    _refresh()

@rpc("authority", "call_remote", "reliable")
func _sync_history(items: Array) -> void:
    history.clear()
    for item in items:
        if item is Dictionary:
            history.append(item)
    _refresh_chat()

func _toggle_ready() -> void:
    if connecting or multiplayer.is_server():
        return
    var mine: Dictionary = players.get(multiplayer.get_unique_id(), {})
    _request_ready.rpc_id(1, not bool(mine.get("ready", false)))

@rpc("any_peer", "call_remote", "reliable")
func _request_ready(value: bool) -> void:
    if not multiplayer.is_server():
        return
    var sender: int = multiplayer.get_remote_sender_id()
    if not players.has(sender):
        return
    var data: Dictionary = players[sender]
    data["ready"] = value
    players[sender] = data
    _broadcast_roster()

func _send_chat() -> void:
    if chat_edit == null or connecting:
        return
    var message: String = chat_edit.text.strip_edges()
    if message.is_empty():
        return
    chat_edit.clear()
    if multiplayer.is_server():
        _accept_chat(1, message)
    else:
        _request_chat.rpc_id(1, message)

@rpc("any_peer", "call_remote", "reliable")
func _request_chat(value: String) -> void:
    if multiplayer.is_server():
        _accept_chat(multiplayer.get_remote_sender_id(), value)

func _accept_chat(sender: int, value: String) -> void:
    if not players.has(sender):
        return
    var now: int = Time.get_ticks_msec()
    if now - int(last_message.get(sender, -100000)) < 650:
        return
    last_message[sender] = now
    var clean: String = value.replace("\n", " ").replace("\r", " ").strip_edges().substr(0, MAX_CHAT)
    if clean.is_empty():
        return
    var data: Dictionary = players[sender]
    _append_chat("%s: %s" % [str(data.get("name", "Player")), clean])

func _system_chat(value: String) -> void:
    _append_chat("• " + value)

func _append_chat(value: String) -> void:
    if not multiplayer.is_server():
        return
    var item: Dictionary = {"text": value}
    history.append(item)
    if history.size() > 100:
        history.pop_front()
    _receive_chat.rpc(item)
    _refresh_chat()

@rpc("authority", "call_remote", "reliable")
func _receive_chat(item: Dictionary) -> void:
    history.append(item)
    if history.size() > 100:
        history.pop_front()
    _refresh_chat()

func _start() -> void:
    if _can_start():
        var snapshot: Dictionary = players.duplicate(true)
        _launch.rpc(snapshot)
        _enter_match.call_deferred(snapshot)

@rpc("authority", "call_remote", "reliable")
func _launch(snapshot: Dictionary) -> void:
    _enter_match.call_deferred(snapshot)

func _enter_match(snapshot: Dictionary) -> void:
    get_node("/root/MatchSession").set("roster", snapshot.duplicate(true))
    get_tree().change_scene_to_file("res://scenes/match.tscn")

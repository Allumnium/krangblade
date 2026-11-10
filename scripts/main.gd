extends Control
## Warbound menu and lobby view; networking is owned by /root/GameSession.

const RULES = preload("res://scripts/lobby_rules.gd")
const BACKGROUND := Color("#121b25")
const PANEL := Color("#213041")
const TEXT := Color("#e9eef4")
const MUTED := Color("#9cabbc")

var network: Node
var screen: String = ""
var saved_ip: String = "127.0.0.1"
var name_edit: LineEdit
var address_edit: LineEdit
var chat_edit: LineEdit
var chat_log: RichTextLabel
var roster: VBoxContainer
var ready_button: Button
var start_button: Button
var add_bot_button: Button
var status_label: Label
var multiplayer_status_label: Label

func _ready() -> void:
    network = get_node("/root/GameSession")
    network.connect("phase_changed", _on_phase_changed)
    network.connect("roster_changed", _refresh_roster)
    network.connect("chat_changed", _refresh_chat)
    network.connect("status_changed", _refresh_status)
    _on_phase_changed()

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
        margins.add_theme_constant_override("margin_" + edge, 24)
    add_child(margins)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    margins.add_child(column)
    var display_row := HBoxContainer.new()
    column.add_child(display_row)
    display_row.add_spacer(false)
    display_row.add_child(get_node("/root/WindowControls").call("make_button"))
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
    button.custom_minimum_size = Vector2(120, 40)
    button.pressed.connect(handler)
    return button

func _panel() -> PanelContainer:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.set_corner_radius_all(8)
    style.set_content_margin_all(14)
    panel.add_theme_stylebox_override("panel", style)
    return panel

func _on_phase_changed() -> void:
    var phase: String = str(network.get("phase"))
    if phase == "lobby" or phase == "connecting":
        if screen != "lobby":
            _show_lobby()
        else:
            _refresh_roster()
    elif phase == "offline":
        if screen == "lobby" or (screen == "" and not str(network.get("status")).is_empty()):
            _show_multiplayer()
        elif screen == "":
            _show_menu()

func _show_menu() -> void:
    screen = "menu"
    var col := _root()
    col.add_spacer(false)
    var title := _text("WARBOUND", 58)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(title)
    var sub := _text("TERRITORY  •  STRATEGY  •  CONQUEST", 14, MUTED)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(sub)
    col.add_spacer(false)
    var center := CenterContainer.new()
    col.add_child(center)
    var actions := VBoxContainer.new()
    actions.add_theme_constant_override("separation", 12)
    center.add_child(actions)
    actions.add_child(_button("MULTIPLAYER", _show_multiplayer))
    actions.add_child(_button("QUIT", func() -> void: get_tree().quit()))
    col.add_spacer(false)

func _show_multiplayer() -> void:
    screen = "multiplayer"
    var col := _root()
    col.add_child(_text("MULTIPLAYER", 32))
    col.add_child(_text("Direct IP / Tailscale • UDP 24567", 14, MUTED))
    var panel := _panel()
    col.add_child(panel)
    var form := VBoxContainer.new()
    form.add_theme_constant_override("separation", 10)
    panel.add_child(form)
    form.add_child(_text("DISPLAY NAME", 13, MUTED))
    name_edit = LineEdit.new()
    name_edit.text = str(network.get("display_name"))
    name_edit.max_length = 24
    form.add_child(name_edit)
    form.add_child(_text("HOST IP ADDRESS", 13, MUTED))
    address_edit = LineEdit.new()
    address_edit.text = saved_ip
    form.add_child(address_edit)
    var buttons := HBoxContainer.new()
    form.add_child(buttons)
    buttons.add_child(_button("HOST GAME", _host))
    buttons.add_child(_button("JOIN GAME", _join))
    form.add_child(_button("BACK", _show_menu))
    multiplayer_status_label = _text(str(network.get("status")), 14, MUTED)
    form.add_child(multiplayer_status_label)

func _host() -> void:
    saved_ip = address_edit.text
    if not bool(network.call("host_game", name_edit.text)):
        _show_multiplayer()

func _join() -> void:
    saved_ip = address_edit.text
    if not bool(network.call("join_game", name_edit.text, saved_ip)):
        _show_multiplayer()

func _show_lobby() -> void:
    screen = "lobby"
    var col := _root()
    var header := HBoxContainer.new()
    col.add_child(header)
    header.add_child(_text("WARBOUND / LOBBY", 28))
    header.add_spacer(false)
    header.add_child(_button("LEAVE", _leave))
    status_label = _text("", 14, MUTED)
    col.add_child(status_label)

    # Flow-wrap panels at narrow widths; scroll the whole body if stacked.
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    col.add_child(scroll)
    var flow := HFlowContainer.new()
    flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    flow.add_theme_constant_override("h_separation", 12)
    flow.add_theme_constant_override("v_separation", 12)
    scroll.add_child(flow)

    var left := _panel()
    left.custom_minimum_size = Vector2(430, 370)
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    flow.add_child(left)
    var left_col := VBoxContainer.new()
    left_col.add_theme_constant_override("separation", 8)
    left.add_child(left_col)
    left_col.add_child(_text("PLAYERS (MAX 8)", 20))
    var roster_scroll := ScrollContainer.new()
    roster_scroll.custom_minimum_size.y = 230
    roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    left_col.add_child(roster_scroll)
    roster = VBoxContainer.new()
    roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    roster.add_theme_constant_override("separation", 3)
    roster_scroll.add_child(roster)
    left_col.add_child(_text("TERRITORY CONTROL  •  1–8 TEAMS", 13, MUTED))
    var buttons := HBoxContainer.new()
    left_col.add_child(buttons)
    ready_button = _button("READY", _toggle_ready)
    buttons.add_child(ready_button)
    start_button = _button("START MATCH", _start_match)
    buttons.add_child(start_button)
    add_bot_button = _button("ADD BOT", func() -> void: network.call("add_bot"))
    buttons.add_child(add_bot_button)

    var right := _panel()
    right.custom_minimum_size = Vector2(430, 370)
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    flow.add_child(right)
    var right_col := VBoxContainer.new()
    right_col.add_theme_constant_override("separation", 8)
    right.add_child(right_col)
    right_col.add_child(_text("LOBBY CHAT", 20))
    chat_log = RichTextLabel.new()
    chat_log.custom_minimum_size.y = 230
    chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
    chat_log.scroll_following = true
    right_col.add_child(chat_log)
    var chat_row := HBoxContainer.new()
    right_col.add_child(chat_row)
    chat_edit = LineEdit.new()
    chat_edit.max_length = 250
    chat_edit.placeholder_text = "Type message..."
    chat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chat_edit.text_submitted.connect(func(_v: String) -> void: _send_chat())
    chat_row.add_child(chat_edit)
    chat_row.add_child(_button("SEND", _send_chat))
    _refresh_status()
    _refresh_roster()
    _refresh_chat()

func _refresh_status() -> void:
    if screen == "lobby" and is_instance_valid(status_label):
        status_label.text = str(network.get("status"))
    elif screen == "multiplayer" and is_instance_valid(multiplayer_status_label):
        multiplayer_status_label.text = str(network.get("status"))

func _refresh_roster() -> void:
    if screen != "lobby" or not is_instance_valid(roster):
        return
    for child in roster.get_children():
        roster.remove_child(child)
        child.queue_free()
    var roster_data: Dictionary = network.get("players")
    var is_host: bool = multiplayer.is_server()
    var is_lobby: bool = str(network.get("phase")) == "lobby"
    for id in RULES.ordered_peers(roster_data):
        var entry: Dictionary = roster_data[id]
        var row := HBoxContainer.new()
        row.custom_minimum_size.y = 32
        row.add_theme_constant_override("separation", 8)
        roster.add_child(row)
        var role: String = "HOST" if id == 1 else "GUEST"
        if RULES.is_bot(id):
            role = "BOT"
        var label := _text("%s • %s" % [str(entry.get("name", "Player")), role], 14)
        label.clip_text = true
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(label)
        var selector := OptionButton.new()
        selector.custom_minimum_size.x = 96
        for team in range(1, RULES.MAX_PLAYERS + 1):
            selector.add_item("Team %d" % team)
        selector.select(clampi(int(entry.get("team", 1)) - 1, 0, RULES.MAX_PLAYERS - 1))
        selector.disabled = not is_lobby or (not is_host and id != multiplayer.get_unique_id())
        selector.item_selected.connect(_team_selected.bind(id))
        row.add_child(selector)
        var ready := _text("READY" if bool(entry.get("ready", false)) else "WAITING", 12, MUTED)
        ready.custom_minimum_size.x = 68
        row.add_child(ready)
        if is_host and RULES.is_bot(id):
            var remove := Button.new()
            remove.text = "REMOVE"
            remove.disabled = not is_lobby
            remove.pressed.connect(func() -> void: network.call("remove_bot", id))
            row.add_child(remove)
    for _index in range(RULES.MAX_PLAYERS - roster_data.size()):
        roster.add_child(_text("EMPTY SLOT", 13, MUTED))
    ready_button.visible = not is_host
    ready_button.disabled = not is_lobby or not roster_data.has(multiplayer.get_unique_id())
    var my_entry: Dictionary = roster_data.get(multiplayer.get_unique_id(), {})
    ready_button.text = "UNREADY" if bool(my_entry.get("ready", false)) else "READY"
    start_button.visible = is_host
    start_button.disabled = not bool(network.call("can_start"))
    add_bot_button.visible = is_host
    add_bot_button.disabled = not is_lobby or roster_data.size() >= RULES.MAX_PLAYERS
    if is_instance_valid(chat_edit):
        chat_edit.editable = is_lobby

func _refresh_chat() -> void:
    if screen != "lobby" or not is_instance_valid(chat_log):
        return
    chat_log.clear()
    var messages: Array = network.get("history")
    for item in messages:
        chat_log.add_text(str((item as Dictionary).get("text", "")) + "\n")

func _team_selected(index: int, id: int) -> void:
    network.call("choose_team", id, index + 1)

func _toggle_ready() -> void:
    network.call("toggle_ready")

func _start_match() -> void:
    network.call("start_match")

func _send_chat() -> void:
    if not is_instance_valid(chat_edit) or chat_edit.text.strip_edges().is_empty():
        return
    network.call("send_chat", chat_edit.text)
    chat_edit.clear()

func _leave() -> void:
    network.call("leave_session")
    _show_multiplayer()

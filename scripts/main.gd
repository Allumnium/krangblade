extends Control
## Warbound menu and lobby view; networking is owned by /root/GameSession.

const RULES = preload("res://scripts/lobby_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const BACKDROP = preload("res://scripts/space_background.gd")
const TEXT := HUD.TEXT
const MUTED := HUD.MUTED

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
var status_label: Label
var multiplayer_status_label: Label
var solo_players: Dictionary = {}
var solo_roster: VBoxContainer
var solo_rows: Dictionary = {}
var solo_add_button: Button
var solo_start_button: Button
var solo_seed_edit: LineEdit
var solo_layout_picker: OptionButton
var lobby_layout_picker: OptionButton
var solo_preview: Control
var lobby_preview: Control
var lobby_seed_label: Label
var lobby_reroll: Button
var solo_random_seed: int = 0

func _ready() -> void:
	theme = HUD.create()
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
	background.set_script(BACKDROP)
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
	if title in ["SINGLE PLAYER", "MULTIPLAYER", "HOST GAME", "JOIN GAME", "START MATCH"]:
		HUD.action(button)
	return button

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928ed"), Color("#34546e"), 14))
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
	title.add_theme_color_override("font_color", HUD.ACCENT)
	col.add_child(title)
	col.add_spacer(false)
	var center := CenterContainer.new()
	col.add_child(center)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	center.add_child(actions)
	actions.add_child(_button("SINGLE PLAYER", _show_solo_setup))
	actions.add_child(_button("MULTIPLAYER", _show_multiplayer))
	actions.add_child(_button("QUIT", func() -> void: get_tree().quit()))
	col.add_spacer(false)
	var version_label := _text("v%s" % str(ProjectSettings.get_setting("application/config/version")), 12, MUTED)
	version_label.name = "GameVersion"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(version_label)

func _setup_header(col: VBoxContainer, title_text: String) -> void:
	var header := HBoxContainer.new()
	col.add_child(header)
	var title := _text(title_text, 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("BACK", _show_menu))

# Both setup screens use the same palette and disabled occupied swatches.
func _color_selector(players: Dictionary, id: int) -> OptionButton:
	var selector := OptionButton.new()
	selector.custom_minimum_size.x = 100
	for choice in range(1, RULES.MAX_PLAYERS + 1):
		var swatch := Image.create_empty(14, 14, false, Image.FORMAT_RGBA8)
		swatch.fill(RULES.EMPIRE_COLORS[choice])
		selector.add_icon_item(ImageTexture.create_from_image(swatch), RULES.COLOR_NAMES[choice], choice)
		selector.set_item_disabled(choice - 1, not RULES.color_available(players, id, choice))
	selector.select(int(players[id].get("color", 1)) - 1)
	return selector

func _show_solo_setup() -> void:
	screen = "solo_setup"
	solo_preview = null
	solo_random_seed = int(randi())
	solo_players.clear()
	for id in range(1, 5):
		solo_players[id] = {"team": id, "color": id}
	var col := _root()
	_setup_header(col, "Single player")
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	col.add_child(content)
	var panel := _panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 2.3
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	solo_roster = rows
	_refresh_solo_roster()
	var settings_panel := _panel()
	settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_panel.custom_minimum_size.x = 240
	content.add_child(settings_panel)
	var settings := VBoxContainer.new()
	settings.add_theme_constant_override("separation", 10)
	settings_panel.add_child(settings)
	settings.add_child(_text("Game settings", 20))
	settings.add_child(_text("Map layout", 14, MUTED))
	solo_layout_picker = _map_layout_picker()
	settings.add_child(solo_layout_picker)
	settings.add_child(_text("Map seed", 14, MUTED))
	solo_seed_edit = LineEdit.new()
	solo_seed_edit.placeholder_text = str(solo_random_seed)
	solo_seed_edit.tooltip_text = "Enter an integer seed, or leave blank to use the displayed random seed."
	var seed_row := HBoxContainer.new()
	settings.add_child(seed_row)
	solo_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(solo_seed_edit)
	seed_row.add_child(_button("Reroll", _reroll_solo_map))
	solo_preview = _new_map_preview(settings)
	solo_layout_picker.item_selected.connect(func(_index: int) -> void: _refresh_solo_preview())
	solo_seed_edit.text_changed.connect(func(_value: String) -> void: _refresh_solo_preview())
	_refresh_solo_preview()
	var footer := HBoxContainer.new()
	col.add_child(footer)
	solo_start_button = _button("START MATCH", _start_solo_from_setup)
	footer.add_spacer(false)
	footer.add_child(solo_start_button)

func _refresh_solo_roster() -> void:
	for child in solo_roster.get_children():
		solo_roster.remove_child(child)
		child.queue_free()
	solo_rows.clear()
	var headings := HBoxContainer.new()
	solo_roster.add_child(headings)
	var player_heading := _text("Player", 13, MUTED)
	player_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headings.add_child(player_heading)
	for heading in ["Color", "Team", ""]:
		var label := _text(heading, 13, MUTED)
		label.custom_minimum_size.x = 32 if heading.is_empty() else 110
		headings.add_child(label)
	for id in RULES.ordered_peers(solo_players):
		var entry: Dictionary = solo_players[id]
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 36
		solo_roster.add_child(row)
		var title := _text("Player" if id == 1 else "AI %d" % (id - 1), 15, RULES.EMPIRE_COLORS[int(entry["color"])])
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var color := _color_selector(solo_players, id)
		color.custom_minimum_size.x = 110
		color.item_selected.connect(_solo_color_selected.bind(id))
		row.add_child(color)
		var team := OptionButton.new()
		team.custom_minimum_size.x = 110
		for choice in range(1, solo_players.size() + 1):
			team.add_item("Team %d" % choice)
		team.select(int(entry["team"]) - 1)
		team.item_selected.connect(_solo_team_selected.bind(id))
		row.add_child(team)
		var remove: Button = _button("×", _remove_solo_player.bind(id))
		remove.custom_minimum_size = Vector2(32, 32)
		remove.disabled = id == 1
		remove.tooltip_text = "Remove AI player"
		row.add_child(remove)
		solo_rows[id] = {"color": color, "team": team, "remove": remove}
	var add_row := HBoxContainer.new()
	solo_roster.add_child(add_row)
	solo_add_button = _button("+ Add player", _add_solo_player)
	solo_add_button.custom_minimum_size = Vector2(140, 32)
	solo_add_button.disabled = solo_players.size() >= RULES.MAX_PLAYERS
	add_row.add_child(solo_add_button)
	_refresh_solo_preview()

func _solo_color_selected(index: int, id: int) -> void:
	if solo_players.has(id) and RULES.color_available(solo_players, id, index + 1):
		solo_players[id]["color"] = index + 1
	_refresh_solo_roster()

func _solo_team_selected(index: int, id: int) -> void:
	if solo_players.has(id) and index >= 0 and index < solo_players.size():
		solo_players[id]["team"] = index + 1

func _add_solo_player() -> void:
	if solo_players.size() >= RULES.MAX_PLAYERS:
		return
	var id: int = solo_players.size() + 1
	solo_players[id] = {"team": id, "color": RULES.free_color(solo_players)}
	_refresh_solo_roster()

func _remove_solo_player(id: int) -> void:
	if id == 1 or not solo_players.has(id):
		return
	solo_players.erase(id)
	var compact: Dictionary = {}
	for old_id in RULES.ordered_peers(solo_players):
		compact[compact.size() + 1] = solo_players[old_id]
	solo_players = compact
	# Reassign out-of-range team labels without splitting existing alliances.
	var used: Dictionary = {}
	var replacements: Dictionary = {}
	for entry in solo_players.values():
		var team: int = int(entry["team"])
		if team <= solo_players.size():
			used[team] = true
	for entry in solo_players.values():
		var team: int = int(entry["team"])
		if team > solo_players.size():
			if not replacements.has(team):
				for choice in range(1, solo_players.size() + 1):
					if not used.has(choice):
						replacements[team] = choice
						used[choice] = true
						break
			entry["team"] = replacements[team]
	_refresh_solo_roster()

func _start_solo_from_setup() -> void:
	var opponents: Array = []
	var colors: Array = []
	for id in RULES.ordered_peers(solo_players):
		colors.append(int(solo_players[id]["color"]))
		if id != 1:
			opponents.append(int(solo_players[id]["team"]))
	var seed_text: String = solo_seed_edit.text.strip_edges()
	if not seed_text.is_empty() and not seed_text.is_valid_int():
		solo_seed_edit.grab_focus()
		return
	var map_seed: int = solo_random_seed if seed_text.is_empty() else seed_text.to_int()
	network.call("start_solo", int(solo_players[1]["team"]), opponents, colors, map_seed, MAP.LAYOUTS[solo_layout_picker.selected])

func _show_multiplayer() -> void:
	screen = "multiplayer"
	var col := _root()
	_setup_header(col, "MULTIPLAYER")
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
	header.add_child(_text("Lobby", 28))
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
	var players_header := HBoxContainer.new()
	left_col.add_child(players_header)
	var players_title := _text("Players", 20)
	players_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_header.add_child(players_title)
	var add_ai_button := _button("+ Add AI", func() -> void: network.call("add_lobby_ai"))
	add_ai_button.name = "AddLobbyAI"
	players_header.add_child(add_ai_button)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.custom_minimum_size.y = 230
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_col.add_child(roster_scroll)
	roster = VBoxContainer.new()
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster.add_theme_constant_override("separation", 3)
	roster_scroll.add_child(roster)
	var layout_row := HBoxContainer.new()
	left_col.add_child(layout_row)
	layout_row.add_child(_text("Map layout", 14, MUTED))
	lobby_layout_picker = _map_layout_picker()
	lobby_layout_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_row.add_child(lobby_layout_picker)
	lobby_layout_picker.item_selected.connect(func(index: int) -> void: network.call("choose_map_layout", MAP.LAYOUTS[index]))
	var seed_row := HBoxContainer.new()
	left_col.add_child(seed_row)
	lobby_seed_label = _text("", 12, MUTED)
	lobby_seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(lobby_seed_label)
	lobby_reroll = _button("Reroll", func() -> void: network.call("reroll_lobby_map"))
	seed_row.add_child(lobby_reroll)
	lobby_preview = _new_map_preview(left_col)
	var buttons := HBoxContainer.new()
	left_col.add_child(buttons)
	ready_button = _button("READY", _toggle_ready)
	buttons.add_child(ready_button)
	start_button = _button("START MATCH", _start_match)
	buttons.add_child(start_button)

	var right := _panel()
	right.custom_minimum_size = Vector2(430, 370)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_child(right)
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 8)
	right.add_child(right_col)
	right_col.add_child(_text("Chat", 20))
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

func _reroll_solo_map() -> void:
	solo_random_seed = int(randi())
	solo_seed_edit.text = ""
	solo_seed_edit.placeholder_text = str(solo_random_seed)
	_refresh_solo_preview()

func _refresh_solo_preview() -> void:
	if not is_instance_valid(solo_preview) or not is_instance_valid(solo_seed_edit):
		return
	var value: String = solo_seed_edit.text.strip_edges()
	if not value.is_empty() and not value.is_valid_int():
		solo_preview.set_meta("map", {})
		solo_preview.set_meta("signature", [])
		solo_preview.queue_redraw()
		return
	var seed_value: int = solo_random_seed if value.is_empty() else value.to_int()
	_update_map_preview(solo_preview, solo_players, seed_value, MAP.LAYOUTS[solo_layout_picker.selected])

func _new_map_preview(parent: Container) -> Control:
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(200, 230)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(preview)
	preview.draw.connect(_draw_map_preview.bind(preview))
	preview.resized.connect(preview.queue_redraw)
	var legend := _text("Colored: starts  ·  Grey: systems  ·  Violet: antimatter", 11, MUTED)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(legend)
	return preview

func _update_map_preview(preview: Control, entries: Dictionary, seed_value: int, layout: String) -> void:
	if entries.is_empty():
		return
	var signature: Array = [seed_value, entries.size(), layout]
	if preview.get_meta("signature", []) != signature:
		preview.set_meta("map", MAP.generate(seed_value, entries.size(), layout))
		preview.set_meta("signature", signature)
	var colors: Array[Color] = []
	for id in RULES.ordered_peers(entries):
		colors.append(RULES.EMPIRE_COLORS[int(entries[id]["color"])])
	preview.set_meta("colors", colors)
	preview.queue_redraw()

func _draw_map_preview(preview: Control) -> void:
	preview.draw_rect(Rect2(Vector2.ZERO, preview.size), Color("#091522"))
	var graph: Dictionary = preview.get_meta("map", {})
	if graph.is_empty():
		return
	var points: Array = graph["points"]
	var bounds: Vector2 = graph["size"]
	var available: Vector2 = (preview.size - Vector2(24, 24)).max(Vector2.ONE)
	var scale_factor: float = minf(available.x / bounds.x, available.y / bounds.y)
	var offset: Vector2 = (preview.size - bounds * scale_factor) * 0.5
	var colors: Array = preview.get_meta("colors", [])
	for edge in graph["edges"]:
		preview.draw_line(offset + points[edge[0]] * scale_factor, offset + points[edge[1]] * scale_factor, Color("#526982"), 1.0, true)
	for asteroid in graph["fields"]:
		var center: Vector2 = offset + asteroid["position"] * scale_factor
		var special: bool = bool(asteroid.get("antimatter", false))
		var radius: float = maxf(3.0 if special else 1.5, float(asteroid["radius"]) * scale_factor)
		var tint: Color = Color("#c295ff") if special else Color("#7e6951")
		preview.draw_circle(center, radius, tint)
		if special:
			preview.draw_arc(center, radius + 2.0, 0.0, TAU, 24, tint, 1.0, true)
	for index in range(points.size()):
		var position: Vector2 = offset + points[index] * scale_factor
		var home: bool = index < colors.size()
		preview.draw_circle(position, 4.0 if home else 2.0, colors[index] if home else Color("#b0c1d2"))
		if home:
			preview.draw_arc(position, 6.0, 0.0, TAU, 20, colors[index], 1.0, true)

func _map_layout_picker() -> OptionButton:
	var picker := OptionButton.new()
	for layout in MAP.LAYOUTS:
		picker.add_item(layout)
	picker.select(0)
	picker.tooltip_text = "Radial: connected outer and inner rings, inward spokes, central antimatter. Grid: lattice clusters. Hex Grid: connected honeycomb cells. Scramble: irregular clusters. All layouts keep antimatter away from starting systems."
	return picker

func _refresh_roster() -> void:
	if screen != "lobby" or not is_instance_valid(roster):
		return
	for child in roster.get_children():
		roster.remove_child(child)
		child.queue_free()
	var roster_data: Dictionary = network.get("players")
	var is_host: bool = multiplayer.is_server()
	var is_lobby: bool = str(network.get("phase")) == "lobby"
	if is_instance_valid(lobby_layout_picker):
		lobby_layout_picker.select(maxi(0, MAP.LAYOUTS.find(str(network.get("map_layout")))))
		lobby_layout_picker.disabled = not is_lobby or not is_host
	if is_instance_valid(lobby_preview):
		var seed_value: int = int(network.get("lobby_map_seed"))
		lobby_seed_label.text = "Seed: %d" % seed_value
		lobby_reroll.visible = is_host
		lobby_reroll.disabled = not is_lobby
		_update_map_preview(lobby_preview, roster_data, seed_value, str(network.get("map_layout")))
	# The header button is a descendant of the lobby's content panel.
	var add_ai_buttons: Array = find_children("AddLobbyAI", "Button", true, false)
	if not add_ai_buttons.is_empty():
		var add_ai_button: Button = add_ai_buttons[0]
		add_ai_button.visible = is_host
		add_ai_button.disabled = not is_lobby or roster_data.size() >= RULES.MAX_PLAYERS
	for id in RULES.ordered_peers(roster_data):
		var entry: Dictionary = roster_data[id]
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 32
		row.add_theme_constant_override("separation", 8)
		roster.add_child(row)
		var ai: bool = bool(entry.get("ai", false))
		var role: String = "AI" if ai else ("HOST" if id == 1 else "GUEST")
		var label := _text("%s • %s" % [str(entry.get("name", "Player")), role], 14)
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", RULES.EMPIRE_COLORS[int(entry.get("color", 1))])
		row.add_child(label)
		var color_selector := _color_selector(roster_data, int(id))
		color_selector.disabled = not is_lobby or (id != multiplayer.get_unique_id() and not (is_host and ai))
		color_selector.item_selected.connect(_color_selected.bind(int(id)))
		row.add_child(color_selector)
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
		if ai and is_host:
			var remove_ai := _button("×", Callable(network, "remove_lobby_ai").bind(id))
			remove_ai.tooltip_text = "Remove AI player"
			remove_ai.disabled = not is_lobby
			row.add_child(remove_ai)
	for _index in range(RULES.MAX_PLAYERS - roster_data.size()):
		roster.add_child(_text("EMPTY SLOT", 13, MUTED))
	ready_button.visible = not is_host
	ready_button.disabled = not is_lobby or not roster_data.has(multiplayer.get_unique_id())
	var my_entry: Dictionary = roster_data.get(multiplayer.get_unique_id(), {})
	ready_button.text = "UNREADY" if bool(my_entry.get("ready", false)) else "READY"
	start_button.visible = is_host
	start_button.disabled = not bool(network.call("can_start"))
	if is_instance_valid(chat_edit):
		chat_edit.editable = is_lobby

func _refresh_chat() -> void:
	if screen != "lobby" or not is_instance_valid(chat_log):
		return
	chat_log.clear()
	var messages: Array = network.get("history")
	for item in messages:
		chat_log.add_text(str((item as Dictionary).get("text", "")) + "\n")

func _color_selected(index: int, id: int) -> void:
	network.call("choose_color", id, index + 1)

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

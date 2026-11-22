extends Control
## Warbound menu and lobby view; networking is owned by /root/GameSession.

const RULES = preload("res://scripts/lobby_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")
const TERRITORY = preload("res://scripts/territory_view.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const BACKDROP = preload("res://scripts/space_background.gd")
const TEXT := HUD.TEXT
const MUTED := HUD.MUTED

class MapPreview:
	extends Control
	var territory = TERRITORY.new()
	var territory_signature: Array = []

	func refresh_territory(entries: Dictionary, ordered: Array[int], colors: Array[Color]) -> void:
		var signature: Array = [get_meta("signature", []), ordered, colors]
		if signature == territory_signature:
			return
		territory_signature = signature
		territory.prepare_preview(get_meta("map", {}), entries, ordered, colors)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#091522"))
		var graph: Dictionary = get_meta("map", {})
		if graph.is_empty():
			return
		var points: Array = graph["points"]
		var bounds: Vector2 = graph["size"]
		var available: Vector2 = (size - Vector2(24, 24)).max(Vector2.ONE)
		var scale_factor: float = minf(available.x / bounds.x, available.y / bounds.y)
		var offset: Vector2 = (size - bounds * scale_factor) * 0.5
		territory.draw_claims(self, offset, bounds * scale_factor)
		var colors: Array = get_meta("colors", [])
		for asteroid in graph["fields"]:
			var center: Vector2 = offset + asteroid["position"] * scale_factor
			var special: bool = bool(asteroid.get("antimatter", false))
			var radius: float = maxf(4.0 if special else 2.0, float(asteroid["radius"]) * scale_factor)
			var tint: Color = Color("#c295ff") if special else Color("#9b8566")
			draw_circle(center, radius, tint)
			if special:
				draw_arc(center, radius + 2.0, 0.0, TAU, 24, tint, 1.0, true)
		for index in range(points.size()):
			var position: Vector2 = offset + points[index] * scale_factor
			var home: bool = index < colors.size()
			var empty: bool = graph.get("planetless", []).has(index)
			if empty:
				draw_arc(position, 2.5, 0.0, TAU, 12, Color("#8197ac"), 1.0, true)
			else:
				draw_circle(position, 5.0 if home else 2.5, colors[index] if home else Color("#b0c1d2"))
			if home:
				draw_arc(position, 6.0, 0.0, TAU, 20, colors[index], 1.0, true)

var menu_music: AudioStreamPlayer
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
var lobby_seed_edit: LineEdit
var browser_list: VBoxContainer
var lobby_reroll: Button
var solo_random_seed: int = 0

func _ready() -> void:
	theme = HUD.create()
	network = get_node("/root/GameSession")
	network.connect("phase_changed", _on_phase_changed)
	network.connect("roster_changed", _refresh_roster)
	network.connect("chat_changed", _refresh_chat)
	network.connect("status_changed", _refresh_status)
	network.connect("lobbies_changed", _refresh_browser)
	_start_menu_music()
	_on_phase_changed()

func _start_menu_music() -> void:
	if not is_inside_tree() or is_instance_valid(menu_music):
		return
	var config := ConfigFile.new()
	config.load("user://warbound_settings.cfg")
	var bus: int = AudioServer.get_bus_index("Music")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Music")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.0001, clampf(float(config.get_value("audio", "music", 100.0)), 0.0, 100.0) / 100.0)))
	AudioServer.set_bus_mute(bus, bool(config.get_value("audio", "music_muted", false)))
	menu_music = AudioStreamPlayer.new()
	add_child(menu_music)
	menu_music.bus = "Music"
	menu_music.volume_db = -3.0
	menu_music.stream = _menu_score()
	menu_music.play()

static var cached_menu_score: AudioStreamWAV

func _menu_score() -> AudioStreamWAV:
	if cached_menu_score != null:
		return cached_menu_score
	# Original 16-bar ambient score: minor ninth pads, a pulse and glass arpeggios.
	const RATE: int = 22050
	const BEAT: float = 0.625
	var chords: Array = [[45, 52, 55, 59], [41, 48, 52, 55], [48, 55, 59, 62], [43, 50, 53, 57], [45, 52, 55, 60], [41, 48, 57, 60], [38, 45, 48, 52], [43, 50, 55, 59]]
	var count: int = int(RATE * BEAT * 64.0)
	var pcm := PackedByteArray()
	pcm.resize(count * 4)
	var peak: int = 1
	for i in range(count):
		var t: float = float(i) / RATE
		var beat: float = t / BEAT
		var chord_index: int = int(beat / 8.0) % chords.size()
		var local: float = fmod(beat, 8.0) * BEAT
		var pad_env: float = minf(1.0, local / 0.8) * minf(1.0, (8.0 * BEAT - local) / 0.8)
		var left: float = 0.0
		var right: float = 0.0
		for n in range(4):
			var hz: float = 440.0 * pow(2.0, (float(chords[chord_index][n]) - 69.0) / 12.0)
			var angle: float = TAU * hz * t
			left += pad_env * (sin(angle + 0.45 * sin(TAU * 0.19 * t + n)) + 0.2 * sin(angle * 2.0)) * 0.048
			right += pad_env * (sin(angle + 0.45 * sin(TAU * 0.23 * t + n + 1.0)) + 0.2 * sin(angle * 2.0)) * 0.048
		var pulse_age: float = fmod(beat, 2.0) * BEAT
		var bass_hz: float = 440.0 * pow(2.0, (float(chords[chord_index][0]) - 81.0) / 12.0)
		var bass: float = sin(TAU * bass_hz * pulse_age) * exp(-3.0 * pulse_age) * minf(1.0, pulse_age / 0.025) * 0.11
		var step: int = int(beat * 2.0)
		var age: float = fmod(beat * 2.0, 1.0) * BEAT * 0.5
		var melody_hz: float = 440.0 * pow(2.0, (float(chords[chord_index][[0, 2, 1, 3, 2, 1, 3, 1][step % 8]]) + 24.0 - 69.0) / 12.0)
		var bell: float = (sin(TAU * melody_hz * age) + 0.25 * sin(TAU * melody_hz * 2.01 * age)) * exp(-10.0 * age) * minf(1.0, age / 0.012) * minf(1.0, (BEAT * 0.5 - age) / 0.025) * 0.075
		var edge: float = minf(1.0, t / 0.25) * minf(1.0, (float(count - i) / RATE) / 0.25)
		var sample_l: int = roundi(clampf((left + bass + bell * 0.75) * edge, -1.0, 1.0) * 30000.0)
		var sample_r: int = roundi(clampf((right + bass + bell) * edge, -1.0, 1.0) * 30000.0)
		peak = maxi(peak, maxi(absi(sample_l), absi(sample_r)))
		pcm.encode_s16(i * 4, sample_l)
		pcm.encode_s16(i * 4 + 2, sample_r)
	# Normalize once, leaving headroom; otherwise the quiet pad mix is barely audible.
	var gain: float = 28000.0 / float(peak)
	for offset in range(0, pcm.size(), 2):
		pcm.encode_s16(offset, roundi(float(pcm.decode_s16(offset)) * gain))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = true
	wav.data = pcm
	wav.loop_begin = 0
	wav.loop_end = count
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	cached_menu_score = wav
	return wav

func _root() -> VBoxContainer:
	if screen != "multiplayer":
		network.call("stop_lobby_browser")
	for child in get_children():
		if child == menu_music:
			continue
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
	_build_match_setup(true)

# Both modes use the same layout, roster, map settings and preview.
func _build_match_setup(solo: bool) -> void:
	var col := _root()
	var header := HBoxContainer.new()
	col.add_child(header)
	var title := _text("Single player" if solo else "Multiplayer lobby", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("BACK" if solo else "LEAVE", _show_menu if solo else _leave))
	if not solo:
		status_label = _text("", 13, MUTED)
		col.add_child(status_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var left := _panel()
	left.custom_minimum_size.x = 420
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(left)
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	left.add_child(left_col)
	left_col.add_child(_text("Players", 20))
	var roster_scroll := ScrollContainer.new()
	roster_scroll.custom_minimum_size.y = 300
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_col.add_child(roster_scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	roster_scroll.add_child(rows)
	if solo:
		solo_roster = rows
	else:
		roster = rows
		_build_lobby_chat(left_col)
	var right := _panel()
	right.custom_minimum_size.x = 380
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.25
	content.add_child(right)
	var settings := VBoxContainer.new()
	settings.add_theme_constant_override("separation", 8)
	right.add_child(settings)
	settings.add_child(_text("Game settings", 20))
	settings.add_child(_text("Map layout", 13, MUTED))
	var picker := _map_layout_picker()
	settings.add_child(picker)
	settings.add_child(_text("Map seed", 13, MUTED))
	var seed_row := HBoxContainer.new()
	settings.add_child(seed_row)
	var seed_edit := LineEdit.new()
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(seed_edit)
	var reroll := _button("Reroll", _reroll_solo_map if solo else func() -> void: network.call("reroll_lobby_map"))
	seed_row.add_child(reroll)
	var preview := _new_map_preview(settings)
	var footer := HBoxContainer.new()
	col.add_child(footer)
	footer.add_spacer(false)
	if solo:
		solo_layout_picker = picker
		solo_seed_edit = seed_edit
		solo_preview = preview
		seed_edit.placeholder_text = str(solo_random_seed)
		seed_edit.tooltip_text = "Enter an integer seed, or leave blank to use the displayed random seed."
		picker.item_selected.connect(func(_index: int) -> void: _refresh_solo_preview())
		seed_edit.text_changed.connect(func(_value: String) -> void: _refresh_solo_preview())
		solo_start_button = _button("START MATCH", _start_solo_from_setup)
		footer.add_child(solo_start_button)
		_refresh_solo_roster()
	else:
		lobby_layout_picker = picker
		lobby_seed_edit = seed_edit
		lobby_reroll = reroll
		lobby_preview = preview
		picker.item_selected.connect(func(index: int) -> void: network.call("choose_map_layout", MAP.LAYOUTS[index]))
		seed_edit.text_submitted.connect(func(_value: String) -> void: _apply_lobby_seed())
		seed_edit.focus_exited.connect(_apply_lobby_seed)
		ready_button = _button("READY", _toggle_ready)
		start_button = _button("START MATCH", _start_match)
		footer.add_child(ready_button)
		footer.add_child(start_button)
		_refresh_status()
		_refresh_roster()
		_refresh_chat()

func _apply_lobby_seed() -> void:
	if screen != "lobby" or not multiplayer.is_server() or not is_instance_valid(lobby_seed_edit):
		return
	var value: String = lobby_seed_edit.text.strip_edges()
	if value.is_valid_int():
		network.call("choose_lobby_seed", value.to_int())
	lobby_seed_edit.text = str(network.get("lobby_map_seed"))

func _build_lobby_chat(parent: Container) -> void:
	parent.add_child(_text("Chat", 20))
	chat_log = RichTextLabel.new()
	chat_log.custom_minimum_size.y = 120
	chat_log.scroll_following = true
	parent.add_child(chat_log)
	var chat_row := HBoxContainer.new()
	parent.add_child(chat_row)
	chat_edit = LineEdit.new()
	chat_edit.max_length = 250
	chat_edit.placeholder_text = "Type message..."
	chat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_edit.text_submitted.connect(func(_v: String) -> void: _send_chat())
	chat_row.add_child(chat_edit)
	chat_row.add_child(_button("SEND", _send_chat))

func _refresh_solo_roster() -> void:
	_build_roster_rows(solo_roster, solo_players, true)
	_refresh_solo_preview()

func _build_roster_rows(parent: VBoxContainer, entries: Dictionary, solo: bool) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	if solo:
		solo_rows.clear()
	var is_host: bool = solo or multiplayer.is_server()
	var editable: bool = solo or str(network.get("phase")) == "lobby"
	var headings := HBoxContainer.new()
	parent.add_child(headings)
	var player_heading := _text("Player", 13, MUTED)
	player_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headings.add_child(player_heading)
	for heading in ["Color"]:
		var label := _text(heading, 13, MUTED)
		label.custom_minimum_size.x = 100
		headings.add_child(label)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 40
	headings.add_child(spacer)
	for id in RULES.ordered_peers(entries):
		var entry: Dictionary = entries[id]
		var ai: bool = id != 1 if solo else bool(entry.get("ai", false))
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 36
		row.add_theme_constant_override("separation", 4)
		parent.add_child(row)
		var name_text: String = ("Player" if id == 1 else "AI %d" % (id - 1)) if solo else str(entry.get("name", "Player"))
		var title := _text(name_text, 14, RULES.EMPIRE_COLORS[int(entry.get("color", 1))])
		title.clip_text = true
		title.tooltip_text = name_text
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var color := _color_selector(entries, id)
		color.disabled = not editable or (not solo and id != multiplayer.get_unique_id() and not (is_host and ai))
		color.item_selected.connect(_solo_color_selected.bind(id) if solo else _color_selected.bind(id))
		row.add_child(color)
		if not solo and not ai:
			var ready := _text("✓" if bool(entry.get("ready", false)) else "…", 14, MUTED)
			ready.custom_minimum_size.x = 40
			ready.tooltip_text = "Ready" if bool(entry.get("ready", false)) else "Waiting"
			row.add_child(ready)
		else:
			var remove := _button("×", _remove_solo_player.bind(id) if solo else Callable(network, "remove_lobby_ai").bind(id))
			remove.custom_minimum_size = Vector2(40, 32)
			remove.disabled = not editable or not is_host or not ai
			remove.tooltip_text = "Remove AI player"
			row.add_child(remove)
			if solo:
				solo_rows[id] = {"color": color, "remove": remove}
	if is_host:
		var add_row := HBoxContainer.new()
		parent.add_child(add_row)
		var add_button := _button("+ Add player", _add_solo_player if solo else Callable(network, "add_lobby_ai"))
		add_button.disabled = not editable or entries.size() >= RULES.MAX_PLAYERS
		add_row.add_child(add_button)
		if solo:
			solo_add_button = add_button

func _solo_color_selected(index: int, id: int) -> void:
	if solo_players.has(id) and RULES.color_available(solo_players, id, index + 1):
		solo_players[id]["color"] = index + 1
	_refresh_solo_roster()

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
	for player_id in solo_players:
		solo_players[player_id]["team"] = player_id
	_refresh_solo_roster()

func _start_solo_from_setup() -> void:
	var opponents: Array = []
	var colors: Array = []
	for id in RULES.ordered_peers(solo_players):
		colors.append(int(solo_players[id]["color"]))
		if id != 1:
			opponents.append(int(id))
	var seed_text: String = solo_seed_edit.text.strip_edges()
	if not seed_text.is_empty() and not seed_text.is_valid_int():
		solo_seed_edit.grab_focus()
		return
	var map_seed: int = solo_random_seed if seed_text.is_empty() else seed_text.to_int()
	network.call("start_solo", 1, opponents, colors, map_seed, MAP.LAYOUTS[solo_layout_picker.selected])

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
	var browser_panel := _panel()
	browser_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(browser_panel)
	var browser := VBoxContainer.new()
	browser_panel.add_child(browser)
	var browser_header := HBoxContainer.new()
	browser.add_child(browser_header)
	var browser_title := _text("Available games (LAN)", 20)
	browser_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser_header.add_child(browser_title)
	browser_header.add_child(_button("REFRESH", func() -> void: network.call("start_lobby_browser", address_edit.text)))
	var browser_scroll := ScrollContainer.new()
	browser_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browser_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	browser.add_child(browser_scroll)
	browser_list = VBoxContainer.new()
	browser_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser_scroll.add_child(browser_list)
	network.call("start_lobby_browser", address_edit.text)
	_refresh_browser()

func _refresh_browser() -> void:
	if screen != "multiplayer" or not is_instance_valid(browser_list):
		return
	for child in browser_list.get_children():
		browser_list.remove_child(child)
		child.queue_free()
	var available: Dictionary = network.get("discovered_lobbies")
	if available.is_empty():
		var empty := _text("No games discovered. Direct IP joining is still available.", 14, MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		browser_list.add_child(empty)
		return
	var addresses: Array = available.keys()
	addresses.sort()
	for address in addresses:
		var info: Dictionary = available[address]
		var row := HBoxContainer.new()
		browser_list.add_child(row)
		var label := _text("%s · %d/8 · %s · %s" % [info["name"], int(info["players"]), info["layout"], address], 14)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.tooltip_text = label.text
		row.add_child(label)
		var join_button := _button("JOIN GAME", _join_discovered.bind(str(address)))
		row.add_child(join_button)

func _join_discovered(address: String) -> void:
	address_edit.text = address
	_join()

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
	_build_match_setup(false)

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
	var preview := MapPreview.new()
	preview.custom_minimum_size = Vector2(340, 320)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(preview)
	preview.resized.connect(preview.queue_redraw)
	var legend := _text("Colored: starts and territory  ·  Solid: planetary systems  ·  Hollow: planetless  ·  Brown: asteroids  ·  Violet: antimatter", 11, MUTED)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(legend)
	return preview

func _update_map_preview(preview: Control, entries: Dictionary, seed_value: int, layout: String) -> void:
	if entries.is_empty():
		preview.set_meta("map", {})
		preview.set_meta("signature", [])
		preview.queue_redraw()
		return
	var signature: Array = [seed_value, entries.size(), layout]
	if preview.get_meta("signature", []) != signature:
		preview.set_meta("map", MAP.generate(seed_value, entries.size(), layout))
		preview.set_meta("signature", signature)
	var colors: Array[Color] = []
	var ordered: Array[int] = []
	ordered.assign(RULES.ordered_peers(entries))
	for id in ordered:
		colors.append(RULES.EMPIRE_COLORS[int(entries[id]["color"])])
	preview.set_meta("colors", colors)
	(preview as MapPreview).refresh_territory(entries, ordered, colors)
	preview.queue_redraw()

func _map_layout_picker() -> OptionButton:
	var picker := OptionButton.new()
	for layout in MAP.LAYOUTS:
		picker.add_item(layout)
	picker.select(0)
	picker.tooltip_text = "Galaxy layout"
	return picker

func _refresh_roster() -> void:
	if screen != "lobby" or not is_instance_valid(roster):
		return
	var roster_data: Dictionary = network.get("players")
	var is_host: bool = multiplayer.is_server()
	var is_lobby: bool = str(network.get("phase")) == "lobby"
	_build_roster_rows(roster, roster_data, false)
	lobby_layout_picker.select(maxi(0, MAP.LAYOUTS.find(str(network.get("map_layout")))))
	lobby_layout_picker.disabled = not is_lobby or not is_host
	var seed_value: int = int(network.get("lobby_map_seed"))
	if not lobby_seed_edit.has_focus():
		lobby_seed_edit.text = str(seed_value)
	lobby_seed_edit.editable = is_lobby and is_host
	lobby_reroll.visible = is_host
	lobby_reroll.disabled = not is_lobby
	_update_map_preview(lobby_preview, roster_data, seed_value, str(network.get("map_layout")))
	ready_button.visible = not is_host
	ready_button.disabled = not is_lobby or not roster_data.has(multiplayer.get_unique_id())
	var my_entry: Dictionary = roster_data.get(multiplayer.get_unique_id(), {})
	ready_button.text = "UNREADY" if bool(my_entry.get("ready", false)) else "READY"
	start_button.visible = is_host
	start_button.disabled = not bool(network.call("can_start"))
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


func _toggle_ready() -> void:
	network.call("toggle_ready")

func _start_match() -> void:
	_apply_lobby_seed()
	network.call("start_match")

func _send_chat() -> void:
	if not is_instance_valid(chat_edit) or chat_edit.text.strip_edges().is_empty():
		return
	network.call("send_chat", chat_edit.text)
	chat_edit.clear()

func _leave() -> void:
	network.call("leave_session")
	_show_multiplayer()

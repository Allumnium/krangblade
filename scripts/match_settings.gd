extends RefCounted
## Local saved preferences and settings/hotkey editor. No simulation state.
const HUD = preload("res://scripts/ui_theme.gd")
const HOTKEYS = preload("res://scripts/command_hotkeys.gd")
const CARD_UI = preload("res://scripts/command_card_ui.gd")

var settings := ConfigFile.new()
var music_volume: float = 100.0
var sfx_volume: float = 100.0
var music_muted: bool = false
var sfx_muted: bool = false
var hotkey_dialog: AcceptDialog
var hotkey_status: Label
var hotkey_pickers: Dictionary = {}
var keyboard_pan_percent: float = 100.0
var mouse_pan_percent: float = 100.0
var wheel_zoom_percent: float = 100.0

var hotkeys: HOTKEYS
var command_card_ui: CARD_UI
var background_music: AudioStreamPlayer
var match_menu: AcceptDialog
var make_label: Callable
var make_button: Callable
var make_icon: Callable
var viewport_rect: Callable

func configure(music: AudioStreamPlayer, bindings: HOTKEYS, cards: CARD_UI, label_factory: Callable, button_factory: Callable, icon_factory: Callable, viewport_query: Callable) -> void:
	background_music = music
	hotkeys = bindings
	command_card_ui = cards
	make_label = label_factory
	make_button = button_factory
	make_icon = icon_factory
	viewport_rect = viewport_query

func load_settings() -> void:
	settings.load("user://warbound_settings.cfg")
	# Ignore obsolete scaling preferences from earlier releases.
	if settings.has_section_key("interface", "scale"):
		settings.erase_section_key("interface", "scale")
	music_volume = clampf(float(settings.get_value("audio", "music", 100.0)), 0.0, 100.0)
	sfx_volume = clampf(float(settings.get_value("audio", "sfx", 100.0)), 0.0, 100.0)
	music_muted = bool(settings.get_value("audio", "music_muted", false))
	sfx_muted = bool(settings.get_value("audio", "sfx_muted", false))
	keyboard_pan_percent = clampf(float(settings.get_value("camera", "keyboard_pan", 100.0)), 0.0, 250.0)
	mouse_pan_percent = clampf(float(settings.get_value("camera", "edge_pan", 100.0)), 0.0, 250.0)
	wheel_zoom_percent = clampf(float(settings.get_value("camera", "wheel_zoom", 100.0)), 25.0, 250.0)

func apply_settings() -> void:
	for bus_name in ["Music", "SFX"]:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
		var volume: float = music_volume if bus_name == "Music" else sfx_volume
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, volume / 100.0)))
		AudioServer.set_bus_mute(index, music_muted if bus_name == "Music" else sfx_muted)
	background_music.bus = "Music"

func _save_settings() -> void:
	settings.set_value("audio", "music", music_volume)
	settings.set_value("audio", "sfx", sfx_volume)
	settings.set_value("audio", "music_muted", music_muted)
	settings.set_value("audio", "sfx_muted", sfx_muted)
	settings.set_value("camera", "keyboard_pan", keyboard_pan_percent)
	settings.set_value("camera", "edge_pan", mouse_pan_percent)
	settings.set_value("camera", "wheel_zoom", wheel_zoom_percent)
	if settings.has_section("hotkeys"):
		settings.erase_section("hotkeys")
	for id in hotkeys.overrides:
		settings.set_value("hotkeys", id, hotkeys.overrides[id])
	settings.save("user://warbound_settings.cfg")
	apply_settings()

func build_menu(menu: AcceptDialog) -> void:
	match_menu = menu
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	options.custom_minimum_size.x = 340
	match_menu.add_child(options)
	options.add_child(make_label.call("Menu", 20))
	for channel in ["Music", "SFX"]:
		var row := HBoxContainer.new()
		options.add_child(row)
		row.add_theme_constant_override("separation", 10)
		var channel_label: Label = make_label.call(channel, 14)
		channel_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		channel_label.custom_minimum_size.x = 64
		channel_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(channel_label)
		var volume := HSlider.new()
		volume.max_value = 100.0
		volume.step = 1.0
		volume.value = music_volume if channel == "Music" else sfx_volume
		volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		volume.custom_minimum_size = Vector2(120, 24)
		row.add_child(volume)
		var mute := Button.new()
		mute.toggle_mode = true
		mute.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mute.custom_minimum_size = Vector2(36, 30)
		mute.button_pressed = music_muted if channel == "Music" else sfx_muted
		_set_mute_icon(mute, mute.button_pressed)
		row.add_child(mute)
		volume.value_changed.connect(_audio_volume_changed.bind(channel))
		mute.toggled.connect(func(value: bool) -> void:
			_set_mute_icon(mute, value)
			_audio_mute_changed(value, channel))
	options.add_child(HSeparator.new())
	_add_camera_setting(options, "Keyboard scroll speed", "keyboard", keyboard_pan_percent, 0.0)
	_add_camera_setting(options, "Mouse edge scroll speed", "edge", mouse_pan_percent, 0.0)
	_add_camera_setting(options, "Mouse wheel zoom speed", "wheel", wheel_zoom_percent, 25.0)
	make_button.call("Hotkeys…", _open_hotkey_editor, options)

func _add_camera_setting(parent: Container, title_text: String, kind: String, initial: float, minimum: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var caption: Label = make_label.call(title_text, 13)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.custom_minimum_size.x = 170
	row.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = 250.0
	slider.step = 5.0
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(100, 24)
	row.add_child(slider)
	var value_label: Label = make_label.call("%d%%" % roundi(initial), 12)
	value_label.custom_minimum_size.x = 45
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % roundi(value)
		match kind:
			"keyboard": keyboard_pan_percent = value
			"edge": mouse_pan_percent = value
			"wheel": wheel_zoom_percent = value
		_save_settings())

func _open_hotkey_editor() -> void:
	if not is_instance_valid(hotkey_dialog):
		hotkey_dialog = AcceptDialog.new()
		hotkey_dialog.title = "Hotkeys"
		hotkey_dialog.borderless = true
		hotkey_dialog.theme = match_menu.theme
		hotkey_dialog.exclusive = true
		hotkey_dialog.transient = true
		hotkey_dialog.unresizable = true
		hotkey_dialog.ok_button_text = "Done"
		match_menu.add_child(hotkey_dialog)
		var body := VBoxContainer.new()
		hotkey_dialog.add_child(body)
		body.add_child(make_label.call("Hotkeys", 20))
		body.add_child(make_label.call("Choose a key for each command. Keys may be reused on different cards.", 13))
		var viewport_size: Vector2 = (viewport_rect.call() as Rect2).size
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(minf(510.0, viewport_size.x - 70.0), clampf(viewport_size.y - 230.0, 120.0, 380.0))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(scroll)
		var rows := VBoxContainer.new()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(rows)
		for scope in ["General", "Fleet", "Shipyard", "Station", "Station Build", "Station Trade", "Asteroid Field"]:
			var heading: Label = make_label.call(scope.to_upper(), 13)
			heading.add_theme_color_override("font_color", HUD.ACCENT)
			rows.add_child(heading)
			for id in hotkeys.entries:
				var entry: Dictionary = hotkeys.entries[id]
				if entry["scope"] != scope:
					continue
				var row := HBoxContainer.new()
				rows.add_child(row)
				var caption: Label = make_label.call(str(entry["title"]), 13)
				caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(caption)
				var picker := OptionButton.new()
				picker.custom_minimum_size.x = 92
				var default_key: int = int(entry["default"])
				if default_key == KEY_ESCAPE:
					picker.add_item("Esc (fixed)", KEY_ESCAPE)
					picker.disabled = true
				else:
					for key in range(KEY_A, KEY_Z + 1):
						picker.add_item(hotkeys.key_name(key), key)
					for key in range(KEY_F1, KEY_F12 + 1):
						picker.add_item(hotkeys.key_name(key), key)
				row.add_child(picker)
				hotkey_pickers[id] = picker
				picker.item_selected.connect(_hotkey_changed.bind(str(id), picker))
		body.add_child(make_label.call("Fixed: arrow keys, Esc, 0–9 control groups and mouse gestures.", 12))
		hotkey_status = make_label.call("", 13)
		hotkey_status.custom_minimum_size.y = 26
		body.add_child(hotkey_status)
		make_button.call("Reset all to defaults", _reset_hotkeys, body)
	_refresh_hotkey_pickers()
	hotkey_status.text = ""
	hotkey_dialog.popup_centered()

func _refresh_hotkey_pickers() -> void:
	for id in hotkey_pickers:
		var picker: OptionButton = hotkey_pickers[id]
		var index: int = picker.get_item_index(hotkeys.value(id, hotkeys.overrides))
		if index >= 0:
			picker.select(index)

func _hotkey_changed(index: int, id: String, picker: OptionButton) -> void:
	var key: int = picker.get_item_id(index)
	var conflict: String = hotkeys.conflict(id, key, hotkeys.overrides)
	if not conflict.is_empty():
		hotkey_status.text = "%s is already assigned to %s." % [hotkeys.key_name(key), conflict]
		_refresh_hotkey_pickers()
		return
	if key == int(hotkeys.entries[id]["default"]):
		hotkeys.overrides.erase(id)
	else:
		hotkeys.overrides[id] = key
	hotkeys.sync_bindings(command_card_ui)
	_save_settings()
	hotkey_status.text = "Saved."

func _reset_hotkeys() -> void:
	hotkeys.overrides.clear()
	hotkeys.sync_bindings(command_card_ui)
	_refresh_hotkey_pickers()
	_save_settings()
	hotkey_status.text = "Default hotkeys restored."

func _set_mute_icon(button: Button, muted: bool) -> void:
	var speaker: String = '<path d="M4 12H10L17 6V26L10 20H4Z"/>'
	button.icon = make_icon.call(speaker + ('<path d="M4 29L29 4"/>' if muted else '<path d="M21 11Q27 16 21 21M25 7Q32 16 25 25"/>'))
	command_card_ui.set_hint(button, "Unmute" if muted else "Mute")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 24)

func _audio_volume_changed(value: float, channel: String) -> void:
	if channel == "Music":
		music_volume = value
	else:
		sfx_volume = value
	_save_settings()

func _audio_mute_changed(value: bool, channel: String) -> void:
	if channel == "Music":
		music_muted = value
	else:
		sfx_muted = value
	_save_settings()


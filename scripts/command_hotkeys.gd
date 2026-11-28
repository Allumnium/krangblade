extends RefCounted
## Client-only command registry, key conflicts, badges and dispatch.
## match_settings owns settings persistence and the editor dialog.
var entries: Dictionary = {}
var overrides: Dictionary = {}
var _buttons_by_key: Dictionary = {}

func register(button: Button, key: int, scope: String, id: String, title_text: String) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#e3f3ff"))
	label.add_theme_color_override("font_outline_color", Color("#101b29"))
	label.add_theme_constant_override("outline_size", 3)
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.offset_left = -34.0
	label.offset_right = -2.0
	label.offset_top = 0.0
	label.offset_bottom = 18.0
	entries[id] = {"scope": scope, "title": title_text, "default": key, "button": button, "badge": label}

func value(id: String, candidate: Dictionary) -> int:
	return int(candidate.get(id, entries[id]["default"]))

func key_name(key: int) -> String:
	return "Esc" if key == KEY_ESCAPE else OS.get_keycode_string(key)

func conflict(id: String, key: int, candidate: Dictionary) -> String:
	var scope: String = entries[id]["scope"]
	for other in entries:
		if other == id:
			continue
		# Construction ships cannot use Auto-Repair; these two main-card actions never coexist.
		if (id == "fleet_build" and other == "fleet_auto_repair") or (id == "fleet_auto_repair" and other == "fleet_build"):
			continue
		var other_scope: String = entries[other]["scope"]
		if (scope == other_scope or scope == "General" or other_scope == "General") and value(other, candidate) == key:
			return str(entries[other]["title"])
	return ""

func load_overrides(settings: ConfigFile, card_ui: RefCounted) -> void:
	var candidate: Dictionary = {}
	for id in entries:
		var default_key: int = int(entries[id]["default"])
		var key: int = int(settings.get_value("hotkeys", id, default_key))
		if default_key != KEY_ESCAPE and ((key >= KEY_A and key <= KEY_Z) or (key >= KEY_F1 and key <= KEY_F12)) and key != default_key:
			candidate[id] = key
	for id in candidate.keys():
		if not conflict(id, int(candidate[id]), candidate).is_empty():
			candidate.clear()
			break
	overrides = candidate
	sync_bindings(card_ui)

func sync_bindings(card_ui: RefCounted) -> void:
	_buttons_by_key.clear()
	for id in entries:
		var entry: Dictionary = entries[id]
		if not entry.has("button"):
			continue
		var button: Button = entry["button"]
		var key: int = value(id, overrides)
		var hint: String = key_name(key)
		var old: String = str(button.get_meta("hotkey", ""))
		if not old.is_empty():
			card_ui.set_hint(button, card_ui.hint(button).replace("\n[" + old + "]", "").replace(" [" + old + "]", ""))
			if card_ui.hint(button) == "[" + old + "]":
				card_ui.set_hint(button, "")
		button.set_meta("hotkey", hint)
		card_ui.set_hint(button, card_ui.hint(button) + ("\n" if not card_ui.hint(button).is_empty() else "") + "[" + hint + "]")
		var badge: Label = entry["badge"]
		badge.text = hint
		var shortcuts: Array = _buttons_by_key.get(key, [])
		shortcuts.append(button)
		_buttons_by_key[key] = shortcuts

func trigger(key: int) -> bool:
	for candidate in _buttons_by_key.get(key, []):
		var button: Button = candidate
		if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
			button.pressed.emit()
			return true
	return false

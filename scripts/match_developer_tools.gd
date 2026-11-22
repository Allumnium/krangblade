extends RefCounted
## Local developer console and performance overlay. Session owns authority and metrics.
const HUD = preload("res://scripts/ui_theme.gd")

var session: Node
var time_buttons: Dictionary = {}
var dev_mode: bool = false
var dev_speed_row: HBoxContainer
var dev_console: Window
var dev_console_output: TextEdit
var dev_console_entry: LineEdit
var diagnostic_label: Label
var diagnostic_button: Button
var diagnostic_elapsed: float = 0.0
var diagnostic_last_bytes: int = -1
var diagnostic_last_full_count: int = 0
var diagnostic_last_motion_count: int = 0

func build_perf(owner: Control, parent: Container, make_button: Callable, make_label: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	diagnostic_button = make_button.call("Perf", func() -> void: diagnostic_label.visible = not diagnostic_label.visible, row)
	diagnostic_button.custom_minimum_size.y = 23
	diagnostic_button.focus_mode = Control.FOCUS_NONE
	diagnostic_button.tooltip_text = "Toggle local performance diagnostics"
	diagnostic_label = make_label.call("", 11)
	diagnostic_label.z_index = 5
	owner.add_child(diagnostic_label)
	diagnostic_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	diagnostic_label.offset_left = -220
	diagnostic_label.offset_right = 220
	diagnostic_label.offset_top = -76
	diagnostic_label.offset_bottom = -52
	diagnostic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diagnostic_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagnostic_label.hide()

func _set_time_speed(speed: int) -> void:
	if not dev_mode or not OS.is_debug_build():
		return
	session.call("request_time_speed", speed)
	refresh_speed(session.get("economy"))

func refresh_speed(state: Dictionary) -> void:
	var current: int = int(state.get("time_speed", 1))
	var can_change: bool = dev_mode and (bool(session.get("is_solo")) or session.multiplayer.is_server()) and str(session.get("phase")) == "match" and state.get("match_result", {}).is_empty()
	for speed in time_buttons:
		var button: Button = time_buttons[speed]
		var active: bool = int(speed) == current
		button.disabled = not can_change
		button.set_pressed_no_signal(active)
		# Keep the replicated speed visible even after the match ends.
		if active:
			button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("pressed"))
			button.add_theme_color_override("font_disabled_color", HUD.ACCENT)
		else:
			button.remove_theme_stylebox_override("disabled")
			button.remove_theme_color_override("font_disabled_color")

func layout_perf(height: float) -> void:
	diagnostic_label.offset_bottom = -20.0 - height
	diagnostic_label.offset_top = -44.0 - height

func update_perf(delta: float) -> void:
	if is_instance_valid(diagnostic_label):
		diagnostic_elapsed += delta
		if diagnostic_elapsed >= 1.0:
			var authority: bool = bool(session.get("is_solo")) or session.multiplayer.is_server()
			var bytes: int = int(session.get("diagnostic_sent_bytes" if authority else "diagnostic_received_bytes"))
			var throughput: float = float(maxi(0, bytes - diagnostic_last_bytes)) / diagnostic_elapsed / 1024.0 if diagnostic_last_bytes >= 0 else 0.0
			diagnostic_last_bytes = bytes
			if diagnostic_label.visible:
				var timing: String = " · sim %.2f ms · encode %.2f ms" % [float(session.get("diagnostic_sim_ms")), float(session.get("diagnostic_encode_ms"))] if authority else ""
				var net: Dictionary = session.call("network_diagnostics")
				if not net.is_empty():
					timing += " · %.0f ms RTT · %.1f%% reliable loss" % [float(net["ping"]), float(net["loss"])]
				if not authority:
					var now: int = Time.get_ticks_msec()
					var last_full: int = int(session.get("diagnostic_last_full_ms"))
					var last_motion: int = int(session.get("diagnostic_last_motion_ms"))
					var full_count: int = int(session.get("diagnostic_full_received"))
					var motion_count: int = int(session.get("diagnostic_motion_received"))
					timing += " · decode %.2f ms · state %.1f Hz / %s · motion %.1f Hz / %s" % [float(session.get("diagnostic_decode_ms")), float(maxi(0, full_count - diagnostic_last_full_count)) / diagnostic_elapsed, "%d ms" % (now - last_full) if last_full >= 0 else "—", float(maxi(0, motion_count - diagnostic_last_motion_count)) / diagnostic_elapsed, "%d ms" % (now - last_motion) if last_motion >= 0 else "—"]
					diagnostic_last_full_count = full_count
					diagnostic_last_motion_count = motion_count
				var phases: Dictionary = session.get("diagnostic_sim_phases") if authority else {}
				var ranked: Array = phases.keys()
				ranked.sort_custom(func(a: String, b: String) -> bool: return int(phases[a]) > int(phases[b]))
				var summary: PackedStringArray = []
				for stage in ranked:
					summary.append("%s %.1fms" % [stage, float(phases[stage]) / 1000.0])
				var hotspot: String = (" · " + summary[0]) if not summary.is_empty() else ""
				diagnostic_label.text = "%d FPS%s%s · %.1f KiB snapshot · %.1f KiB/s payload" % [Engine.get_frames_per_second(), timing, hotspot, float(session.get("diagnostic_snapshot_bytes")) / 1024.0, throughput]
				diagnostic_button.tooltip_text = "Toggle local performance diagnostics\n" + "\n".join(summary)
			diagnostic_elapsed = 0.0

func has_console() -> bool:
	return is_instance_valid(dev_console)

func console_visible() -> bool:
	return has_console() and dev_console.visible

func close_console() -> void:
	dev_console.hide()

func open_console() -> void:
	dev_console.popup_centered(Vector2i(540, 280))
	dev_console_entry.grab_focus()

func is_console_toggle_key(event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_QUOTELEFT or event.keycode in [KEY_QUOTELEFT, KEY_ASCIITILDE]

func build_console(owner: Control, make_button: Callable) -> void:
	dev_console = Window.new()
	dev_console.title = "Development console"
	dev_console.theme = owner.theme
	dev_console.transient = true
	dev_console.exclusive = true
	dev_console.unresizable = true
	dev_console.visible = false
	owner.add_child(dev_console)
	dev_console.close_requested.connect(dev_console.hide)
	dev_console.window_input.connect(_dev_console_window_input)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928"), Color("#45617b"), 8, 4))
	dev_console.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	dev_console_output = TextEdit.new()
	dev_console_output.editable = false
	dev_console_output.focus_mode = Control.FOCUS_NONE
	dev_console_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dev_console_output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(dev_console_output)
	dev_console_entry = LineEdit.new()
	dev_console_entry.placeholder_text = "Enter command (help for commands)"
	content.add_child(dev_console_entry)
	dev_speed_row = HBoxContainer.new()
	content.add_child(dev_speed_row)
	for speed in [0, 1, 2, 5]:
		var label: String = "Ⅱ" if speed == 0 else "%d×" % speed
		var button: Button = make_button.call(label, _set_time_speed.bind(int(speed)), dev_speed_row)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(26, 23)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		time_buttons[speed] = button
	dev_speed_row.hide()
	dev_console_entry.text_submitted.connect(_dev_console_submit)
	_dev_console_print("Development console — type /devmode to expose developer controls. Type help for commands.")

func _dev_console_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (is_console_toggle_key(event) or event.keycode == KEY_ESCAPE):
		dev_console.set_input_as_handled()
		dev_console.hide()

func _dev_console_print(value: String) -> void:
	var output: String = dev_console_output.text + ("\n" if not dev_console_output.text.is_empty() else "") + value
	dev_console_output.text = output.right(12000)
	dev_console_output.set_caret_line(dev_console_output.get_line_count() - 1)
	dev_console_output.scroll_vertical = dev_console_output.get_line_count()

func _dev_console_submit(raw: String) -> void:
	dev_console_entry.clear()
	var words: PackedStringArray = raw.strip_edges().split(" ", false)
	if words.is_empty() or not OS.is_debug_build():
		return
	_dev_console_print("> " + raw)
	match words[0].to_lower():
		"/devmode":
			dev_mode = not dev_mode
			dev_speed_row.visible = dev_mode
			refresh_speed(session.get("economy"))
			_dev_console_print("Developer controls enabled." if dev_mode else "Developer controls hidden.")
		"help":
			_dev_console_print("help · clear · status · /devmode" + (" · speed <0|1|2|5> (host/solo)" if dev_mode else ""))
		"clear":
			dev_console_output.clear()
		"status":
			var state: Dictionary = session.get("economy")
			_dev_console_print("Ships: %d | Speed: %dx | Elapsed years: %.1f" % [state.get("ships", []).size(), int(state.get("time_speed", 1)), float(state.get("elapsed", 0.0))])
		"speed":
			if not dev_mode:
				_dev_console_print("Enable /devmode first.")
			elif not bool(session.get("is_solo")) and not session.multiplayer.is_server():
				_dev_console_print("Only the host can change simulation speed here.")
			elif words.size() != 2 or not words[1].is_valid_int() or int(words[1]) not in [0, 1, 2, 5]:
				_dev_console_print("Usage: speed <0|1|2|5>")
			else:
				session.call("request_time_speed", int(words[1]))
				_dev_console_print("Speed request: %sx" % words[1])
		_:
			_dev_console_print("Unknown command. Type help.")

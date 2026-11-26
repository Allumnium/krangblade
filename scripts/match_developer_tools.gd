extends RefCounted
## Local developer console and performance overlay. Session owns authority and metrics.
const HUD = preload("res://scripts/ui_theme.gd")

var session: Node
var time_buttons: Dictionary = {}
var dev_mode: bool = false
var dev_speed_row: HBoxContainer
var console_output: Callable
var console_clear: Callable
var diagnostic_label: Label
var diagnostic_panel: VBoxContainer
var diagnostic_bars: VBoxContainer
var diagnostic_button: Button
var diagnostic_elapsed: float = 0.0
var diagnostic_last_bytes: int = -1
var diagnostic_last_full_count: int = 0
var diagnostic_last_motion_count: int = 0

func build_perf(owner: Control, parent: Container, make_button: Callable, make_label: Callable, make_icon: Callable, strip_width: float) -> void:
	diagnostic_button = make_button.call("", func() -> void: diagnostic_panel.visible = not diagnostic_panel.visible, parent)
	diagnostic_button.icon = make_icon.call('<path d="M3 25H29M5 23V16H10V23M13 23V8H18V23M21 23V12H26V23"/>', 32)
	diagnostic_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diagnostic_button.expand_icon = true
	diagnostic_button.add_theme_constant_override("icon_max_width", 24)
	diagnostic_button.custom_minimum_size = Vector2.ONE * strip_width
	diagnostic_button.focus_mode = Control.FOCUS_NONE
	diagnostic_button.tooltip_text = "Diagnostics"
	diagnostic_panel = VBoxContainer.new()
	diagnostic_panel.z_index = 5
	diagnostic_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(diagnostic_panel)
	diagnostic_panel.position = Vector2(14, 70)
	diagnostic_panel.add_theme_constant_override("separation", 3)
	diagnostic_label = make_label.call("", 11)
	diagnostic_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagnostic_panel.add_child(diagnostic_label)
	diagnostic_bars = VBoxContainer.new()
	diagnostic_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagnostic_bars.add_theme_constant_override("separation", 2)
	diagnostic_panel.add_child(diagnostic_bars)
	diagnostic_panel.hide()

func _diagnostic_bar(title: String, value: float, maximum: float, unit: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagnostic_bars.add_child(row)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.custom_minimum_size.x = 112
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(120, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.max_value = maxf(maximum, 0.001)
	bar.step = 0.0
	bar.value = value
	bar.add_theme_stylebox_override("background", HUD.surface(Color("#101c29"), Color("#284661"), 1, 0))
	bar.add_theme_stylebox_override("fill", HUD.surface(Color("#4a9bc8"), Color("#4a9bc8"), 1, 0))
	row.add_child(bar)
	var amount := Label.new()
	amount.text = "%.2f %s" % [value, unit]
	amount.add_theme_font_size_override("font_size", 11)
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(amount)


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
		if button.disabled == can_change:
			button.disabled = not can_change
		# A rejected request can leave a locally toggled button out of sync.
		# Always reconcile actual state, even when the authority speed is unchanged.
		if button.button_pressed != active:
			button.set_pressed_no_signal(active)
		# Theme override writes invalidate layout/theme caches even on hidden
		# controls. Only change overrides when their actual values differ.
		if active:
			var pressed_style: StyleBox = button.get_theme_stylebox("pressed")
			if not button.has_theme_stylebox_override("disabled") or not is_same(button.get_theme_stylebox("disabled"), pressed_style):
				button.add_theme_stylebox_override("disabled", pressed_style)
			if not button.has_theme_color_override("font_disabled_color") or button.get_theme_color("font_disabled_color") != HUD.ACCENT:
				button.add_theme_color_override("font_disabled_color", HUD.ACCENT)
		else:
			if button.has_theme_stylebox_override("disabled"):
				button.remove_theme_stylebox_override("disabled")
			if button.has_theme_color_override("font_disabled_color"):
				button.remove_theme_color_override("font_disabled_color")

func update_perf(delta: float) -> void:
	if is_instance_valid(diagnostic_label):
		diagnostic_elapsed += delta
		if diagnostic_elapsed >= 1.0:
			var authority: bool = bool(session.get("is_solo")) or session.multiplayer.is_server()
			var bytes: int = int(session.get("diagnostic_sent_bytes" if authority else "diagnostic_received_bytes"))
			var throughput: float = float(maxi(0, bytes - diagnostic_last_bytes)) / diagnostic_elapsed / 1024.0 if diagnostic_last_bytes >= 0 else 0.0
			diagnostic_last_bytes = bytes
			if diagnostic_panel.visible:
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
				diagnostic_label.text = "%d FPS\n%.1f KiB snapshot · %.1f KiB/s payload" % [Engine.get_frames_per_second(), float(session.get("diagnostic_snapshot_bytes")) / 1024.0, throughput]
				var threaded: bool = authority and bool(session.get("threaded_authority_active"))
				if threaded:
					diagnostic_label.text += "\nWorker · %d overruns" % int(session.get("diagnostic_worker_overruns"))
				for child in diagnostic_bars.get_children():
					diagnostic_bars.remove_child(child)
					child.queue_free()
				var timing_max: float = maxf(1.0, float(session.get("diagnostic_sim_ms")) if authority else float(session.get("diagnostic_decode_ms")))
				if authority:
					timing_max = maxf(timing_max, float(session.get("diagnostic_encode_ms")))
					if threaded:
						timing_max = maxf(timing_max, float(session.get("diagnostic_worker_snapshot_ms")))
					_diagnostic_bar("Simulation (worker)" if threaded else "Simulation", float(session.get("diagnostic_sim_ms")), timing_max, "ms")
					if threaded:
						_diagnostic_bar("Worker snapshot", float(session.get("diagnostic_worker_snapshot_ms")), timing_max, "ms")
					_diagnostic_bar("Encode", float(session.get("diagnostic_encode_ms")), timing_max, "ms")
				else:
					_diagnostic_bar("Decode", float(session.get("diagnostic_decode_ms")), timing_max, "ms")
				for stage in ranked:
					_diagnostic_bar(str(stage), float(phases[stage]) / 1000.0, timing_max, "ms")
				if not net.is_empty():
					_diagnostic_bar("RTT", float(net["ping"]), maxf(100.0, float(net["ping"])), "ms")
					_diagnostic_bar("Reliable loss", float(net["loss"]), 100.0, "%")
				if not authority:
					diagnostic_label.text += "\n" + timing.strip_edges()
				diagnostic_button.tooltip_text = "Diagnostics"

			diagnostic_elapsed = 0.0

func build_chat_controls(parent: Container, make_button: Callable, output: Callable, clear: Callable) -> void:
	console_output = output
	console_clear = clear
	dev_speed_row = HBoxContainer.new()
	parent.add_child(dev_speed_row)
	for speed in [0, 1, 2, 5]:
		var label: String = "Ⅱ" if speed == 0 else "%d×" % speed
		var button: Button = make_button.call(label, _set_time_speed.bind(int(speed)), dev_speed_row)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(26, 23)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		time_buttons[speed] = button
	dev_speed_row.hide()

func _dev_console_print(value: String) -> void:
	console_output.call(value)

func submit_command(raw: String) -> void:
	var words: PackedStringArray = raw.strip_edges().split(" ", false)
	if words.is_empty() or not raw.begins_with("/") or not OS.is_debug_build() or not console_output.is_valid():
		return
	if words[0].to_lower() != "/clear":
		_dev_console_print("> " + raw)
	match words[0].to_lower():
		"/devmode":
			dev_mode = not dev_mode
			dev_speed_row.visible = dev_mode
			refresh_speed(session.get("economy"))
			_dev_console_print("Developer controls enabled." if dev_mode else "Developer controls hidden.")
		"/help":
			_dev_console_print("/help · /clear · /status · /devmode" + (" · /speed <0|1|2|5> (host/solo)" if dev_mode else ""))
		"/clear":
			console_clear.call()
		"/status":
			var state: Dictionary = session.get("economy")
			_dev_console_print("Ships: %d | Speed: %dx | Elapsed years: %.1f" % [state.get("ships", []).size(), int(state.get("time_speed", 1)), float(state.get("elapsed", 0.0))])
		"/speed":
			if not dev_mode:
				_dev_console_print("Enable /devmode first.")
			elif not bool(session.get("is_solo")) and not session.multiplayer.is_server():
				_dev_console_print("Only the host can change simulation speed here.")
			elif words.size() != 2 or not words[1].is_valid_int() or int(words[1]) not in [0, 1, 2, 5]:
				_dev_console_print("Usage: /speed <0|1|2|5>")
			else:
				session.call("request_time_speed", int(words[1]))
				_dev_console_print("Speed request: %sx" % words[1])
		_:
			_dev_console_print("Unknown command. Type /help.")

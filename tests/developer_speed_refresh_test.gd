extends SceneTree
## Test the control contract, not positions, labels or layout.
const TOOLS = preload("res://scripts/match_developer_tools.gd")
const HUD = preload("res://scripts/ui_theme.gd")

var changes: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session: Node = root.get_node("GameSession")
	session.set("is_solo", true)
	session.set("phase", "match")
	var controls = TOOLS.new()
	controls.session = session
	for speed in [0, 1, 2, 5]:
		var button := Button.new()
		button.toggle_mode = true
		root.add_child(button)
		controls.time_buttons[speed] = button
		button.theme_changed.connect(func() -> void: changes += 1)
	var state: Dictionary = {"time_speed": 1}
	controls.refresh_speed(state)
	await process_frame
	var initial_changes: int = changes
	for iteration in range(25):
		controls.refresh_speed(state)
	await process_frame
	assert(changes == initial_changes, "Unchanged speed must not invalidate button themes")
	assert(controls.time_buttons[1].disabled and controls.time_buttons[1].button_pressed)
	controls.dev_mode = true
	controls.refresh_speed(state)
	assert(not controls.time_buttons[1].disabled)
	# A locally toggled button (e.g. rejected authority request) must be restored.
	controls.time_buttons[5].set_pressed_no_signal(true)
	controls.refresh_speed(state)
	assert(not controls.time_buttons[5].button_pressed)
	state["time_speed"] = 5
	controls.refresh_speed(state)
	assert(not controls.time_buttons[1].button_pressed and controls.time_buttons[5].button_pressed)
	assert(not controls.time_buttons[1].has_theme_stylebox_override("disabled"))
	assert(not controls.time_buttons[1].has_theme_color_override("font_disabled_color"))
	assert(is_same(controls.time_buttons[5].get_theme_stylebox("disabled"), controls.time_buttons[5].get_theme_stylebox("pressed")))
	assert(controls.time_buttons[5].get_theme_color("font_disabled_color") == HUD.ACCENT)
	state["match_result"] = {"team": 1}
	controls.refresh_speed(state)
	for button in controls.time_buttons.values():
		assert(button.disabled)
		button.queue_free()
	print("PASS: developer speed refresh idempotence, rejected-toggle recovery, speed and eligibility transitions")
	quit()

extends SceneTree
## Rendered UI acceptance checks; save viewport images for visual inspection.
var session: Node
var failed: bool = false

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failed = true
        push_error("FAIL: " + message)

func _run() -> void:
    create_timer(30.0).timeout.connect(func() -> void: quit(1))
    root.size = Vector2i(1152, 800)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    session = root.get_node("GameSession")
    _check(bool(session.call("host_game", "Commander", 0)), "host for UI")
    for index in range(7):
        session.call("add_bot")
    session.call("start_match")
    while str(session.get("phase")) != "match":
        await process_frame
    (session.get("simulation_timer") as Timer).stop()
    await process_frame
    await process_frame
    var ui: Control = current_scene
    var field: Control = ui.get("battlefield")
    var map: Dictionary = session.get("map_data")
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.pressed = true
    mouse.position = field.call("_screen", map.nodes[0].position)
    field.call("_input_map", mouse)
    _check(int(ui.get("selected")) == 0, "left-click selection")
    _check(not (ui.get("base_button") as Button).disabled, "friendly recruitment control")
    mouse.button_index = MOUSE_BUTTON_RIGHT
    mouse.position = field.call("_screen", map.nodes[6].position)
    field.call("_input_map", mouse)
    session.call("_simulation_tick")
    _check(int((session.get("match_state") as Dictionary).players[1].rally) == 6, "right-click rally")
    var before: float = float(field.get("zoom"))
    mouse.button_index = MOUSE_BUTTON_WHEEL_UP
    mouse.position = field.size * 0.5
    field.call("_input_map", mouse)
    _check(float(field.get("zoom")) > before, "wheel zoom")
    await _camera_and_display(ui, field)
    await _entrench_controls(ui, field, map)
    field.call("fit_map")
    var sim: RefCounted = session.get("simulation")
    for id in sim.get("players"):
        var player: Dictionary = (sim.get("players") as Dictionary)[id]
        player.auto = false
        player.bot = false
        for index in range(100 - int(player.count)):
            sim.call("_spawn", id, int(player.base), 20.0)
    var index: int = 0
    for unit in (sim.get("units") as Dictionary).values():
        unit.node = 112 + index % 16
        unit.to = -1
        index += 1
    session.call("_simulation_tick")
    _check((session.get("match_state") as Dictionary).units.size() == 800, "dense battlefield")
    await _render("normal", ui, field)
    root.size = Vector2i(640, 720)
    await process_frame
    await process_frame
    field.call("fit_map")
    await _render("narrow", ui, field)
    root.size = Vector2i(1152, 800)
    await process_frame
    await process_frame
    field.set("zoom", 1.0)
    field.set("pan", field.size * 0.5)
    await _render("center", ui, field)
    session.call("leave_session")
    if not failed:
        print("PASS: UI selection, rally, camera keys/drag, editing focus, fullscreen, 800 troops, normal/narrow/center renders")
    quit(1 if failed else 0)

func _key(code: Key, pressed: bool, alt: bool = false) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = pressed
    event.alt_pressed = alt
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func _entrench_controls(ui: Control, field: Control, map: Dictionary) -> void:
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    click.position = field.call("_screen", map.nodes[1].position)
    field.call("_input_map", click)
    var edit: SpinBox = ui.get("reserve_edit")
    _check(edit.editable, "can plan entrenchment on a neutral node")
    edit.value = 3
    await create_timer(0.35).timeout
    var sim: RefCounted = session.get("simulation")
    _check(int((sim.get("players") as Dictionary)[1].reserves.get(1, -1)) == 3, "number input automatically saves")
    session.call("_simulation_tick")
    edit.value = 5
    ui.call("_select", 2)
    _check(int((sim.get("players") as Dictionary)[1].reserves.get(1, -1)) == 5, "selection change commits to previous node")
    _check(int(edit.value) == 0, "new selection loads its own value without saving")
    ui.call("_select", 1)
    _check(int(edit.value) == 5, "returning to node restores new target before snapshot acknowledgment")
    edit.get_line_edit().text = "0"
    edit.get_line_edit().text_submitted.emit("0")
    _check(int((sim.get("players") as Dictionary)[1].reserves[1]) == 0, "Enter immediately releases defenders")
    edit.get_line_edit().text = "3"
    (ui.get("reserve_button") as Button).pressed.emit()
    session.call("_simulation_tick")
    _check(int((session.get("match_state") as Dictionary).players[1].reserves[1]) == 3, "holding target reaches match snapshot")

func _camera_and_display(ui: Control, field: Control) -> void:
    root.grab_focus()
    await create_timer(0.1).timeout
    field.set_process(false)
    field.set("pointer_inside", false)
    var before: Vector2 = field.get("pan")
    _key(KEY_W, true)
    _check(field.call("_keyboard_direction") == Vector2.UP, "physical W input")
    field.call("_process", 0.1)
    var straight: Vector2 = (field.get("pan") as Vector2) - before
    _check(straight.y > 0 and is_zero_approx(straight.x), "W moves view north")
    _key(KEY_D, true)
    before = field.get("pan")
    field.call("_process", 0.1)
    var diagonal: Vector2 = (field.get("pan") as Vector2) - before
    _check(diagonal.x < 0 and diagonal.y > 0 and is_equal_approx(diagonal.length(), straight.length()), "diagonal camera speed normalized")
    _key(KEY_D, false)
    var edit: LineEdit = (ui.get("reserve_edit") as SpinBox).get_line_edit()
    edit.grab_focus()
    before = field.get("pan")
    field.call("_process", 0.1)
    _check(field.get("pan") == before, "typing doesn't move camera")
    _key(KEY_W, false)
    edit.release_focus()
    var middle := InputEventMouseButton.new()
    middle.button_index = MOUSE_BUTTON_MIDDLE
    middle.pressed = true
    Input.parse_input_event(middle)
    Input.flush_buffered_events()
    field.call("_input_map", middle)
    before = field.get("pan")
    var drag := InputEventMouseMotion.new()
    drag.relative = Vector2(17, -9)
    field.call("_input_map", drag)
    _check((field.get("pan") as Vector2).is_equal_approx(before + drag.relative), "middle drag pans")
    var release: InputEventMouseButton = middle.duplicate()
    release.pressed = false
    Input.parse_input_event(release)
    Input.flush_buffered_events()
    field.call("_input_map", release)
    _check(field.call("_edge_direction", Vector2(1, field.size.y * 0.5)) == Vector2.LEFT, "left edge pans west")
    var view_center: Vector2 = field.call("_world", field.size * 0.5)
    var saved_size: Vector2i = root.size
    _key(KEY_F11, true)
    _key(KEY_F11, false)
    await create_timer(0.15).timeout
    _check(root.mode == Window.MODE_FULLSCREEN, "F11 enters fullscreen")
    _check((field.call("_world", field.size * 0.5) as Vector2).is_equal_approx(view_center), "fullscreen preserves camera view")
    var display_button: Button
    for button in ui.find_children("*", "Button", true, false):
        if button.text == "WINDOWED (F11)":
            display_button = button
            break
    _check(display_button != null, "fullscreen button reflects current mode")
    if display_button != null:
        display_button.pressed.emit()
    await create_timer(0.15).timeout
    _check(root.mode == Window.MODE_WINDOWED and root.size == saved_size, "button restores window size")
    _key(KEY_ENTER, true, true)
    _key(KEY_ENTER, false)
    await create_timer(0.15).timeout
    _check(root.mode == Window.MODE_FULLSCREEN, "Alt+Enter enters fullscreen")
    _key(KEY_ESCAPE, true)
    _key(KEY_ESCAPE, false)
    await create_timer(0.15).timeout
    _check(root.mode == Window.MODE_WINDOWED, "Esc exits fullscreen")
    field.set_process(true)

func _render(label: String, ui: Control, field: Control) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    print("SIZE: ", label, " window=", root.size, " viewport=", root.get_visible_rect().size, " field=", field.size)
    _check(field.size.y >= 180 and field.size.x <= root.size.x, "usable battlefield at " + label)
    for key in ["metrics", "status_label", "selection_label"]:
        var control: Control = ui.get(key)
        _check(control.get_global_rect().end.x <= root.size.x + 1, "no horizontal HUD overflow: " + key)
    var directory: String = OS.get_environment("TEMP")
    if directory.is_empty():
        directory = "/tmp"
    var filename: String = directory.path_join("warbound-ui-" + label + ".png")
    var error: Error = root.get_texture().get_image().save_png(filename)
    _check(error == OK, "save screenshot")
    print("RENDER: " + filename)

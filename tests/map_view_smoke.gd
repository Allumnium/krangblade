extends SceneTree
const MAP = preload("res://scripts/planet_map.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var session: Node = root.get_node("GameSession")
    assert(bool(session.call("start_solo")))
    await process_frame
    await process_frame
    var view: Control = current_scene
    assert(view != null and view.has_method("_select_at"))
    await process_frame
    var state: Dictionary = session.get("economy")
    var points: Array = state["map"]["points"]
    var neighbor: int = -1
    for i in range(1, points.size()):
        if MAP.linked(state["map"], 0, i):
            neighbor = i
            break
    assert(neighbor >= 0)
    var screen: Vector2 = view.call("_screen_point", points[neighbor])
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.pressed = true
    mouse.position = screen
    view.call("_map_input", mouse)
    assert(int(view.get("selected")) == neighbor)
    assert(int(state["planets"][neighbor]["owner"]) == 0)
    var claim: Button = view.get("claim_button")
    assert(claim.visible and not claim.disabled)
    claim.pressed.emit()
    assert(int(state["planets"][neighbor]["owner"]) == 1)

    # Zoom retains the world coordinate at the cursor; pan changes projection.
    var world: Vector2 = view.call("_world_point", screen)
    view.call("_zoom_at", screen, 2.0)
    assert((view.call("_world_point", screen) as Vector2).is_equal_approx(world))
    assert(is_equal_approx(float(view.get("zoom")), 2.0))
    mouse.button_index = MOUSE_BUTTON_RIGHT
    view.call("_map_input", mouse)
    var motion := InputEventMouseMotion.new()
    motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
    motion.relative = Vector2(40, -25)
    var before: Vector2 = view.call("_screen_point", points[neighbor])
    view.call("_map_input", motion)
    assert((view.call("_screen_point", points[neighbor]) as Vector2).is_equal_approx(before + motion.relative))
    mouse.pressed = false
    view.call("_map_input", mouse)
    view.call("_reset_view")
    assert(is_equal_approx(float(view.get("zoom")), 1.0))
    assert((view.get("pan") as Vector2).is_zero_approx())

    session.call("request_operation", 0, "ship")
    for i in range(20):
        session.call("_economy_tick")
    assert(state["ships"].size() == 1)
    assert((view.get("ship_visuals") as Dictionary).size() == 1)
    await process_frame
    await process_frame
    print("PASS: select without capture, explicit claim, zoom anchor, pan, reset and ship rendering")
    quit(0)

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
    assert(view.theme != null)
    assert((view.get("stock_labels") as Dictionary).size() == 6)
    var resources: OptionButton = view.get("resource_picker")
    for i in range(resources.item_count):
        assert(resources.get_item_icon(i) != null)
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
    var send: Button = view.get("send_colony_button")
    assert(send.visible and send.disabled)
    session.call("request_operation", 0, "colony_ship")
    view.set("selected", 0)
    view.call("_refresh")
    var jobs: ItemList = view.get("jobs")
    assert(jobs.item_count == 1)
    jobs.select(0)
    view.call("_refresh")
    assert((view.get("job_progress") as ProgressBar).visible)
    assert((view.get("job_cost") as HBoxContainer).get_child_count() > 0)
    view.set("selected", neighbor)
    view.call("_refresh")
    for i in range(125):
        session.call("_economy_tick")
    assert(state["ships"].size() == 1)
    assert(not send.disabled)
    send.pressed.emit()
    assert(int(state["planets"][neighbor]["owner"]) == 0)
    assert(not (state["ships"][0]["route"] as Array).is_empty())
    for i in range(200):
        session.call("_economy_tick")
    assert(int(state["planets"][neighbor]["owner"]) == 1)
    assert(state["ships"].is_empty())

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
    for i in range(100):
        session.call("_economy_tick")
    assert(state["ships"].size() == 1)
    assert((view.get("ship_visuals") as Dictionary).size() == 1)
    await process_frame
    await process_frame
    print("PASS: select without capture, colony dispatch and arrival, zoom anchor, pan, reset and ship rendering")
    quit(0)

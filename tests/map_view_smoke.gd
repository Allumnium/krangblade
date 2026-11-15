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
    var header: PanelContainer = view.get("header_panel")
    var brand: Label = view.get("brand_label")
    var canvas: Control = view.get("map_canvas")
    var inspector: PanelContainer = view.get("inspector_panel")
    assert(header.size.y <= 96.0)
    assert(header.position.y + header.size.y < canvas.position.y)
    assert(header.position.y + header.size.y < inspector.position.y)
    assert(brand.autowrap_mode == TextServer.AUTOWRAP_OFF)
    assert(brand.size.x >= brand.get_combined_minimum_size().x)
    var tabs: TabContainer = view.get("inspector_tabs")
    assert(tabs.get_tab_count() == 4)
    assert(tabs.get_tab_title(0) == "Economy" and tabs.get_tab_title(1) == "Trade" and tabs.get_tab_title(2) == "Shipyards" and tabs.get_tab_title(3) == "Upgrades")
    var trade: OptionButton = view.get("trade_picker")
    assert(trade.item_count == 6)
    trade.select(3)
    view.call("_load_thresholds")
    assert(view.call("_trade_resource") == "Organics")
    assert(view.call("_resource") == "Metals")
    assert((view.get("year_label") as Label).text.begins_with("YEAR"))
    assert((view.get("population_label") as Label).text.contains("Population"))
    assert((view.get("stock_labels") as Dictionary).size() == 6)
    var resources: OptionButton = view.get("resource_picker")
    for i in range(resources.item_count):
        assert(resources.get_item_icon(i) != null)
    var state: Dictionary = session.get("economy")
    assert((view.get("global_resource_labels") as Dictionary).size() == 6)
    assert((view.get("global_population_label") as Label).text.begins_with("POP"))
    assert((view.get("global_planet_label") as Label).text == "WORLDS  1")
    var cards: Dictionary = view.get("upgrade_cards")
    assert(cards.size() == 6)
    var farm: Dictionary = cards["Organics"]
    var farm_button: Button = farm["button"]
    assert(tabs.get_tab_control(3).is_ancestor_of(farm_button))
    assert(not farm_button.disabled)
    assert((cards["Tech"]["button"] as Button).disabled)
    tabs.current_tab = 3
    farm_button.pressed.emit()
    assert(state["planets"][0]["queue"].size() == 1)
    assert((farm["progress"] as ProgressBar).visible)
    assert(farm_button.text.contains("CANCEL"))
    farm_button.pressed.emit()
    assert(state["planets"][0]["queue"].is_empty())
    tabs.current_tab = 0
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
    tabs.current_tab = 2
    assert(tabs.get_tab_control(2).is_ancestor_of(jobs))
    assert(tabs.get_tab_control(1).is_ancestor_of(trade))
    jobs.select(0)
    view.call("_refresh")
    assert((view.get("job_progress") as ProgressBar).visible)
    assert((view.get("job_cost") as HBoxContainer).get_child_count() > 0)
    tabs.current_tab = 0
    view.set("selected", neighbor)
    view.call("_refresh")
    for i in range(125):
        session.call("_economy_tick")
    assert(state["ships"].size() == 1)
    assert((view.get("year_label") as Label).text == "YEAR  %d" % (1 + floori(float(state["elapsed"]) + 0.00001)))
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
    view.call("_pan_camera", Vector2(1, 1), 0.5)
    var keyboard_pan: Vector2 = view.get("pan")
    assert(keyboard_pan.x < 0.0 and keyboard_pan.y < 0.0)
    assert(is_equal_approx(keyboard_pan.length(), 210.0))
    view.call("_reset_view")
    var prior_width: float = canvas.size.x
    var fixed_point: Vector2 = view.call("_screen_point", points[0])
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.pressed = true
    mouse.position = Vector2(-100, -100)
    view.call("_map_input", mouse)
    assert(int(view.get("selected")) == -1 and not inspector.visible)
    session.call("_economy_tick")
    session.call("_economy_tick")
    assert(int(view.get("selected")) == -1 and not inspector.visible)
    await process_frame
    assert(canvas.size.x > prior_width)
    assert((view.call("_screen_point", points[0]) as Vector2).is_equal_approx(fixed_point))
    mouse.position = view.call("_screen_point", points[0])
    view.call("_map_input", mouse)
    assert(int(view.get("selected")) == 0 and inspector.visible)
    assert((view.call("_screen_point", points[0]) as Vector2).is_equal_approx(fixed_point))
    assert((view.get("global_planet_label") as Label).text == "WORLDS  2")

    session.call("request_operation", 0, "ship")
    for i in range(100):
        session.call("_economy_tick")
    assert(state["ships"].size() == 1)
    assert((view.get("ship_visuals") as Dictionary).size() == 1)
    assert((view.get("global_craft_label") as Label).text == "CRAFT  1")
    var mineral_button: Button = view.get("miner_button")
    assert(not mineral_button.disabled)
    assert((view.get("environment_label") as Label).text.contains("Advanced manufacturing"))
    assert(view.call("_planet_color", state["planets"][0]) is Color)
    var orbit_start: Vector2 = view.call("_orbit_offset", 0, 17.0, 0.0)
    var orbit_next: Vector2 = view.call("_orbit_offset", 0, 17.0, 1.0)
    assert(not orbit_start.is_equal_approx(orbit_next))
    assert(is_equal_approx(orbit_start.length(), orbit_next.length()))
    var fighter_button: Button = view.get("fighter_button")
    fighter_button.pressed.emit()
    for i in range(70):
        session.call("_economy_tick")
    assert(state["ships"].size() == 2)
    assert(state["ships"][1]["kind"] == "fighter")
    assert((view.get("global_craft_label") as Label).text == "CRAFT  2")
    await process_frame
    await process_frame
    print("PASS: select without capture, colony dispatch and arrival, zoom anchor, pan, reset and ship rendering")
    quit(0)

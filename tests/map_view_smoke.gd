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
    var canvas: Control = view.get("map_canvas")
    var inspector: PanelContainer = view.get("inspector_panel")
    var overview: PanelContainer = view.get("overview_panel")
    assert(overview.visible and inspector.visible)
    assert(overview.is_ancestor_of(view.get("population_label")))
    assert(inspector.is_ancestor_of(view.get("inspector_tabs")))
    assert(not overview.is_ancestor_of(view.get("inspector_tabs")))
    assert(header.size.y <= 52.0)
    assert(header.get_child_count() == 1 and header.get_child(0) is HBoxContainer)
    for child in header.get_child(0).get_children():
        if child is Button:
            assert(child.text == "MENU")
    var menu: AcceptDialog = view.get("match_menu")
    var menu_button: Button = view.get("leave")
    menu_button.pressed.emit()
    assert(menu.visible and session.get("phase") == "match")
    menu.get_ok_button().pressed.emit()
    assert(not menu.visible and session.get("phase") == "match")
    for tile in view.get("global_resource_tiles").values():
        assert(tile.get_parent() == header.get_child(0))
    var idle_rows: Dictionary = view.get("yard_activity_rows")
    assert(idle_rows.size() == 1)
    assert((idle_rows[0]["row"] as Control).is_visible_in_tree())
    assert((idle_rows[0]["label"] as Label).text.contains("Idle"))
    var yard_upgrade: Button = idle_rows[0]["upgrade"]
    assert(yard_upgrade.visible and not yard_upgrade.disabled)
    yard_upgrade.pressed.emit()
    var setup_state: Dictionary = session.get("economy")
    var queued: Dictionary = setup_state["planets"][0]["queue"][0]
    assert(queued["kind"] == "yard_upgrade" and queued["target"] == "0")
    assert(yard_upgrade.disabled)
    var queue_rows: Dictionary = view.get("queue_rows")
    var cancel_upgrade: Button = queue_rows[int(queued["id"])]["cancel"]
    assert(not cancel_upgrade.disabled)
    cancel_upgrade.pressed.emit()
    assert(setup_state["planets"][0]["queue"].is_empty())
    assert(not yard_upgrade.disabled)
    assert((view.get("info") as Label).text.begins_with("System"))
    assert(header.position.y + header.size.y < canvas.position.y)
    assert(header.position.y + header.size.y < inspector.position.y)
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
    assert(view.get("global_resource_labels")["Metals"].text.contains("("))
    assert((view.get("global_population_label") as Label).text.begins_with("POP  10."))
    var cards: Dictionary = view.get("upgrade_cards")
    assert(cards.size() == 6)
    var farm: Dictionary = cards["Organics"]
    var farm_button: Button = farm["button"]
    assert(tabs.get_tab_control(3).is_ancestor_of(farm_button))
    assert(not farm_button.disabled)
    assert((cards["Tech"]["button"] as Button).disabled)
    tabs.current_tab = 3
    var upgrade_audio: AudioStreamPlayer = view.get("upgrade_audio")
    assert(upgrade_audio.stream.resource_path == "res://assets/sfx/detail.wav")
    assert(not upgrade_audio.playing)
    farm_button.pressed.emit()
    assert(upgrade_audio.playing)
    upgrade_audio.stop()
    view.call("_on_economy_changed")
    assert(not upgrade_audio.playing)
    session.call("request_operation", 0, "production", "Organics")
    assert(not upgrade_audio.playing)
    assert(state["planets"][0]["queue"].size() == 1)
    assert((farm["progress"] as ProgressBar).visible)
    assert(farm_button.text.contains("CANCEL"))
    farm_button.pressed.emit()
    assert(state["planets"][0]["queue"].is_empty())
    assert(not upgrade_audio.playing)
    tabs.current_tab = 2
    var checks: Dictionary = view.get("continuous_checks")
    assert(checks.size() == 4)
    var automatic: CheckBox = checks["fighter"]
    automatic.button_pressed = true
    assert(state["planets"][0]["continuous"]["fighter"])
    automatic.button_pressed = false
    assert(not state["planets"][0]["continuous"]["fighter"])
    var new_yard: Button = view.get("yard_button")
    new_yard.pressed.emit()
    var yard_job: Dictionary = state["planets"][0]["queue"][0]
    var pending_key: int = -int(yard_job["id"])
    assert(idle_rows.size() == 2 and idle_rows.has(pending_key))
    session.call("_economy_tick")
    session.call("_economy_tick")
    assert((idle_rows[pending_key]["progress"] as ProgressBar).value > 0.0)
    (queue_rows[int(yard_job["id"])]["cancel"] as Button).pressed.emit()
    assert(idle_rows.size() == 1)
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
    assert(queue_rows.size() == 1)
    var colony_job_id: int = int(state["planets"][0]["queue"][0]["id"])
    assert(not (queue_rows[colony_job_id]["cancel"] as Button).disabled)
    for i in range(10):
        session.call("_economy_tick")
    var active: Dictionary = view.get("yard_activity_rows")
    assert(active.size() == 1)
    assert((active[0]["progress"] as ProgressBar).value > 0.0)
    tabs.current_tab = 2
    assert(tabs.get_tab_control(2).is_ancestor_of(view.get("queue_list")))
    assert(tabs.get_tab_control(1).is_ancestor_of(trade))
    assert((queue_rows[colony_job_id]["progress"] as ProgressBar).value > 0.0)
    assert((queue_rows[colony_job_id]["cost"] as Label).text.contains("Metals"))
    # Cancel an active hull through its own row, then rebuild it.
    (queue_rows[colony_job_id]["cancel"] as Button).pressed.emit()
    assert(state["planets"][0]["queue"].is_empty())
    session.call("request_operation", 0, "colony_ship")
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
    for i in range(1020):
        session.call("_economy_tick")
        if int(state["planets"][neighbor]["owner"]) == 1:
            break
    assert(int(state["planets"][neighbor]["owner"]) == 1)
    assert(state["ships"].is_empty())

    # Zoom retains the world coordinate at the cursor; pan changes projection.
    var world: Vector2 = view.call("_world_point", screen)
    view.call("_zoom_at", screen, 2.0)
    assert((view.call("_world_point", screen) as Vector2).is_equal_approx(world))
    assert(is_equal_approx(float(view.get("zoom")), 2.0))
    view.call("_zoom_at", screen, 100.0)
    assert(is_equal_approx(float(view.get("zoom")), 16.0))
    assert((view.call("_world_point", screen) as Vector2).is_equal_approx(world))
    view.call("_zoom_at", screen, 0.125)
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
    assert(is_equal_approx(canvas.size.x, prior_width))
    assert(not overview.visible)
    assert((view.call("_screen_point", points[0]) as Vector2).is_equal_approx(fixed_point))
    mouse.position = view.call("_screen_point", points[0])
    view.call("_map_input", mouse)
    assert(int(view.get("selected")) == 0 and inspector.visible and overview.visible)
    assert((view.call("_screen_point", points[0]) as Vector2).is_equal_approx(fixed_point))

    session.call("request_operation", 0, "ship")
    for i in range(100):
        session.call("_economy_tick")
    assert(state["ships"].size() == 1)
    assert((view.get("ship_visuals") as Dictionary).size() == 1)
    assert((idle_rows[0]["label"] as Label).text.contains("Idle"))
    assert((idle_rows[0]["progress"] as ProgressBar).value == 0.0)
    var mineral_button: Button = view.get("miner_button")
    assert(not mineral_button.disabled)
    assert((view.get("environment_label") as Label).text.contains("Manufacturing"))
    assert(view.call("_planet_color", state["planets"][0]) is Color)
    var layout: Dictionary = view.call("_system_visual", 0, state)
    var bodies: Array = layout["bodies"]
    assert(bodies.size() >= 2 and bodies.size() <= 6)
    var body_start: Vector2 = view.call("_body_position", bodies[0], 60.0, 0.0)
    var body_next: Vector2 = view.call("_body_position", bodies[0], 60.0, 1.0)
    assert(not body_start.is_equal_approx(body_next))
    assert(is_equal_approx(body_start.length(), body_next.length()))
    assert(view.call("_system_visual", 0, state) == layout)
    var orbit_start: Vector2 = view.call("_orbit_offset", 0, 17.0, 0.0)
    var orbit_next: Vector2 = view.call("_orbit_offset", 0, 17.0, 1.0)
    assert(not orbit_start.is_equal_approx(orbit_next))
    assert(is_equal_approx(orbit_start.length(), orbit_next.length()))
    var orbit_heading: Vector2 = view.call("_orbit_direction", orbit_start)
    assert(orbit_heading.dot(orbit_next - orbit_start) > 0.0)
    var fighter_button: Button = view.get("fighter_button")
    fighter_button.pressed.emit()
    for i in range(70):
        session.call("_economy_tick")
    assert(state["ships"].size() == 2)
    assert(state["ships"][1]["kind"] == "fighter")
    view.call("_zoom_at", view.call("_screen_point", points[0]), 4.0)
    var fighter_id: int = int(state["ships"][1]["id"])
    var ship_poses: Dictionary = view.call("_ship_poses", state)
    mouse.position = ship_poses[fighter_id]["point"]
    view.call("_map_input", mouse)
    assert(int(view.get("selected_ship_id")) == fighter_id)
    assert(int(view.get("selected")) == -1)
    assert((view.get("ship_overview") as VBoxContainer).visible)
    assert(not tabs.visible)
    assert((view.get("fleet_title") as Label).text == "Military")
    assert(not (view.get("fleet_detail") as Label).visible)
    var logistics_id: int = int(state["ships"][0]["id"])
    ship_poses = view.call("_ship_poses", state)
    mouse.position = ship_poses[logistics_id]["point"]
    view.call("_map_input", mouse)
    assert(int(view.get("selected_ship_id")) == logistics_id)
    assert((view.get("fleet_title") as Label).text == "Logistics")
    assert((view.get("fleet_detail") as Label).text.contains("1 ships"))
    assert((view.get("ship_title") as Label).text.contains("Logistics ship"))
    assert((view.get("ship_cargo") as VBoxContainer).get_parent().visible)
    var fixed: Vector2 = view.call("_screen_point", points[0])
    mouse.position = Vector2(-10000, -10000)
    view.call("_map_input", mouse)
    assert(int(view.get("selected_ship_id")) == -1)
    assert(not inspector.visible and not overview.visible)
    assert((view.call("_screen_point", points[0]) as Vector2).is_equal_approx(fixed))
    mouse.position = view.call("_screen_point", points[0])
    view.call("_map_input", mouse)
    assert(int(view.get("selected")) == 0 and tabs.visible)
    var explored: Dictionary = state["explored"][1]
    var unknown: int = -1
    for i in range(points.size()):
        if not explored["planets"].has(i):
            unknown = i
            break
    assert(unknown >= 0)
    mouse.position = view.call("_screen_point", points[unknown])
    view.call("_map_input", mouse)
    assert(int(view.get("selected")) == -1)
    # Select a discovered field and change its actual simulation policy.
    if not (state["map"]["fields"] as Array).is_empty():
        explored["fields"][0] = true
        mouse.position = view.call("_screen_point", state["map"]["fields"][0]["position"])
        view.call("_map_input", mouse)
        assert(int(view.get("selected_field")) == 0)
        var metals: CheckBox = view.get("mining_metals")
        assert(metals.button_pressed)
        metals.button_pressed = false
        assert(not state["mining_policies"][1][0]["Metals"])
        mouse.position = Vector2(-10000, -10000)
        view.call("_map_input", mouse)
    # A consumed/disappearing ship clears its selection, rather than leaving stale details.
    view.set("selected", -1)
    view.set("selected_ship_id", logistics_id)
    state["ships"].remove_at(0)
    view.call("_refresh")
    assert(int(view.get("selected_ship_id")) == -1 and not inspector.visible)
    await process_frame
    await process_frame
    print("PASS: select without capture, colony dispatch and arrival, zoom anchor, pan, reset and ship rendering")
    quit(0)

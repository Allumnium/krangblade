extends SceneTree
const BUILD_RULES = preload("res://scripts/economy_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var session: Node = root.get_node("GameSession")
    if not (bool(session.call("start_solo"))):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    await process_frame
    await process_frame
    var view: Control = current_scene
    if not (view != null and view.has_method("_select_at")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    await process_frame
    if not (view.theme != null):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var opening_state: Dictionary = session.get("economy")
    if not (opening_state["ships"].size() == 5):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.call("_ship_poses", opening_state) as Dictionary).size() == 5):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    # Isolate the subsequent construction/selection UI scenarios from autonomous starter ships.
    opening_state["ships"].clear()
    view.call("_sync_ship_visuals", opening_state)
    var territory_layer: Control = view.get("territory_layer")
    var territory_image: ColorRect = view.get("territory_image")
    if not (territory_image.visible and territory_image.material is ShaderMaterial):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var territory_sites: ImageTexture = view.get("territory_sites")
    var site_data: Image = territory_sites.get_image()
    if not (site_data.get_height() == 1 and site_data.get_width() == int(view.get("territory_site_count"))):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var home_site: Color = site_data.get_pixel(0, 0)
    if not (is_equal_approx(home_site.b, 1.0) and is_equal_approx(home_site.a, 1.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (float(view.get("territory_radius")) > 0.0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var cached_sites: ImageTexture = view.get("territory_sites")
    view.call("_refresh_territory", session.get("economy"))
    if not (view.get("territory_sites") == cached_sites):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (territory_image.mouse_filter == Control.MOUSE_FILTER_IGNORE):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (territory_layer.get_index() < (view.get("map_canvas") as Control).get_index()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("territory_last") as Array)[0] == 1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (view.call("_show_system_rings", 0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not view.call("_show_system_rings", 1)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (territory_image.position.is_equal_approx(view.call("_screen_point", -Vector2.ONE * float(view.get("territory_radius")) * 1.5))):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var header: PanelContainer = view.get("header_panel")
    var canvas: Control = view.get("map_canvas")
    var inspector: PanelContainer = view.get("inspector_panel")
    var overview: PanelContainer = view.get("overview_panel")
    if not (overview.visible and inspector.visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (overview.is_ancestor_of(view.get("population_label"))):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (inspector.is_ancestor_of(view.get("inspector_tabs"))):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not overview.is_ancestor_of(view.get("inspector_tabs"))):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (header.size.y <= 60.0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (header.get_child_count() == 1 and header.get_child(0) is HBoxContainer):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    for child in header.get_child(0).get_children():
        if child is Button:
            if not (child.text == "MENU"):
                push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
                quit(1)
                return
    var menu: AcceptDialog = view.get("match_menu")
    var menu_button: Button = view.get("leave")
    menu_button.pressed.emit()
    if not (menu.visible and session.get("phase") == "match"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    menu.get_ok_button().pressed.emit()
    if not (not menu.visible and session.get("phase") == "match"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    for tile in view.get("global_resource_tiles").values():
        if not (tile.get_parent() == header.get_child(0)):
            push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
            quit(1)
            return
    var idle_rows: Dictionary = view.get("yard_activity_rows")
    if not (idle_rows.size() == 3):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((idle_rows[0]["row"] as Control).is_visible_in_tree()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((idle_rows[0]["label"] as Label).text.contains("Idle")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not (idle_rows[0]["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (idle_rows[0]["header"] as Button).pressed.emit()
    if not ((idle_rows[0]["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var yard_upgrade: Button = idle_rows[0]["upgrade"]
    if not (yard_upgrade.visible and not yard_upgrade.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    yard_upgrade.pressed.emit()
    var setup_state: Dictionary = session.get("economy")
    var queued: Dictionary = setup_state["planets"][0]["queue"][0]
    if not (queued["kind"] == "yard_upgrade" and queued["target"] == "0"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (yard_upgrade.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (idle_rows[0]["cancel"] as Button).pressed.emit()
    if not (setup_state["planets"][0]["queue"].is_empty()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not yard_upgrade.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var yard_repeat: Button = idle_rows[0]["repeat"]
    if not (yard_repeat.icon != null and yard_repeat.text.is_empty()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    yard_repeat.button_pressed = true
    if not (setup_state["planets"][0]["continuous"]["yard_upgrade:0"]):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    yard_repeat.button_pressed = false
    if not (not setup_state["planets"][0]["continuous"]["yard_upgrade:0"]):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("info") as Label).text.begins_with(str(setup_state["map"]["names"][0]))):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (header.position.y + header.size.y < canvas.position.y):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var military_toggle: Button = view.get("military_lens")
    var logistics_toggle: Button = view.get("logistics_lens")
    if not (not military_toggle.button_pressed and not logistics_toggle.button_pressed):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (military_toggle.global_position.y >= header.global_position.y + header.size.y):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    military_toggle.pressed.emit()
    if not (military_toggle.button_pressed and not logistics_toggle.button_pressed):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    logistics_toggle.pressed.emit()
    if not (not military_toggle.button_pressed and logistics_toggle.button_pressed):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    logistics_toggle.pressed.emit()
    if not (not logistics_toggle.button_pressed and view.get("active_lens") == ""):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var fill_state: Dictionary = session.get("economy")
    var fill_home: Dictionary = fill_state["planets"][0]
    var prefill: float = float(fill_home["stock"]["Metals"])
    fill_home["stock"]["Metals"] = 500.0
    view.call("_refresh_global_bar", fill_state)
    if not (is_equal_approx(float(view.get("global_resource_fills")["Metals"]), 0.25)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    fill_home["stock"]["Metals"] = 2000.0
    view.call("_refresh_global_bar", fill_state)
    if not (is_equal_approx(float(view.get("global_resource_fills")["Metals"]), 1.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    view.call("_refresh_global_bar", {})
    if not (is_zero_approx(float(view.get("global_resource_fills")["Metals"]))):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    fill_home["stock"]["Metals"] = prefill
    view.call("_refresh_global_bar", fill_state)
    if not (header.position.y + header.size.y < inspector.position.y):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var tabs: TabContainer = view.get("inspector_tabs")
    if not (tabs.get_tab_count() == 4):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (tabs.get_tab_title(0) == "Shipyards" and tabs.get_tab_title(1) == "Economy" and tabs.get_tab_title(2) == "Trade" and tabs.get_tab_title(3) == "Upgrades"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (tabs.current_tab == 0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var trade_sliders: Dictionary = view.get("trade_sliders")
    if not (trade_sliders.size() == 6):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    for resource in ["Metals", "Plastics", "Textiles", "Organics", "Tech", "Crystals"]:
        if not (trade_sliders.has(resource)):
            push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
            quit(1)
            return
        if not (tabs.get_tab_control(2).is_ancestor_of(trade_sliders[resource])):
            push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
            quit(1)
            return
    view.call("_load_thresholds")
    tabs.current_tab = 2
    await process_frame
    var trade_amounts: Dictionary = view.get("trade_stock_labels")
    for resource in trade_amounts:
        var amount_label: Label = trade_amounts[resource]
        if not (amount_label.autowrap_mode == TextServer.AUTOWRAP_OFF):
            push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
            quit(1)
            return
        if not (amount_label.get_line_count() == 1):
            push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
            quit(1)
            return
        if not (amount_label.size.x >= amount_label.get_minimum_size().x):
            push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
            quit(1)
            return
        if not ((amount_label.get_parent() as Control).size.y < 36.0):
            push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
            quit(1)
            return
    var slider: Control = trade_sliders["Organics"]
    var metal_slider: Control = trade_sliders["Metals"]
    var stock_state: Dictionary = session.get("economy")
    var stock_system: Dictionary = stock_state["planets"][0]
    var saved_stock: float = float(stock_system["stock"]["Organics"])
    stock_system["stock"]["Organics"] = 450.0
    view.call("_refresh")
    if not (is_equal_approx(float(slider.get("stock_percent")), 22.5)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var left_resources: Dictionary = view.get("production_values")
    if not (overview.is_ancestor_of(left_resources["Organics"]["stock"])):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((left_resources["Organics"]["stock"] as Label).text == "450.0 t"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    stock_system["stock"]["Organics"] = 1500.0
    view.call("_refresh")
    if not (is_equal_approx(float(slider.get("stock_percent")), 75.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((left_resources["Organics"]["stock"] as Label).text == "1.5 kt"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((trade_amounts["Organics"] as Label).text == "1.5 kt / 2.0 kt"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    stock_system["stock"]["Organics"] = saved_stock
    view.call("_refresh")
    if not (is_equal_approx(float(slider.get("lower")), 10.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (is_equal_approx(float(slider.get("upper")), 20.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var threshold_mouse := InputEventMouseButton.new()
    threshold_mouse.button_index = MOUSE_BUTTON_LEFT
    threshold_mouse.pressed = true
    threshold_mouse.position = Vector2(float(slider.call("_x", 20.0)), 14)
    slider.call("_gui_input", threshold_mouse)
    var drag := InputEventMouseMotion.new()
    drag.position = Vector2(float(slider.call("_x", 65.0)), 14)
    slider.call("_gui_input", drag)
    view.call("_refresh")
    if not (is_equal_approx(float(slider.get("upper")), 65.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    threshold_mouse.pressed = false
    threshold_mouse.position = drag.position
    slider.call("_gui_input", threshold_mouse)
    var threshold_state: Dictionary = session.get("economy")
    if not (is_equal_approx(float(threshold_state["planets"][0]["thresholds"]["Organics"]["max"]), 65.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    threshold_mouse.pressed = true
    threshold_mouse.position = Vector2(float(slider.call("_x", 10.0)), 14)
    slider.call("_gui_input", threshold_mouse)
    threshold_mouse.pressed = false
    threshold_mouse.position = Vector2(float(slider.call("_x", 80.0)), 14)
    slider.call("_gui_input", threshold_mouse)
    if not (is_equal_approx(float(slider.get("lower")), 80.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (is_equal_approx(float(threshold_state["planets"][0]["thresholds"]["Organics"]["min"]), 80.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (is_equal_approx(float(metal_slider.get("lower")), 10.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (is_equal_approx(float(metal_slider.get("upper")), 20.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (is_equal_approx(float(threshold_state["planets"][0]["thresholds"]["Metals"]["max"]), 20.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    view.call("_load_thresholds")
    if not (is_equal_approx(float(slider.get("lower")), 80.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (is_equal_approx(float(slider.get("upper")), 80.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    tabs.current_tab = 0
    if not ((view.get("year_label") as Label).text.begins_with("YEAR")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("population_label") as Label).get_parent().get_child(0).texture == view.get("population_icon")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("population_label") as Label).autowrap_mode == TextServer.AUTOWRAP_OFF):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (view.call("_tons", 1500000.0) == "1.5 Mt"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var resource_text: String = view.call("_resource_breakdown", opening_state, "Metals")
    if not (resource_text.contains("in transit") and resource_text.contains("Current local flows") and resource_text.contains(view.call("_system_name", 0))):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var before_hover: String = resource_text
    opening_state["planets"][0]["stock"]["Metals"] += 1.0
    if not (view.call("_resource_breakdown", opening_state, "Metals") != before_hover):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    opening_state["planets"][0]["stock"]["Metals"] -= 1.0
    if not (not (view.get("population_label") as Label).text.contains(" / ")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not (view.get("population_label") as Label).tooltip_text.contains("supported")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not (view.get("population_label") as Label).text.contains("/yr")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (tabs.get_tab_control(1).is_ancestor_of(view.get("warehouse_card")["button"])):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var state: Dictionary = session.get("economy")
    if not ((view.get("global_resource_labels") as Dictionary).size() == 6):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (view.get("global_resource_labels")["Metals"].text.contains("(")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("global_population_label") as Label).text.begins_with("10.")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("global_population_label") as Label).get_parent().get_child(0).texture == view.get("population_icon")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    tabs.current_tab = 1
    var building_cards: Dictionary = view.get("economy_cards")
    if not (building_cards.size() == 6):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not (building_cards["Textiles"]["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (building_cards["Textiles"]["header"] as Button).pressed.emit()
    if not ((building_cards["Textiles"]["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (building_cards["Metals"]["header"] as Button).pressed.emit()
    if not (not (building_cards["Textiles"]["body"] as Control).visible and (building_cards["Metals"]["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    tabs.current_tab = 0
    tabs.current_tab = 1
    if not (not (building_cards["Metals"]["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (building_cards["Textiles"]["header"] as Button).pressed.emit()
    if not (not (building_cards["Textiles"]["detail"] as Label).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((building_cards["Textiles"]["costs"] as GridContainer).get_child_count() == 3):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var textile_mill: Button = building_cards["Textiles"]["button"]
    if not (tabs.get_tab_control(1).is_ancestor_of(textile_mill)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not textile_mill.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (textile_mill.tooltip_text.contains("300 t Metals")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((building_cards["Tech"]["button"] as Button).disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var warehouse_button: Button = view.get("warehouse_card")["button"]
    if not (not warehouse_button.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (warehouse_button.tooltip_text.contains("500 t Metals")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    warehouse_button.pressed.emit()
    if not (warehouse_button.tooltip_text.contains("1500 t Metals")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (int(state["planets"][0]["warehouse_level"]) == 1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (warehouse_button.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    textile_mill.pressed.emit()
    if not (int(state["planets"][0]["buildings"].get("Textiles", 0)) == 0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (textile_mill.disabled and textile_mill.text == "Build"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((building_cards["Textiles"]["progress"] as ProgressBar).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((building_cards["Textiles"]["cancel"] as Button).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (building_cards["Textiles"]["cancel"] as Button).pressed.emit()
    if not (not (building_cards["Textiles"]["progress"] as ProgressBar).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not textile_mill.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not (view.get("warehouse_card")["cancel"] as Button).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    tabs.current_tab = 3
    if not (not (building_cards["Textiles"]["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var cards: Dictionary = view.get("upgrade_cards")
    if not (cards.size() == 6):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var defense_card: Dictionary = view.get("pds_card")
    if not (not (defense_card["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (defense_card["header"] as Button).pressed.emit()
    if not ((defense_card["costs"] as GridContainer).get_child_count() == 5):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (defense_card["button"] as Button).pressed.emit()
    if not ((defense_card["progress"] as ProgressBar).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (defense_card["cancel"] as Button).pressed.emit()
    if not (not (defense_card["progress"] as ProgressBar).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var farm: Dictionary = cards["Organics"]
    if not (not (farm["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (farm["header"] as Button).pressed.emit()
    if not (not (defense_card["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    view.call("_refresh")
    if not ((farm["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not (farm["detail"] as Label).text.contains("Requires")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((cards["Tech"]["detail"] as Label).text.contains("Requires")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((farm["costs"] as GridContainer).get_child_count() == 1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var farm_button: Button = farm["button"]
    if not (tabs.get_tab_control(3).is_ancestor_of(farm_button)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not farm_button.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var farm_repeat: Button = farm["repeat"]
    if not (farm_repeat.icon != null and not farm_repeat.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    farm_repeat.button_pressed = true
    if not (state["planets"][0]["continuous"]["production:Organics"]):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    farm_repeat.button_pressed = false
    if not (not state["planets"][0]["continuous"]["production:Organics"]):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not (cards["Tech"]["repeat"] as Button).disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((cards["Tech"]["button"] as Button).disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    tabs.current_tab = 3
    var upgrade_audio: AudioStreamPlayer = view.get("upgrade_audio")
    if not (upgrade_audio.stream.resource_path == "res://assets/sfx/detail.wav"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not upgrade_audio.playing):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    farm_button.pressed.emit()
    if not (upgrade_audio.playing):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    upgrade_audio.stop()
    view.call("_on_economy_changed")
    if not (not upgrade_audio.playing):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    session.call("request_operation", 0, "production", "Organics")
    if not (not upgrade_audio.playing):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (state["planets"][0]["queue"].size() == 1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((farm["progress"] as ProgressBar).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (farm_button.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (farm["cancel"] as Button).pressed.emit()
    if not (state["planets"][0]["queue"].is_empty()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not upgrade_audio.playing):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    tabs.current_tab = 0
    var checks: Dictionary = view.get("continuous_checks")
    if not (checks.size() == 4):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var automatic: Button = checks["fighter"]
    if not (automatic.icon != null and automatic.text.is_empty() and automatic.toggle_mode):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    automatic.button_pressed = true
    if not (state["planets"][0]["continuous"]["fighter"]):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    automatic.button_pressed = false
    if not (not state["planets"][0]["continuous"]["fighter"]):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var new_yard: Button = idle_rows[102]["build"]
    if not (overview.is_ancestor_of(new_yard) and not tabs.is_ancestor_of(new_yard)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (new_yard.text == "Build" and new_yard.visible and not new_yard.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (new_yard.tooltip_text.contains("2000 t Metals")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((idle_rows[102]["costs"] as GridContainer).get_child_count() == 6):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not (idle_rows[103]["build"] as Button).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    state["planets"][0]["stock"]["Crystals"] = 100.0
    new_yard.pressed.emit()
    var third_build: Button = idle_rows[103]["build"]
    if not (third_build.visible and third_build.tooltip_text.contains("6000 t Metals")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    third_build.pressed.emit()
    if not (idle_rows.size() == 3 and not idle_rows.has(102) and not idle_rows.has(103)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var second_job: Dictionary = state["planets"][0]["queue"][0]
    var third_job: Dictionary = state["planets"][0]["queue"][1]
    var second_key: int = -int(second_job["id"])
    var third_key: int = -int(third_job["id"])
    session.call("_economy_tick")
    session.call("_economy_tick")
    if not ((idle_rows[second_key]["progress"] as ProgressBar).value > 0.0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((idle_rows[third_key]["progress"] as ProgressBar).value > 0.0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var third_progress: float = (idle_rows[third_key]["progress"] as ProgressBar).value
    (idle_rows[second_key]["cancel"] as Button).pressed.emit()
    if not (not idle_rows.has(second_key)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (idle_rows.has(third_key) and idle_rows.has(103)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((idle_rows[third_key]["label"] as Label).text.begins_with("Shipyard 2")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (is_equal_approx((idle_rows[third_key]["progress"] as ProgressBar).value, third_progress)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (idle_rows[third_key]["cancel"] as Button).pressed.emit()
    if not (idle_rows.size() == 3 and (idle_rows[102]["build"] as Button).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not (idle_rows[103]["build"] as Button).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    tabs.current_tab = 0
    var points: Array = state["map"]["points"]
    var neighbor: int = -1
    for i in range(1, points.size()):
        if MAP.linked(state["map"], 0, i):
            neighbor = i
            break
    if not (neighbor >= 0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var screen: Vector2 = view.call("_screen_point", points[neighbor])
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.pressed = true
    mouse.position = screen
    view.call("_map_input", mouse)
    if not (int(view.get("selected")) == neighbor):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (int(state["planets"][neighbor]["owner"]) == 0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var send: Button = view.get("send_colony_button")
    if not (send.visible and send.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not tabs.visible and inspector.is_ancestor_of(send)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not overview.is_ancestor_of(send)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    session.call("request_operation", 0, "colony_ship")
    view.set("selected", 0)
    view.call("_refresh")
    if not (tabs.current_tab == 0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var build: Dictionary = view.get("build_cards")
    var colony_card: Dictionary = build["colony_ship"]
    if not (not (colony_card["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (colony_card["header"] as Button).pressed.emit()
    if not ((colony_card["costs"] as GridContainer).get_child_count() == 6):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((colony_card["body"] as Control).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((colony_card["header"] as Button).text.ends_with("(1)")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((colony_card["button"] as Button).get_parent() == (colony_card["header"] as Button).get_parent()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    (colony_card["header"] as Button).pressed.emit()
    if not (not (colony_card["body"] as Control).visible and (colony_card["button"] as Button).is_visible_in_tree()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not (colony_card["cancel"] as Button).disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    for i in range(10):
        session.call("_economy_tick")
    var active: Dictionary = view.get("yard_activity_rows")
    if not (active.size() == 3):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((active[0]["progress"] as ProgressBar).value > 0.0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    tabs.current_tab = 0
    if not (tabs.get_tab_control(0).is_ancestor_of(colony_card["button"])):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (tabs.get_tab_control(2).is_ancestor_of(metal_slider)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    # Cancel an active hull through its build card, then rebuild it.
    (colony_card["cancel"] as Button).pressed.emit()
    if not (state["planets"][0]["queue"].is_empty()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    session.call("request_operation", 0, "colony_ship")
    tabs.current_tab = 0
    view.set("selected", neighbor)
    view.call("_refresh")
    for resource in BUILD_RULES._cost("colony_ship", 1):
        state["planets"][0]["stock"][resource] = maxf(float(state["planets"][0]["stock"][resource]), float(BUILD_RULES._cost("colony_ship", 1)[resource]) * 1.5)
    for i in range(ceili(BUILD_RULES._work("colony_ship", 1) / BUILD_RULES.yard_speed(1) / 0.1) + 1):
        session.call("_economy_tick")
    if not (state["ships"].size() == 1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("year_label") as Label).text == "YEAR  %d" % (1 + floori(float(state["elapsed"]) + 0.00001))):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not send.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    send.pressed.emit()
    if not (int(state["planets"][neighbor]["owner"]) == 0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not (state["ships"][0]["route"] as Array).is_empty()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    for i in range(1020):
        session.call("_economy_tick")
        if int(state["planets"][neighbor]["owner"]) == 1:
            break
    if not (int(state["planets"][neighbor]["owner"]) == 1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (state["ships"].is_empty()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (state["planets"][neighbor]["yards"].size() == 1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return

    # Zoom retains the world coordinate at the cursor; pan changes projection.
    var world: Vector2 = view.call("_world_point", screen)
    view.call("_zoom_at", screen, 2.0)
    if not ((view.call("_world_point", screen) as Vector2).is_equal_approx(world)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (is_equal_approx(float(view.get("zoom")), 2.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    view.call("_zoom_at", screen, 100.0)
    if not (is_equal_approx(float(view.get("zoom")), 64.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.call("_world_point", screen) as Vector2).is_equal_approx(world)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    view.call("_zoom_at", screen, 0.03125)
    mouse.button_index = MOUSE_BUTTON_RIGHT
    view.call("_map_input", mouse)
    var motion := InputEventMouseMotion.new()
    motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
    motion.relative = Vector2(40, -25)
    var before: Vector2 = view.call("_screen_point", points[neighbor])
    view.call("_map_input", motion)
    if not ((view.call("_screen_point", points[neighbor]) as Vector2).is_equal_approx(before + motion.relative)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    mouse.pressed = false
    view.call("_map_input", mouse)
    view.call("_reset_view")
    if not (is_equal_approx(float(view.get("zoom")), 1.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("pan") as Vector2).is_zero_approx()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    view.call("_pan_camera", Vector2(1, 1), 0.5)
    var keyboard_pan: Vector2 = view.get("pan")
    if not (keyboard_pan.x < 0.0 and keyboard_pan.y < 0.0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (is_equal_approx(keyboard_pan.length(), 210.0)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    view.call("_reset_view")
    var prior_width: float = canvas.size.x
    var fixed_point: Vector2 = view.call("_screen_point", points[0])
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.pressed = true
    mouse.position = Vector2(-100, -100)
    view.call("_map_input", mouse)
    if not (int(view.get("selected")) == -1 and not inspector.visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    session.call("_economy_tick")
    session.call("_economy_tick")
    if not (int(view.get("selected")) == -1 and not inspector.visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    await process_frame
    if not (is_equal_approx(canvas.size.x, prior_width)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not overview.visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.call("_screen_point", points[0]) as Vector2).is_equal_approx(fixed_point)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    mouse.position = view.call("_screen_point", points[0])
    view.call("_map_input", mouse)
    if not (int(view.get("selected")) == 0 and inspector.visible and overview.visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.call("_screen_point", points[0]) as Vector2).is_equal_approx(fixed_point)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return

    session.call("request_operation", 0, "ship")
    for i in range(100):
        session.call("_economy_tick")
    if not (state["ships"].size() == 1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("ship_visuals") as Dictionary).size() == 1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((idle_rows[0]["label"] as Label).text.contains("Idle")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((idle_rows[0]["progress"] as ProgressBar).value == 0.0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var mineral_button: Button = view.get("miner_button")
    if not (not mineral_button.disabled):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var owner_label: Label = view.get("system_owner_label")
    if not (owner_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (owner_label.get_parent() == (view.get("info") as Label).get_parent()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (owner_label.text == str(session.get("players")[1]["name"])):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (view.call("_empire_color_index", 1) == 1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var normal: Dictionary = {"abundance": {"Metals": 1.0, "Plastics": 1.0, "Crystals": 1.0}, "bonuses": {"Organics": 1.0}, "advanced_bonus": 1.0}
    if not (view.call("_system_bonus_text", normal) == ""):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    normal["abundance"]["Metals"] = 1.5
    if not (view.call("_system_bonus_text", normal) == "Metal production 150%"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var production: Dictionary = view.get("production_values")
    await process_frame
    for resource in production:
        for key in ["stock", "level", "rate", "bonus"]:
            var value: Label = production[resource][key]
            if not (value.autowrap_mode == TextServer.AUTOWRAP_OFF):
                push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
                quit(1)
                return
            if not (value.get_line_count() == 1):
                push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
                quit(1)
                return
            if not (value.size.x >= value.get_minimum_size().x):
                push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
                quit(1)
                return
        if not ((production[resource]["level"].get_parent() as Control).size.y < 36.0):
            push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
            quit(1)
            return
    if not (production.size() == 6):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((production["Metals"]["level"] as Label).text == "1"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((production["Metals"]["rate"] as Label).tooltip_text.ends_with("/yr")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (view.call("_planet_color", state["planets"][0]) is Color):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var layout: Dictionary = view.call("_system_visual", 0, state)
    var bodies: Array = layout["bodies"]
    if not (bodies.size() >= 2 and bodies.size() <= 6):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var body_start: Vector2 = view.call("_body_position", bodies[0], 60.0, 0.0)
    var body_next: Vector2 = view.call("_body_position", bodies[0], 60.0, 1.0)
    if not (not body_start.is_equal_approx(body_next)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (bodies[0]["surface_seed"] != bodies[1]["surface_seed"]):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var first_texture: Texture2D = view.call("_body_texture", bodies[0])
    var second_texture: Texture2D = view.call("_body_texture", bodies[1])
    if not (first_texture != second_texture):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (first_texture == view.call("_body_texture", bodies[0])):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (is_equal_approx(body_start.length(), body_next.length())):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (view.call("_system_visual", 0, state) == layout):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var orbit_start: Vector2 = view.call("_orbit_offset", 0, 17.0, 0.0)
    var orbit_next: Vector2 = view.call("_orbit_offset", 0, 17.0, 1.0)
    if not (not orbit_start.is_equal_approx(orbit_next)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (is_equal_approx(orbit_start.length(), orbit_next.length())):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var orbit_heading: Vector2 = view.call("_orbit_direction", orbit_start)
    if not (orbit_heading.dot(orbit_next - orbit_start) > 0.0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    # Fund this isolated fighter UI scenario regardless of earlier crew-related production changes.
    var econ = preload("res://scripts/economy_rules.gd")
    for resource in econ._cost("fighter", 1):
        state["planets"][0]["stock"][resource] = maxf(float(state["planets"][0]["stock"][resource]), 2.0 * float(econ._cost("fighter", 1)[resource]))
    var fighter_button: Button = view.get("fighter_button")
    fighter_button.pressed.emit()
    var saved_metal: float = float(state["planets"][0]["stock"]["Metals"])
    state["planets"][0]["stock"]["Metals"] = 0.0
    view.call("_refresh")
    var fighter_progress: ProgressBar = build["fighter"]["build_progress"]
    if not (fighter_progress.visible and fighter_progress.get_meta("blocked") and fighter_progress.tooltip_text.contains("Metals")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    state["planets"][0]["stock"]["Metals"] = saved_metal
    view.call("_refresh")
    if not (not fighter_progress.get_meta("blocked") and not fighter_progress.has_theme_stylebox_override("fill")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    for i in range(70):
        session.call("_economy_tick")
    if not (state["ships"].size() == 2):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (state["ships"][1]["kind"] == "fighter"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    view.call("_process", 0.2)
    view.call("_zoom_at", view.call("_screen_point", points[0]), 16.0)
    var fighter_id: int = int(state["ships"][1]["id"])
    var ship_poses: Dictionary = view.call("_ship_poses", state)
    mouse.position = ship_poses[fighter_id]["point"]
    view.call("_map_input", mouse)
    if not (int(view.get("selected_ship_id")) == fighter_id):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (int(view.get("selected")) == -1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("ship_overview") as VBoxContainer).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not tabs.visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("fleet_title") as Label).text == "Military"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("fleet_detail") as Label).visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("military_lens") as Button).button_pressed == false):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    military_toggle.pressed.emit()
    var allocation_graph: Dictionary = preload("res://scripts/economy_rules.gd").military_graph(state)
    var allocation_field: int = (state["planets"] as Array).size()
    var allocation_rect: Rect2 = view.call("_combat_slider_rect", state, allocation_field, allocation_graph["points"])
    view.set("military_drag", allocation_field)
    view.set("military_drag_weights", preload("res://scripts/economy_rules.gd").military_policy(state, 1, "fighter"))
    view.call("_update_combat_drag", allocation_rect.position + Vector2(27.0, 12.0))
    if not (int(view.get("military_preview")[allocation_field]) == 50):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var release := InputEventMouseButton.new()
    release.button_index = MOUSE_BUTTON_LEFT
    release.pressed = false
    release.position = allocation_rect.position + Vector2(27.0, 12.0)
    view.call("_map_input", release)
    if not (int(state["military"][1]["fighter"][allocation_field]) == 50):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    session.call("request_military", "fighter", 0, 100)
    military_toggle.pressed.emit()
    var logistics_id: int = int(state["ships"][0]["id"])
    ship_poses = view.call("_ship_poses", state)
    mouse.position = ship_poses[logistics_id]["point"]
    view.call("_map_input", mouse)
    if not (int(view.get("selected_ship_id")) == logistics_id):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("fleet_title") as Label).text == "Logistics"):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("fleet_detail") as Label).text.contains("1 ship")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("ship_title") as Label).text.contains("Logistics ship")):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.get("ship_cargo") as VBoxContainer).get_parent().visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    await process_frame
    for label_set in [view.get("ship_cargo_labels"), view.get("fleet_cargo_labels")]:
        for resource in label_set:
            var amount: Label = label_set[resource]
            if not (amount.autowrap_mode == TextServer.AUTOWRAP_OFF):
                push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
                quit(1)
                return
            if not (amount.size.x >= amount.get_minimum_size().x):
                push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
                quit(1)
                return
            if not (amount.get_line_count() == 1):
                push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
                quit(1)
                return
            if not ((amount.get_parent() as Control).size.y < 36.0):
                push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
                quit(1)
                return
    if not ((view.get("fleet_scroll") as ScrollContainer).size.y <= inspector.size.y):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var fixed: Vector2 = view.call("_screen_point", points[0])
    mouse.position = Vector2(-10000, -10000)
    view.call("_map_input", mouse)
    if not (int(view.get("selected_ship_id")) == -1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not inspector.visible and not overview.visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not ((view.call("_screen_point", points[0]) as Vector2).is_equal_approx(fixed)):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    mouse.position = view.call("_screen_point", points[0])
    view.call("_map_input", mouse)
    if not (int(view.get("selected")) == 0 and tabs.visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    var explored: Dictionary = state["explored"][1]
    var unknown: int = -1
    for i in range(points.size()):
        if not explored["planets"].has(i):
            unknown = i
            break
    if not (unknown >= 0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    if not (not state["fog_of_war"]):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    mouse.position = view.call("_screen_point", points[unknown])
    view.call("_map_input", mouse)
    if not (int(view.get("selected")) == unknown):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    state["fog_of_war"] = true
    view.call("_map_input", mouse)
    if not (int(view.get("selected")) == -1):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    state["fog_of_war"] = false
    # Select a field without artificially revealing it.
    if not (state["map"]["fields"] as Array).is_empty():
        mouse.position = view.call("_screen_point", state["map"]["fields"][0]["position"])
        view.call("_map_input", mouse)
        if not (int(view.get("selected_field")) == 0):
            push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
            quit(1)
            return
        var metals: CheckBox = view.get("mining_metals")
        if not (metals.button_pressed):
            push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
            quit(1)
            return
        metals.button_pressed = false
        if not (not state["mining_policies"][1][0]["Metals"]):
            push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
            quit(1)
            return
        mouse.position = Vector2(-10000, -10000)
        view.call("_map_input", mouse)
    # Every replicated hull has a pose, regardless of team, discovery or activity.
    var visible_state: Dictionary = state.duplicate(true)
    visible_state["fog_of_war"] = true
    visible_state["teams"][22] = 2
    visible_state["teams"][23] = 1
    visible_state["ships"] = []
    var unknown_neighbor: int = -1
    for edge in visible_state["map"]["edges"]:
        if int(edge[0]) == unknown:
            unknown_neighbor = int(edge[1])
        elif int(edge[1]) == unknown:
            unknown_neighbor = int(edge[0])
    if not (unknown_neighbor >= 0):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    for fixture in [{"id": 90001, "owner": 22, "kind": "fighter", "at": unknown, "route": [], "leg": 0.0, "combat_target": 90002},
            {"id": 90002, "owner": 23, "kind": "ship", "at": unknown, "route": [unknown_neighbor], "leg": 10.0},
            {"id": 90003, "owner": 22, "kind": "colony_ship", "at": unknown, "route": [], "leg": 0.0}]:
        visible_state["ships"].append(fixture)
    if not (visible_state["map"]["fields"] as Array).is_empty():
        var field: Dictionary = visible_state["map"]["fields"][0]
        visible_state["ships"].append({"id": 90004, "owner": 22, "kind": "miner", "at": int(field["anchor"]), "route": [], "leg": 0.0, "mining_mode": "mining", "mining_target": field["position"], "field_leg": 1.0})
        visible_state["ships"].append({"id": 90005, "owner": 23, "kind": "fighter", "at": points.size(), "route": [], "leg": 0.0})
    var all_poses: Dictionary = view.call("_ship_poses", visible_state)
    if not (all_poses.size() == visible_state["ships"].size()):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    for fixture in visible_state["ships"]:
        if not (all_poses.has(int(fixture["id"]))):
            push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
            quit(1)
            return
    # A consumed/disappearing ship clears its selection, rather than leaving stale details.
    view.set("selected", -1)
    view.set("selected_ship_id", logistics_id)
    state["ships"].remove_at(0)
    view.call("_refresh")
    if not (int(view.get("selected_ship_id")) == -1 and not inspector.visible):
        push_error("Map smoke assertion failed at line %d" % get_stack()[0]["line"])
        quit(1)
        return
    await process_frame
    await process_frame
    print("PASS: select without capture, colony dispatch and arrival, zoom anchor, pan, reset and ship rendering")
    quit(0)

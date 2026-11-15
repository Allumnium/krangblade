extends Control
## Planet map and inspector. Host/solo session owns all simulation mutations.
const MAP = preload("res://scripts/planet_map.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const BACKDROP = preload("res://scripts/space_background.gd")
const PLANET = preload("res://assets/ui/planet.svg")
const ECONOMY = preload("res://scripts/economy_rules.gd")
const COLORS = [Color("#607286"), Color("#67d4a9"), Color("#f4a46a"), Color("#77aafe"),
    Color("#ce91ed"), Color("#eed16b"), Color("#f084a6"), Color("#6bcbd4"), Color("#ed7577")]
const PANEL_WIDTH: float = 392.0
const HEADER_HEIGHT: float = 90.0
const KEYBOARD_PAN_SPEED: float = 420.0
const RADIUS: float = 17.0
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 4.0
const SNAPSHOT_SECONDS: float = 0.2

var session: Node
var map_canvas: Control
var header_panel: PanelContainer
var brand_label: Label
var inspector_panel: PanelContainer
var inspector_tabs: TabContainer
var population_label: Label
var population_bar: ProgressBar
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
var drag_button: int = 0
var ship_visuals: Dictionary = {}
var colony_picker: OptionButton
var send_colony_button: Button
var colony_button: Button
var colony_choices: Array[int] = []
var selected: int = -1
var initial_selection_done: bool = false
var global_resource_labels: Dictionary = {}
var global_resource_tiles: Dictionary = {}
var global_population_label: Label
var global_craft_label: Label
var global_planet_label: Label
var year_label: Label
var trade_picker: OptionButton
var trade_detail: Label
var heading: Label
var info: Label
var stock_labels: Dictionary = {}
var level_labels: Dictionary = {}
var inventory: VBoxContainer
var job_progress: ProgressBar
var job_cost: HBoxContainer
var job_cost_key: String = ""
var visual_clock: float = 0.0
var fleet: Label
var resource_picker: OptionButton
var resource_detail: Label
var min_stock: SpinBox
var max_stock: SpinBox
var threshold_button: Button
var upgrade_resource: Button
var ship_button: Button
var yard_button: Button
var yard_picker: OptionButton
var yard_info: Label
var upgrade_yard: Button
var jobs: ItemList
var cancel_button: Button
var leave: Button
var last_job_text: String = ""
var last_yard_text: String = ""

func _ready() -> void:
    theme = HUD.create()
    session = get_node("/root/GameSession")
    session.connect("phase_changed", _refresh)
    session.connect("status_changed", _refresh)
    session.connect("economy_changed", _on_economy_changed)
    _build_ui()
    _on_economy_changed()
    session.call("match_scene_loaded")

func _label(value: String, font_size: int = 14) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    return label

func _button(text: String, action: Callable, parent: Container) -> Button:
    var b := Button.new()
    b.text = text
    b.pressed.connect(action)
    b.custom_minimum_size.y = 32
    parent.add_child(b)
    return b

func _build_ui() -> void:
    var background := ColorRect.new()
    background.set_script(BACKDROP)
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    map_canvas = Control.new()
    add_child(map_canvas)
    map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    map_canvas.offset_left = 8
    map_canvas.offset_top = HEADER_HEIGHT + 16
    map_canvas.offset_right = -PANEL_WIDTH - 8
    map_canvas.offset_bottom = -8
    map_canvas.clip_contents = true
    map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
    map_canvas.gui_input.connect(_map_input)
    map_canvas.draw.connect(_draw_map)
    map_canvas.resized.connect(map_canvas.queue_redraw)
    header_panel = PanelContainer.new()
    add_child(header_panel)
    header_panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928ed"), Color("#284661"), 6))
    header_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    header_panel.offset_left = 8
    header_panel.offset_right = -8
    header_panel.offset_top = 8
    header_panel.offset_bottom = 8 + HEADER_HEIGHT
    var header_body := VBoxContainer.new()
    header_body.add_theme_constant_override("separation", 5)
    header_panel.add_child(header_body)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    header_body.add_child(row)
    leave = _button("RETURN", _leave, row)
    brand_label = _label("WARBOUND", 21)
    brand_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    brand_label.add_theme_color_override("font_color", HUD.ACCENT)
    row.add_child(brand_label)
    heading = _label("EMPIRE", 13)
    heading.autowrap_mode = TextServer.AUTOWRAP_OFF
    heading.add_theme_color_override("font_color", HUD.MUTED)
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.clip_text = true
    heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    row.add_child(heading)
    year_label = _global_stat(row, "YEAR  1", HUD.ACCENT)
    _button("RESET VIEW", _reset_view, row)
    _build_global_bar(header_body)
    inspector_panel = PanelContainer.new()
    add_child(inspector_panel)
    inspector_panel.anchor_left = 1.0
    inspector_panel.anchor_right = 1.0
    inspector_panel.anchor_bottom = 1.0
    inspector_panel.offset_left = -PANEL_WIDTH
    inspector_panel.offset_right = -8
    inspector_panel.offset_top = HEADER_HEIGHT + 16
    inspector_panel.offset_bottom = -8
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 8)
    inspector_panel.add_child(body)
    var overview: VBoxContainer = HUD.section(body, "01  /  PLANETARY COMMAND")
    info = _label("", 19)
    overview.add_child(info)
    population_label = _label("", 13)
    overview.add_child(population_label)
    population_bar = ProgressBar.new()
    population_bar.custom_minimum_size.y = 8
    population_bar.show_percentage = false
    population_bar.tooltip_text = "Population relative to local Organics-supported capacity"
    overview.add_child(population_bar)
    fleet = _label("", 13)
    fleet.add_theme_color_override("font_color", HUD.MUTED)
    overview.add_child(fleet)
    colony_picker = OptionButton.new()
    overview.add_child(colony_picker)
    send_colony_button = _button("SEND COLONY SHIP", _send_colony, overview)
    HUD.action(send_colony_button, Color("#c7a4ff"))
    inspector_tabs = TabContainer.new()
    inspector_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    inspector_tabs.clip_contents = true
    body.add_child(inspector_tabs)
    var economy_page: VBoxContainer = _inspector_page("Economy")
    var trade_page: VBoxContainer = _inspector_page("Trade")
    var shipyard_page: VBoxContainer = _inspector_page("Shipyards")
    var resources: VBoxContainer = HUD.section(economy_page, "RESOURCE INVENTORY")
    inventory = VBoxContainer.new()
    inventory.add_theme_constant_override("separation", 3)
    resources.add_child(inventory)
    var columns := HBoxContainer.new()
    inventory.add_child(columns)
    var resource_header := _label("RESOURCE", 11)
    resource_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    resource_header.add_theme_color_override("font_color", HUD.MUTED)
    columns.add_child(resource_header)
    var stock_header := _label("STOCK", 11)
    stock_header.custom_minimum_size.x = 72
    stock_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    stock_header.add_theme_color_override("font_color", HUD.MUTED)
    columns.add_child(stock_header)
    var level_header := _label("LV", 11)
    level_header.custom_minimum_size.x = 32
    level_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    level_header.add_theme_color_override("font_color", HUD.MUTED)
    columns.add_child(level_header)
    for resource in ECONOMY.RESOURCES:
        var tile := PanelContainer.new()
        tile.add_theme_stylebox_override("panel", HUD.surface(Color("#122337"), Color("#1d354b"), 4, 3))
        inventory.add_child(tile)
        var line := HBoxContainer.new()
        tile.add_child(line)
        var icon := TextureRect.new()
        icon.texture = HUD.ICONS[resource]
        icon.custom_minimum_size = Vector2(22, 22)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        line.add_child(icon)
        var resource_name := _label(resource, 13)
        resource_name.add_theme_color_override("font_color", HUD.COLORS[resource])
        resource_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        line.add_child(resource_name)
        var stock_label := _label("—", 14)
        stock_label.custom_minimum_size.x = 72
        stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        line.add_child(stock_label)
        stock_labels[resource] = stock_label
        var level_label := _label("—", 12)
        level_label.custom_minimum_size.x = 32
        level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        level_label.add_theme_color_override("font_color", HUD.MUTED)
        line.add_child(level_label)
        level_labels[resource] = level_label
    var production: VBoxContainer = HUD.section(economy_page, "PRODUCTION")
    resource_picker = OptionButton.new()
    for resource in ECONOMY.RESOURCES:
        resource_picker.add_icon_item(HUD.ICONS[resource], resource)
    resource_picker.item_selected.connect(func(_i: int) -> void: _refresh())
    production.add_child(resource_picker)
    resource_detail = _label("")
    production.add_child(resource_detail)
    upgrade_resource = _button("UPGRADE PRODUCTION", func() -> void: _operation("production", _resource()), production)
    HUD.action(upgrade_resource)
    var logistics: VBoxContainer = HUD.section(trade_page, "TRADE THRESHOLDS")
    trade_picker = OptionButton.new()
    for resource in ECONOMY.RESOURCES:
        trade_picker.add_icon_item(HUD.ICONS[resource], resource)
    trade_picker.item_selected.connect(func(_i: int) -> void: _load_thresholds(); _refresh())
    logistics.add_child(trade_picker)
    trade_detail = _label("")
    logistics.add_child(trade_detail)
    var thresholds := HBoxContainer.new()
    logistics.add_child(thresholds)
    for i in range(2):
        var col := VBoxContainer.new()
        col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        thresholds.add_child(col)
        col.add_child(_label("Import below" if i == 0 else "Export above", 12))
        var spin := SpinBox.new()
        spin.max_value = 1000000
        spin.step = 1
        spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        col.add_child(spin)
        if i == 0:
            min_stock = spin
        else:
            max_stock = spin
    threshold_button = _button("APPLY THRESHOLDS", _apply_thresholds, logistics)
    var shipyards: VBoxContainer = HUD.section(shipyard_page, "SHIPYARDS")
    yard_picker = OptionButton.new()
    yard_picker.item_selected.connect(func(_i: int) -> void: _refresh())
    shipyards.add_child(yard_picker)
    yard_info = _label("")
    shipyards.add_child(yard_info)
    ship_button = _button("BUILD LOGISTICS SHIP", func() -> void: _operation("ship"), shipyards)
    HUD.action(ship_button)
    colony_button = _button("BUILD COLONY SHIP", func() -> void: _operation("colony_ship"), shipyards)
    HUD.action(colony_button, Color("#c7a4ff"))
    yard_button = _button("BUILD SHIPYARD", func() -> void: _operation("yard"), shipyards)
    upgrade_yard = _button("UPGRADE SHIPYARD", func() -> void: _operation("yard_upgrade", str(yard_picker.selected)), shipyards)
    var queue: VBoxContainer = HUD.section(shipyard_page, "CONSTRUCTION QUEUE")
    jobs = ItemList.new()
    jobs.custom_minimum_size.y = 130
    jobs.item_selected.connect(func(_i: int) -> void: _refresh())
    queue.add_child(jobs)
    job_progress = ProgressBar.new()
    job_progress.custom_minimum_size.y = 20
    job_progress.show_percentage = true
    queue.add_child(job_progress)
    job_cost = HBoxContainer.new()
    queue.add_child(job_cost)
    cancel_button = _button("CANCEL SELECTED / REFUND", _cancel, queue)
    HUD.action(cancel_button, Color("#e9a276"))

func _build_global_bar(parent: Container) -> void:
    var stats := HBoxContainer.new()
    stats.add_theme_constant_override("separation", 4)
    parent.add_child(stats)
    for resource in ECONOMY.RESOURCES:
        var tile := PanelContainer.new()
        tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tile.add_theme_stylebox_override("panel", HUD.surface(Color("#122337"), Color("#284661"), 4, 3))
        stats.add_child(tile)
        var line := HBoxContainer.new()
        tile.add_child(line)
        var icon := TextureRect.new()
        icon.texture = HUD.ICONS[resource]
        icon.custom_minimum_size = Vector2(18, 18)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        line.add_child(icon)
        var value := _label("0", 13)
        value.autowrap_mode = TextServer.AUTOWRAP_OFF
        value.clip_text = true
        value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        value.add_theme_color_override("font_color", HUD.COLORS[resource])
        line.add_child(value)
        global_resource_labels[resource] = value
        global_resource_tiles[resource] = tile
    global_population_label = _global_stat(stats, "POP  0 M", Color("#b2e2a9"))
    global_craft_label = _global_stat(stats, "CRAFT  0", Color("#c7a4ff"))
    global_planet_label = _global_stat(stats, "WORLDS  0", HUD.ACCENT)

func _global_stat(parent: Container, value: String, tint: Color) -> Label:
    var tile := PanelContainer.new()
    tile.add_theme_stylebox_override("panel", HUD.surface(Color("#122337"), Color("#284661"), 4, 3))
    parent.add_child(tile)
    var label := _label(value, 12)
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.add_theme_color_override("font_color", tint)
    label.mouse_filter = Control.MOUSE_FILTER_PASS
    tile.add_child(label)
    return label

func _compact_amount(value: float) -> String:
    if value >= 1000000000.0:
        return "%.1fB" % (value / 1000000000.0)
    if value >= 1000000.0:
        return "%.1fM" % (value / 1000000.0)
    if value >= 1000.0:
        return "%.1fK" % (value / 1000.0)
    return "%.0f" % value

func _refresh_global_bar(state: Dictionary) -> void:
    year_label.text = "YEAR  %d" % ECONOMY.current_year(state)
    year_label.tooltip_text = "One game year per simulation second"
    var totals: Dictionary = ECONOMY.empire_totals(state, _me())
    for resource in ECONOMY.RESOURCES:
        var value: float = float(totals["resources"][resource])
        global_resource_labels[resource].text = _compact_amount(value)
        global_resource_tiles[resource].tooltip_text = "%s: %.1f total\nPlanet inventories: %.1f\nShip cargo: %.1f" % [
            resource, value, float(totals["stock"][resource]), float(totals["cargo"][resource])]
    global_population_label.text = "POP  %s" % _compact_amount(float(totals["population"]) * 1000000.0)
    global_population_label.tooltip_text = "Population across owned planets: %.2f million" % float(totals["population"])
    global_craft_label.text = "CRAFT  %d" % int(totals["craft"])
    global_craft_label.tooltip_text = "%d logistics ships / %d colony ships" % [int(totals["logistics"]), int(totals["colonies"])]
    global_planet_label.text = "WORLDS  %d" % int(totals["planets"])
    global_planet_label.tooltip_text = "Owned planets (excludes allied planets)"

func _inspector_page(title_text: String) -> VBoxContainer:
    var scroll := ScrollContainer.new()
    scroll.name = title_text
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    inspector_tabs.add_child(scroll)
    var page := VBoxContainer.new()
    page.add_theme_constant_override("separation", 8)
    page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(page)
    return page

func _state() -> Dictionary:
    return session.get("economy")

func _planet() -> Dictionary:
    var planets: Array = _state().get("planets", [])
    if selected < 0 or selected >= planets.size():
        return {}
    return planets[selected]

func _me() -> int:
    return 1 if bool(session.get("is_solo")) else multiplayer.get_unique_id()

func _resource() -> String:
    return resource_picker.get_item_text(resource_picker.selected)

func _trade_resource() -> String:
    return trade_picker.get_item_text(trade_picker.selected)

func _load_thresholds() -> void:
    var p: Dictionary = _planet()
    if p.is_empty():
        return
    var t: Dictionary = p["thresholds"][_trade_resource()]
    min_stock.value = float(t["min"])
    max_stock.value = float(t["max"])

func _apply_thresholds() -> void:
    if min_stock.value > max_stock.value:
        max_stock.value = min_stock.value
    session.call("request_thresholds", selected, _trade_resource(), min_stock.value, max_stock.value)

func _operation(kind: String, target: String = "") -> void:
    session.call("request_operation", selected, kind, target)

func _cancel() -> void:
    var selection: PackedInt32Array = jobs.get_selected_items()
    if not selection.is_empty():
        session.call("request_cancel", selected, int(jobs.get_item_metadata(selection[0])))

func _refresh() -> void:
    if is_instance_valid(map_canvas):
        map_canvas.queue_redraw()
    if not is_instance_valid(heading):
        return
    var state: Dictionary = _state()
    var phase: String = str(session.get("phase"))
    heading.text = "EMPIRE  /  " + str(session.get("status"))
    _refresh_global_bar(state)
    leave.text = "MENU" if bool(session.get("is_solo")) else ("RETURN TO LOBBY" if multiplayer.is_server() else "LEAVE")
    if phase == "loading":
        leave.text = "CANCEL START" if multiplayer.is_server() else "LEAVE"
    var count: int = 0
    var moving: int = 0
    var colonies: int = 0
    var available_colonies: int = 0
    for ship in state.get("ships", []):
        if int(ship["owner"]) == _me():
            if ship.get("kind", "ship") == "colony_ship":
                colonies += 1
                if (ship["route"] as Array).is_empty():
                    available_colonies += 1
                continue
            count += 1
            if not (ship["route"] as Array).is_empty():
                moving += 1
    fleet.text = "LOGISTICS   %d ships / %d traveling\nCOLONY   %d ships / %d idle" % [count, moving, colonies, available_colonies]
    var planets: Array = state.get("planets", [])
    if not initial_selection_done and not planets.is_empty():
        initial_selection_done = true
        for i in range(planets.size()):
            if int(planets[i]["owner"]) == _me():
                selected = i
                _load_thresholds()
                break
    var p: Dictionary = _planet()
    inspector_panel.visible = not p.is_empty()
    map_canvas.offset_right = -PANEL_WIDTH - 8 if inspector_panel.visible else -8
    var owned: bool = not p.is_empty() and int(p["owner"]) == _me() and phase == "match"
    _refresh_colony_choices(state, p, phase)
    colony_button.disabled = not owned
    threshold_button.disabled = not owned
    upgrade_resource.disabled = true
    ship_button.disabled = true
    yard_button.disabled = not owned
    upgrade_yard.disabled = true
    cancel_button.disabled = true
    if p.is_empty():
        info.text = "Select a planet."
        population_label.text = ""
        population_bar.hide()
        resource_detail.text = ""
        trade_detail.text = ""
        yard_info.text = ""
        jobs.clear()
        inventory.hide()
        job_progress.hide()
        job_cost.hide()
        return
    var owner: int = int(p["owner"])
    var roster: Dictionary = session.get("players")
    var name_text: String = "Neutral" if owner == 0 else str(roster.get(owner, {}).get("name", "Player"))
    info.text = "Planet %02d%s\n%s" % [selected + 1, "  /  Home" if bool(p["home"]) else "", name_text]
    var population: float = float(p["population"])
    var capacity: float = ECONOMY.population_capacity(p)
    population_label.text = "Population  %.1f / %.1f M   •   %+.2f M/yr\nResource output  ×%.2f" % [population, capacity, ECONOMY.population_growth(p), ECONOMY.population_multiplier(p)]
    population_bar.visible = capacity > 0.0
    population_bar.value = 100.0 * population / maxf(capacity, 1.0)
    inventory.show()
    for r in ECONOMY.RESOURCES:
        stock_labels[r].text = "%.1f" % float(p["stock"][r])
        level_labels[r].text = str(int(p["levels"][r]))
    var resource: String = _resource()
    var available: bool = ECONOMY.ACTIVE_PRODUCTION.has(resource) and (not ECONOMY.EXTRACTED.has(resource) or float(p["abundance"].get(resource, 0.0)) > 0.0)
    var modifier: float = float(p["bonuses"].get(resource, 1.0))
    var detail: String = "Production rules not defined yet."
    if ECONOMY.EXTRACTED.has(resource):
        detail = "Deposit: %.2fx  •  Output: %.1f/s" % [float(p["abundance"].get(resource, 0.0)), ECONOMY.rate(p, resource)]
    elif resource == "Organics":
        var output: float = ECONOMY.rate(p, resource)
        var demand: float = ECONOMY.organics_demand(p)
        detail = "Farming: %.2f/yr  •  Demand: %.2f/yr\nNet: %+.2f/yr  •  Supports %.1f M" % [output, demand, output - demand, ECONOMY.population_capacity(p)]
    resource_detail.text = "%s\nPlanet bonus: %.2fx" % [detail, modifier]
    var trade_resource: String = _trade_resource()
    var t: Dictionary = p["thresholds"][trade_resource]
    trade_detail.text = "Stock: %.1f\nCurrent import/export: %.0f / %.0f" % [float(p["stock"][trade_resource]), float(t["min"]), float(t["max"])]
    upgrade_resource.disabled = not owned or not available or ECONOMY._has_job(p, "production", resource)
    ship_button.disabled = not owned or not bool(p["home"])
    var yards: Array = p["yards"]
    var yard_text: String = str(yards.size())
    for y in yards:
        yard_text += ":" + str(y["level"])
    if yard_text != last_yard_text:
        var previous: int = yard_picker.selected
        yard_picker.clear()
        for i in range(yards.size()):
            yard_picker.add_item("Shipyard %d / Level %d" % [i + 1, int(yards[i]["level"])])
        if not yards.is_empty():
            yard_picker.select(clampi(previous, 0, yards.size() - 1))
        last_yard_text = yard_text
    var y_index: int = yard_picker.selected
    if y_index >= 0 and y_index < yards.size():
        var y: Dictionary = yards[y_index]
        var upgrading: bool = ECONOMY._has_job(p, "yard_upgrade", str(y_index))
        yard_info.text = "Work/s: %.1f  •  Max size: %d  •  %s" % [ECONOMY.yard_speed(int(y["level"])), ECONOMY.max_size(int(y["level"])), "Upgrading" if upgrading else ("Idle" if int(y["job"]) < 0 else "Building")]
        upgrade_yard.disabled = not owned or upgrading
    else:
        yard_info.text = "No shipyards"
    var selected_job: int = -1
    var old: PackedInt32Array = jobs.get_selected_items()
    if not old.is_empty():
        selected_job = int(jobs.get_item_metadata(old[0]))
    var job_text: String = str(selected) + str(p["queue"])
    if job_text != last_job_text:
        jobs.clear()
        for item in p["queue"]:
            var name_value: String = "Logistics ship" if item["kind"] == "ship" else str(item["kind"]).replace("_", " ").capitalize()
            var line: String = "%s %s — %.0f%%" % [name_value, str(item["target"]), 100.0 * float(item["progress"]) / float(item["work"])]
            if ECONOMY._possible(p, item) <= ECONOMY.EPS:
                line += " (waiting for materials)"
            jobs.add_item(line)
            if item["kind"] == "production":
                jobs.set_item_icon(jobs.item_count - 1, HUD.ICONS[item["target"]])
            if ECONOMY._possible(p, item) <= ECONOMY.EPS:
                jobs.set_item_custom_fg_color(jobs.item_count - 1, Color("#e9a276"))
            var i: int = jobs.item_count - 1
            jobs.set_item_metadata(i, int(item["id"]))
            if int(item["id"]) == selected_job:
                jobs.select(i)
        last_job_text = job_text
    cancel_button.disabled = not owned or jobs.get_selected_items().is_empty()
    _refresh_selected_job(p)

func _refresh_selected_job(p: Dictionary) -> void:
    var selection: PackedInt32Array = jobs.get_selected_items()
    var item: Dictionary = {}
    if not selection.is_empty():
        var id: int = int(jobs.get_item_metadata(selection[0]))
        for entry in p["queue"]:
            if int(entry["id"]) == id:
                item = entry
                break
    job_progress.visible = not item.is_empty()
    job_cost.visible = not item.is_empty()
    if item.is_empty():
        return
    job_progress.value = 100.0 * float(item["progress"]) / float(item["work"])
    var cost: String = str(item["allocated"]) + str(item["cost"])
    if cost == job_cost_key:
        return
    job_cost_key = cost
    for child in job_cost.get_children():
        job_cost.remove_child(child)
        child.queue_free()
    for r in item["cost"]:
        var icon := TextureRect.new()
        icon.texture = HUD.ICONS[r]
        icon.custom_minimum_size = Vector2(20, 20)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        job_cost.add_child(icon)
        var label := _label("%.0f / %.0f" % [float(item["allocated"][r]), float(item["cost"][r])], 12)
        label.add_theme_color_override("font_color", HUD.COLORS[r])
        job_cost.add_child(label)

func _leave() -> void:
    if bool(session.get("is_solo")):
        session.call("leave_solo")
    elif multiplayer.is_server():
        if str(session.get("phase")) == "loading":
            session.call("cancel_loading")
        else:
            session.call("return_to_lobby")
    else:
        session.call("leave_session")
        get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _refresh_colony_choices(state: Dictionary, p: Dictionary, phase: String) -> void:
    var neutral: bool = not p.is_empty() and int(p.get("owner", -1)) == 0 and phase == "match"
    colony_picker.visible = neutral
    send_colony_button.visible = neutral
    var choices: Array[int] = []
    var labels: Array[String] = []
    if neutral:
        for ship in state["ships"]:
            if not ECONOMY.colony_path(state, _me(), ship, selected).is_empty():
                choices.append(int(ship["id"]))
                labels.append("Colony ship #%d • Planet %02d" % [int(ship["id"]), int(ship["at"]) + 1])
    if choices != colony_choices or colony_picker.item_count == 0:
        var previous: int = -1
        if colony_picker.selected >= 0 and colony_picker.selected < colony_choices.size():
            previous = colony_choices[colony_picker.selected]
        colony_choices = choices
        colony_picker.clear()
        for label_text in labels:
            colony_picker.add_item(label_text)
        if choices.is_empty():
            colony_picker.add_item("No reachable idle colony ships")
        else:
            colony_picker.select(maxi(0, choices.find(previous)))
    colony_picker.disabled = choices.is_empty()
    send_colony_button.disabled = choices.is_empty()

func _send_colony() -> void:
    var index: int = colony_picker.selected
    if not send_colony_button.disabled and index >= 0 and index < colony_choices.size():
        session.call("request_colonize", colony_choices[index], selected)

func _reset_view() -> void:
    zoom = 1.0
    pan = Vector2.ZERO
    map_canvas.queue_redraw()

func _fit() -> float:
    var area: Vector2 = map_canvas.size - Vector2(24, 52)
    return maxf(0.01, minf(area.x / MAP.SIZE.x, area.y / MAP.SIZE.y))

func _screen_point(point: Vector2) -> Vector2:
    return map_canvas.size * 0.5 + pan + (point - MAP.SIZE * 0.5) * _fit() * zoom

func _world_point(point: Vector2) -> Vector2:
    return MAP.SIZE * 0.5 + (point - map_canvas.size * 0.5 - pan) / (_fit() * zoom)

func _zoom_at(point: Vector2, multiplier: float) -> void:
    var world: Vector2 = _world_point(point)
    zoom = clampf(zoom * multiplier, MIN_ZOOM, MAX_ZOOM)
    pan += point - _screen_point(world)
    map_canvas.queue_redraw()

func _planet_radius(index: int, state: Dictionary) -> float:
    return clampf((RADIUS + (3.0 if bool(state["planets"][index]["home"]) else 0.0)) * zoom, 9.0, 48.0)

func _select_at(point: Vector2) -> void:
    var state: Dictionary = _state()
    if state.is_empty() or str(session.get("phase")) != "match":
        return
    var points: Array = state["map"]["points"]
    var nearest: float = INF
    var hit: int = -1
    for i in range(points.size()):
        var distance: float = point.distance_to(_screen_point(points[i]))
        if distance <= _planet_radius(i, state) + 4.0 and distance < nearest:
            nearest = distance
            hit = i
    selected = hit
    var focused: Control = get_viewport().gui_get_focus_owner()
    if is_instance_valid(focused):
        focused.release_focus()
    if hit >= 0:
        _load_thresholds()
    _refresh()

func _map_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse: InputEventMouseButton = event
        if mouse.button_index == MOUSE_BUTTON_MIDDLE or mouse.button_index == MOUSE_BUTTON_RIGHT:
            if mouse.pressed:
                drag_button = mouse.button_index
            elif drag_button == mouse.button_index:
                drag_button = 0
        elif mouse.pressed:
            match mouse.button_index:
                MOUSE_BUTTON_WHEEL_UP: _zoom_at(mouse.position, 1.15)
                MOUSE_BUTTON_WHEEL_DOWN: _zoom_at(mouse.position, 1.0 / 1.15)
                MOUSE_BUTTON_LEFT: _select_at(mouse.position)
    elif event is InputEventMouseMotion and drag_button != 0:
        var motion: InputEventMouseMotion = event
        if motion.button_mask == 0:
            drag_button = 0
        else:
            pan += motion.relative
            map_canvas.queue_redraw()
    map_canvas.accept_event()

func _ship_position(ship: Dictionary, points: Array) -> Vector2:
    var pos: Vector2 = points[int(ship["at"])]
    var route: Array = ship["route"]
    if not route.is_empty():
        var next: Vector2 = points[int(route[0])]
        pos = pos.lerp(next, clampf(float(ship["leg"]) / maxf(1.0, pos.distance_to(next)), 0.0, 1.0))
    return pos

func _visual_position(visual: Dictionary) -> Vector2:
    return (visual["from"] as Vector2).lerp(visual["to"], clampf(float(visual["age"]) / SNAPSHOT_SECONDS, 0.0, 1.0))

func _on_economy_changed() -> void:
    var state: Dictionary = _state()
    var updated: Dictionary = {}
    if not state.is_empty():
        var points: Array = state["map"]["points"]
        for ship in state["ships"]:
            var id: int = int(ship["id"])
            var target: Vector2 = _ship_position(ship, points)
            var previous: Dictionary = ship_visuals.get(id, {})
            if previous.is_empty():
                updated[id] = {"from": target, "to": target, "age": SNAPSHOT_SECONDS}
            elif previous["to"] != target:
                updated[id] = {"from": _visual_position(previous), "to": target, "age": 0.0}
            else:
                updated[id] = previous
    ship_visuals = updated
    _refresh()

func _keyboard_pan(delta: float) -> void:
    if str(session.get("phase")) != "match":
        return
    if not get_window().has_focus():
        return
    var focus: Control = get_viewport().gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit:
        return
    for picker in [resource_picker, trade_picker, yard_picker, colony_picker]:
        if picker.get_popup().visible:
            return
    var direction := Vector2(
        float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
        float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
    _pan_camera(direction, delta)

func _pan_camera(direction: Vector2, delta: float) -> void:
    if not direction.is_zero_approx():
        pan -= direction.normalized() * KEYBOARD_PAN_SPEED * delta
        map_canvas.queue_redraw()

func _process(delta: float) -> void:
    _keyboard_pan(delta)
    visual_clock = fmod(visual_clock + delta, TAU * 100.0)
    for visual in ship_visuals.values():
        if float(visual["age"]) < SNAPSHOT_SECONDS:
            visual["age"] = minf(SNAPSHOT_SECONDS, float(visual["age"]) + delta)
    if is_instance_valid(map_canvas):
        map_canvas.queue_redraw()

func _draw_map() -> void:
    if session == null:
        return
    var state: Dictionary = _state()
    if state.is_empty():
        return
    var points: Array = state["map"]["points"]
    var teams: Array[int] = ECONOMY.planet_teams(state)
    for edge in state["map"]["edges"]:
        var a: int = int(edge[0])
        var b: int = int(edge[1])
        var color: Color = COLORS[teams[a]].darkened(0.3) if teams[a] > 0 and teams[a] == teams[b] else Color("#40566b")
        var a_pos: Vector2 = _screen_point(points[a])
        var b_pos: Vector2 = _screen_point(points[b])
        map_canvas.draw_line(a_pos, b_pos, Color(color, 0.10), 7.0, true)
        map_canvas.draw_line(a_pos, b_pos, Color(color, 0.78), 1.5, true)
    var font: Font = ThemeDB.fallback_font
    for i in range(points.size()):
        var pos: Vector2 = _screen_point(points[i])
        var radius: float = _planet_radius(i, state)
        var tint: Color = COLORS[teams[i]]
        map_canvas.draw_circle(pos, radius + 7, Color(tint, 0.055), true)
        map_canvas.draw_circle(pos, radius + 4, Color(tint, 0.09), true)
        map_canvas.draw_texture_rect(PLANET, Rect2(pos - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)
        map_canvas.draw_arc(pos, radius + 1.5, 0.0, TAU, 48, tint, 2.0, true)
        if bool(state["planets"][i]["home"]):
            map_canvas.draw_arc(pos, radius + 5.0, 0.0, TAU, 48, Color(tint, 0.5), 1.0, true)
        if i == selected:
            var phase: float = 0.6 + 0.35 * sin(visual_clock * 3.0)
            for angle in range(4):
                var start: float = float(angle) * TAU / 4.0 + 0.1
                map_canvas.draw_arc(pos, radius + 8.0, start, start + 1.15, 14, Color(HUD.ACCENT, phase), 2.0, true)
        map_canvas.draw_string(font, pos + Vector2(-20, 5), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 40, 14, Color("#f4faff"))
    var docked: Dictionary = {}

    for ship in state["ships"]:
        var at: int = int(ship["at"])
        var route: Array = ship["route"]
        var visual: Dictionary = ship_visuals.get(int(ship["id"]), {})
        var pos: Vector2 = _ship_position(ship, points) if visual.is_empty() else _visual_position(visual)
        var direction: Vector2 = Vector2.UP
        var point: Vector2 = _screen_point(pos)
        if route.is_empty():
            # Separate idle ships around the planet; count badges handle large fleets.
            var slot: int = int(docked.get(at, 0))
            docked[at] = slot + 1
            if slot >= 8:
                continue
            direction = Vector2.from_angle(TAU * slot / 8.0 - PI * 0.5)
            point += direction * (_planet_radius(at, state) + 12.0)
        else:
            var next: Vector2 = points[int(route[0])]
            direction = (next - (points[at] as Vector2)).normalized()
            point += direction.orthogonal() * (5.0 + float(int(ship["id"]) % 5) * 4.0)
        var team: int = int(state["teams"].get(int(ship["owner"]), 0))
        var loaded: bool = ECONOMY._cargo_total(ship) > ECONOMY.EPS
        var hull: Color = COLORS[team].lightened(0.35) if not loaded else Color("#f8df8c")
        var colony: bool = ship.get("kind", "ship") == "colony_ship"
        if colony:
            hull = Color("#c7a4ff")
        var side: Vector2 = direction.orthogonal()
        var shape := PackedVector2Array([point + direction * 9, point - direction * 6 + side * 5,
            point - direction * 3, point - direction * 6 - side * 5])
        if colony:
            shape = PackedVector2Array([point + direction * 12, point + side * 7, point - direction * 9, point - side * 7])
        if not route.is_empty():
            var engine: Vector2 = point - direction * 9.0
            map_canvas.draw_circle(engine, 5.0, Color("#43a5ff30"), true)
            map_canvas.draw_line(engine, engine - direction * (5.0 + 2.0 * sin(visual_clock * 9.0)), Color("#79dfff"), 2.0, true)
        map_canvas.draw_colored_polygon(shape, hull)
        var outline: PackedVector2Array = shape.duplicate()
        outline.append(shape[0])
        map_canvas.draw_polyline(outline, Color("#08111b"), 1.5, true)
    for index in docked:
        var count: int = int(docked[index])
        var pos: Vector2 = _screen_point(points[int(index)]) + Vector2(0, _planet_radius(int(index), state) + 29)
        map_canvas.draw_string(font, pos + Vector2(-36, 0), "%d docked" % count, HORIZONTAL_ALIGNMENT_CENTER, 72, 12, Color("#e0ebf5"))
    # Overlay legend is fixed to the viewport, not the world.
    var legend_y: float = map_canvas.size.y - 10.0
    map_canvas.draw_rect(Rect2(0, legend_y - 20, map_canvas.size.x, 30), Color("#091522e8"))
    map_canvas.draw_string(font, Vector2(8, legend_y), "WASD / drag MMB/RMB · Scroll zoom · Gold: cargo · Purple: colony", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#c5d3e1"))

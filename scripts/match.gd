extends Control
## Planet map and inspector. Host/solo session owns all simulation mutations.
const MAP = preload("res://scripts/planet_map.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const BACKDROP = preload("res://scripts/space_background.gd")
const PLANET = preload("res://assets/ui/planet.svg")
const UPGRADE_SOUND = preload("res://assets/sfx/detail.wav")
const ECONOMY = preload("res://scripts/economy_rules.gd")
const COLORS = [Color("#607286"), Color("#67d4a9"), Color("#f4a46a"), Color("#77aafe"),
    Color("#ce91ed"), Color("#eed16b"), Color("#f084a6"), Color("#6bcbd4"), Color("#ed7577")]
const PANEL_WIDTH: float = 368.0
const OVERVIEW_WIDTH: float = 236.0
const HEADER_HEIGHT: float = 46.0
const KEYBOARD_PAN_SPEED: float = 420.0
const RADIUS: float = 12.0
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 64.0
const SNAPSHOT_SECONDS: float = 0.2

var session: Node
var upgrade_audio: AudioStreamPlayer
var known_upgrade_jobs: Dictionary = {}
var upgrade_audio_initialized: bool = false
var map_canvas: Control
var header_panel: PanelContainer
var inspector_panel: PanelContainer
var overview_panel: PanelContainer
var yard_activity: VBoxContainer
var yard_activity_rows: Dictionary = {}
var inspector_tabs: TabContainer
var population_label: Label
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
var drag_button: int = 0
var ship_visuals: Dictionary = {}
var colony_picker: OptionButton
var send_colony_button: Button
var colony_button: Button
var colony_choices: Array[int] = []
var selected: int = -1
var selected_ship_id: int = -1
var selected_field: int = -1
var mining_controls: VBoxContainer
var mining_enabled: CheckBox
var mining_metals: CheckBox
var mining_crystals: CheckBox
var planet_overview: VBoxContainer
var ship_overview: VBoxContainer
var ship_title: Label
var ship_detail: Label
var ship_cargo: VBoxContainer
var ship_cargo_labels: Dictionary = {}
var fleet_scroll: ScrollContainer
var fleet_overview: VBoxContainer
var fleet_title: Label
var fleet_detail: Label
var fleet_cargo: VBoxContainer
var fleet_cargo_labels: Dictionary = {}
var initial_selection_done: bool = false
var global_resource_labels: Dictionary = {}
var global_resource_tiles: Dictionary = {}
var global_population_label: Label
var year_label: Label
var info: Label
var stock_labels: Dictionary = {}
var level_labels: Dictionary = {}
var inventory: VBoxContainer
var visual_clock: float = 0.0
var system_visuals: Dictionary = {}
var system_visual_seed: int = -1
var resource_picker: OptionButton
var resource_detail: Label
var trade_sliders: Dictionary = {}
var trade_stock_labels: Dictionary = {}
var upgrade_cards: Dictionary = {}
var continuous_checks: Dictionary = {}
var repeat_icon: Texture2D
var production_summary: VBoxContainer
var production_values: Dictionary = {}
var queue_title: Label
var fighter_button: Button
var miner_button: Button
var environment_label: Label
var ship_button: Button
var yard_button: Button
var leave: Button
var match_menu: AcceptDialog
var menu_exit: Button
var queue_rows: Dictionary = {}
var queue_list: VBoxContainer

class TradeRange extends Control:
    signal committed(minimum: float, maximum: float)
    var lower: float = 10.0
    var upper: float = 20.0
    var stock_percent: float = 0.0
    var stock_color: Color = Color.WHITE
    var enabled: bool = true
    var active_handle: int = -1
    const PAD: float = 10.0
    const TRACK_Y: float = 38.0

    func set_range(minimum: float, maximum: float) -> void:
        active_handle = -1
        lower = clampf(minimum, 0.0, 100.0)
        upper = clampf(maximum, lower, 100.0)
        queue_redraw()

    func set_stock(amount: float, maximum: float, tint: Color) -> void:
        stock_percent = clampf(100.0 * amount / maxf(maximum, 1.0), 0.0, 100.0)
        stock_color = tint
        queue_redraw()

    func _x(value: float) -> float:
        return PAD + maxf(1.0, size.x - PAD * 2.0) * value / 100.0

    func _value(x: float) -> float:
        return roundf(clampf((x - PAD) / maxf(1.0, size.x - PAD * 2.0) * 100.0, 0.0, 100.0))

    func _draw() -> void:
        var font: Font = ThemeDB.fallback_font
        var low_color := Color("#67d4a9") if enabled else Color("#667687")
        var high_color := Color("#e9a276") if enabled else Color("#667687")
        var left: String = "Import < %d%%" % roundi(lower)
        var right: String = "Export > %d%%" % roundi(upper)
        draw_string(font, Vector2(PAD, 17), left, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, low_color)
        draw_string(font, Vector2(size.x - PAD - font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, 17), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, high_color)
        var lo := Vector2(_x(lower), TRACK_Y)
        var hi := Vector2(_x(upper), TRACK_Y)
        draw_line(Vector2(PAD, TRACK_Y), Vector2(size.x - PAD, TRACK_Y), Color("#344960"), 5.0, true)
        if stock_percent > 0.0:
            draw_line(Vector2(PAD, TRACK_Y), Vector2(_x(stock_percent), TRACK_Y), stock_color, 7.0, true)
        # Offset the handles vertically when their values meet, keeping both visible.
        var overlap: bool = absf(lo.x - hi.x) < 13.0
        if overlap:
            lo.y -= 5.0
            hi.y += 5.0
        draw_circle(lo, 7.0, low_color)
        draw_circle(hi, 7.0, high_color)
        draw_arc(lo, 7.0, 0.0, TAU, 24, Color("#102030"), 1.0, true)
        draw_arc(hi, 7.0, 0.0, TAU, 24, Color("#102030"), 1.0, true)

    func _move_handle(x: float) -> void:
        if active_handle == 0:
            lower = minf(_value(x), upper)
        elif active_handle == 1:
            upper = maxf(_value(x), lower)
        queue_redraw()

    func _gui_input(event: InputEvent) -> void:
        if not enabled:
            return
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                var lo := Vector2(_x(lower), TRACK_Y)
                var hi := Vector2(_x(upper), TRACK_Y)
                if absf(lo.x - hi.x) < 13.0:
                    lo.y -= 5.0
                    hi.y += 5.0
                active_handle = 0 if event.position.distance_to(lo) < event.position.distance_to(hi) else 1
                _move_handle(event.position.x)
            elif active_handle >= 0:
                _move_handle(event.position.x)
                active_handle = -1
                committed.emit(lower, upper)
            accept_event()
        elif event is InputEventMouseMotion and active_handle >= 0:
            _move_handle(event.position.x)
            accept_event()

func _ready() -> void:
    theme = HUD.create()
    session = get_node("/root/GameSession")
    session.connect("phase_changed", _refresh)
    session.connect("status_changed", _refresh)
    session.connect("economy_changed", _on_economy_changed)
    upgrade_audio = AudioStreamPlayer.new()
    upgrade_audio.stream = UPGRADE_SOUND
    add_child(upgrade_audio)
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
    map_canvas.offset_right = -8
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
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    header_panel.add_child(row)
    leave = _button("MENU", _open_menu, row)
    _build_global_bar(row)
    global_population_label = _global_stat(row, "POP  0", Color("#b2e2a9"))
    year_label = _global_stat(row, "YEAR  1", HUD.ACCENT)
    match_menu = AcceptDialog.new()
    match_menu.title = "Menu"
    match_menu.exclusive = true
    match_menu.unresizable = true
    match_menu.ok_button_text = "Resume"
    add_child(match_menu)
    menu_exit = match_menu.add_button("Leave match", false, "leave")
    match_menu.custom_action.connect(_menu_action)
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
    overview_panel = PanelContainer.new()
    add_child(overview_panel)
    overview_panel.anchor_bottom = 1.0
    overview_panel.offset_left = 8
    overview_panel.offset_right = OVERVIEW_WIDTH + 8
    overview_panel.offset_top = HEADER_HEIGHT + 16
    overview_panel.offset_bottom = -8
    var overview_scroll := ScrollContainer.new()
    overview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    overview_panel.add_child(overview_scroll)
    var overview := VBoxContainer.new()
    overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    overview.add_theme_constant_override("separation", 8)
    overview_scroll.add_child(overview)
    planet_overview = VBoxContainer.new()
    planet_overview.add_theme_constant_override("separation", 8)
    overview.add_child(planet_overview)
    ship_overview = VBoxContainer.new()
    ship_overview.add_theme_constant_override("separation", 8)
    overview.add_child(ship_overview)
    ship_title = _label("", 19)
    ship_overview.add_child(ship_title)
    ship_detail = _label("", 13)
    ship_overview.add_child(ship_detail)
    ship_cargo = HUD.section(ship_overview, "Cargo")
    _build_cargo_rows(ship_cargo, ship_cargo_labels)
    fleet_scroll = ScrollContainer.new()
    fleet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    fleet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(fleet_scroll)
    fleet_overview = VBoxContainer.new()
    fleet_overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fleet_overview.add_theme_constant_override("separation", 8)
    fleet_scroll.add_child(fleet_overview)
    fleet_title = _label("", 19)
    fleet_overview.add_child(fleet_title)
    fleet_detail = _label("", 14)
    fleet_overview.add_child(fleet_detail)
    fleet_cargo = HUD.section(fleet_overview, "Cargo")
    _build_cargo_rows(fleet_cargo, fleet_cargo_labels)
    mining_controls = HUD.section(fleet_overview, "Mine")
    mining_enabled = CheckBox.new()
    mining_enabled.text = "Enabled"
    mining_controls.add_child(mining_enabled)
    mining_metals = CheckBox.new()
    mining_metals.text = "Metals"
    mining_controls.add_child(mining_metals)
    mining_crystals = CheckBox.new()
    mining_crystals.text = "Crystals"
    mining_controls.add_child(mining_crystals)
    for check in [mining_enabled, mining_metals, mining_crystals]:
        check.toggled.connect(func(_value: bool) -> void: _apply_mining_policy())
    mining_controls.get_parent().hide()
    info = _label("", 19)
    planet_overview.add_child(info)
    environment_label = _label("", 12)
    environment_label.add_theme_color_override("font_color", HUD.MUTED)
    planet_overview.add_child(environment_label)
    population_label = _label("", 13)
    planet_overview.add_child(population_label)
    production_summary = HUD.section(planet_overview, "Production")
    _build_production_summary()
    colony_picker = OptionButton.new()
    planet_overview.add_child(colony_picker)
    send_colony_button = _button("SEND COLONY SHIP", _send_colony, planet_overview)
    HUD.action(send_colony_button, Color("#c7a4ff"))
    yard_activity = HUD.section(planet_overview, "Shipyards")
    inspector_tabs = TabContainer.new()
    inspector_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    inspector_tabs.clip_contents = true
    body.add_child(inspector_tabs)
    var economy_page: VBoxContainer = _inspector_page("Economy")
    var trade_page: VBoxContainer = _inspector_page("Trade")
    var shipyard_page: VBoxContainer = _inspector_page("Shipyards")
    var upgrades_page: VBoxContainer = _inspector_page("Upgrades")
    _build_upgrade_cards(upgrades_page)
    var resources: VBoxContainer = HUD.section(economy_page, "Inventory")
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
    var production: VBoxContainer = HUD.section(economy_page, "Production")
    resource_picker = OptionButton.new()
    for resource in ECONOMY.RESOURCES:
        resource_picker.add_icon_item(HUD.ICONS[resource], resource)
    resource_picker.item_selected.connect(func(_i: int) -> void: _refresh())
    production.add_child(resource_picker)
    resource_detail = _label("")
    production.add_child(resource_detail)
    for resource in ECONOMY.RESOURCES:
        var logistics: VBoxContainer = HUD.section(trade_page, "")
        logistics.get_child(0).hide()
        var trade_row := HBoxContainer.new()
        logistics.add_child(trade_row)
        var resource_icon := TextureRect.new()
        resource_icon.texture = HUD.ICONS[resource]
        resource_icon.custom_minimum_size = Vector2(18, 18)
        resource_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        resource_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        trade_row.add_child(resource_icon)
        var name_label := _label(resource, 13)
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_label.add_theme_color_override("font_color", HUD.COLORS[resource])
        trade_row.add_child(name_label)
        var stock_label := _label("", 12)
        trade_row.add_child(stock_label)
        trade_stock_labels[resource] = stock_label
        var slider := TradeRange.new()
        slider.custom_minimum_size.y = 56
        slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        slider.tooltip_text = "Import below the left handle; export above the right handle. 100%% = %.0f units." % ECONOMY.TRADE_REFERENCE
        slider.committed.connect(_apply_thresholds.bind(resource))
        logistics.add_child(slider)
        trade_sliders[resource] = slider
    var shipyards: VBoxContainer = HUD.section(shipyard_page, "Build")
    ship_button = _ship_build_row(shipyards, "BUILD LOGISTICS SHIP", "ship")
    HUD.action(ship_button)
    colony_button = _ship_build_row(shipyards, "BUILD COLONY SHIP", "colony_ship")
    HUD.action(colony_button, Color("#c7a4ff"))
    fighter_button = _ship_build_row(shipyards, "BUILD FIGHTER", "fighter")
    HUD.action(fighter_button, Color("#f2b57e"))
    fighter_button.tooltip_text = "Prototype fighter hull. Combat and military orders are not implemented yet."
    miner_button = _ship_build_row(shipyards, "BUILD MINING SHIP", "miner")
    HUD.action(miner_button, Color("#d8e58b"))
    miner_button.tooltip_text = "Automatically mines accessible fields from owned service systems."
    yard_button = _button("BUILD SHIPYARD", func() -> void: _operation("yard"), shipyards)
    var queue: VBoxContainer = HUD.section(shipyard_page, "Queue")
    queue_title = queue.get_child(0)
    queue_list = VBoxContainer.new()
    queue_list.add_theme_constant_override("separation", 6)
    queue.add_child(queue_list)


func _ship_build_row(parent: Container, title_text: String, kind: String) -> Button:
    var row := HBoxContainer.new()
    parent.add_child(row)
    var button: Button = _button(title_text, _operation.bind(kind), row)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var check: Button = _repeat_button(row, kind)
    continuous_checks[kind] = check
    return button

func _repeat_button(parent: Container, key: String) -> Button:
    if repeat_icon == null:
        var image := Image.new()
        image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#dbeaff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 2l4 4-4 4M3 11V9a3 3 0 0 1 3-3h15M7 22l-4-4 4-4M21 13v2a3 3 0 0 1-3 3H3"/></svg>')
        repeat_icon = ImageTexture.create_from_image(image)
    var button := Button.new()
    button.icon = repeat_icon
    button.expand_icon = true
    button.toggle_mode = true
    button.custom_minimum_size = Vector2(32, 32)
    button.add_theme_constant_override("icon_max_width", 20)
    button.tooltip_text = "Repeat automatically"
    parent.add_child(button)
    button.toggled.connect(func(enabled: bool) -> void:
        session.call("request_continuous", selected, key, enabled))
    return button

func _sync_repeat(button: Button, p: Dictionary, key: String, available: bool) -> void:
    button.set_pressed_no_signal(bool(p.get("continuous", {}).get(key, false)))
    button.disabled = not available
    button.modulate = HUD.ACCENT if button.button_pressed else Color.WHITE
    button.tooltip_text = "Repeat enabled (click to stop)" if button.button_pressed else "Repeat automatically"

func _build_production_summary() -> void:
    for resource in ECONOMY.RESOURCES:
        var row := HBoxContainer.new()
        production_summary.add_child(row)
        var icon := TextureRect.new()
        icon.texture = HUD.ICONS[resource]
        icon.custom_minimum_size = Vector2(16, 16)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        row.add_child(icon)
        var name_label := _label(resource, 12)
        name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(name_label)
        var level := _label("", 12)
        level.autowrap_mode = TextServer.AUTOWRAP_OFF
        level.custom_minimum_size.x = 32
        level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(level)
        var rate_label := _label("", 12)
        rate_label.autowrap_mode = TextServer.AUTOWRAP_OFF
        rate_label.custom_minimum_size.x = 55
        rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(rate_label)
        production_values[resource] = {"level": level, "rate": rate_label}

func _system_bonus_text(p: Dictionary) -> String:
    var lines: PackedStringArray = []
    var names: Dictionary = {"Metals": "Metal production", "Plastics": "Plastic production", "Crystals": "Crystal production", "Organics": "Organics production"}
    for resource in ECONOMY.ACTIVE_PRODUCTION:
        var percent: int = roundi(ECONOMY.production_modifier(p, resource) * 100.0)
        if percent != 100:
            lines.append("%s %d%%" % [names[resource], percent])
    var advanced: int = roundi(float(p.get("advanced_bonus", 1.0)) * 100.0)
    if advanced != 100:
        lines.append("Advanced manufacturing %d%% (future)" % advanced)
    return "\n".join(lines)

func _build_upgrade_cards(parent: Container) -> void:
    var labels: Dictionary = {"Metals": "Metal extraction", "Plastics": "Plastic extraction",
        "Textiles": "Textile production", "Organics": "Organics farming",
        "Tech": "Tech production", "Crystals": "Crystal extraction"}
    for resource in ECONOMY.RESOURCES:
        var card: VBoxContainer = HUD.section(parent, "")
        # Replace the empty section heading with a resource icon and title.
        card.get_child(0).hide()
        var row := HBoxContainer.new()
        card.add_child(row)
        var icon := TextureRect.new()
        icon.texture = HUD.ICONS[resource]
        icon.custom_minimum_size = Vector2(24, 24)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        row.add_child(icon)
        var title := _label(labels[resource], 15)
        title.add_theme_color_override("font_color", HUD.COLORS[resource])
        title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(title)
        var detail := _label("", 12)
        card.add_child(detail)
        var progress := ProgressBar.new()
        progress.custom_minimum_size.y = 15
        card.add_child(progress)
        var actions := HBoxContainer.new()
        card.add_child(actions)
        var action: Button = _button("UPGRADE", _upgrade_card_action.bind(resource), actions)
        action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        HUD.action(action)
        var repeat: Button = _repeat_button(actions, "production:" + resource)
        upgrade_cards[resource] = {"title": title, "name": labels[resource], "detail": detail, "progress": progress, "button": action, "repeat": repeat}

func _upgrade_job(planet: Dictionary, resource: String) -> Dictionary:
    for job in planet.get("queue", []):
        if job["kind"] == "production" and job["target"] == resource:
            return job
    return {}

func _upgrade_card_action(resource: String) -> void:
    var job: Dictionary = _upgrade_job(_planet(), resource)
    if job.is_empty():
        _operation("production", resource)
    else:
        session.call("request_cancel", selected, int(job["id"]))

func _refresh_upgrade_cards(planet: Dictionary, owned: bool) -> void:
    if planet.is_empty():
        return
    for resource in ECONOMY.RESOURCES:
        var card: Dictionary = upgrade_cards[resource]
        var level: int = int(planet["levels"][resource])
        card["title"].text = "%s  •  Lv %d" % [card["name"], level]
        var job: Dictionary = _upgrade_job(planet, resource)
        var button: Button = card["button"]
        var progress: ProgressBar = card["progress"]
        progress.visible = not job.is_empty()
        var detail: Label = card["detail"]
        var available: bool = not ECONOMY._continuous_target(planet, "production:" + resource).is_empty()
        _sync_repeat(card["repeat"], planet, "production:" + resource, owned and available)
        if not job.is_empty():
            progress.value = 100.0 * float(job["progress"]) / float(job["work"])
            detail.text = "%s%s" % [_cost_text(job["cost"], job["allocated"]), " • Waiting" if ECONOMY._possible(planet, job) <= ECONOMY.EPS else ""]
            button.text = "CANCEL / REFUND"
            button.disabled = not owned
        else:
            button.text = "UPGRADE TO LV %d" % (level + 1)
            button.disabled = not owned or not available or (planet["queue"] as Array).size() >= ECONOMY.MAX_QUEUE
            if not ECONOMY.ACTIVE_PRODUCTION.has(resource):
                detail.text = "Production design pending"
            elif not available:
                detail.text = "No local deposit"
            else:
                detail.text = "Output %.2f/yr\n%s · %.0f yr" % [ECONOMY.rate(planet, resource), _cost_text(ECONOMY._cost("production", level + 1)), ECONOMY._work("production", level + 1)]

func _build_cargo_rows(parent: Container, labels: Dictionary) -> void:
    for resource in ECONOMY.RESOURCES:
        var row := HBoxContainer.new()
        parent.add_child(row)
        var icon := TextureRect.new()
        icon.texture = HUD.ICONS[resource]
        icon.custom_minimum_size = Vector2(18, 18)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        row.add_child(icon)
        var title := _label(resource, 12)
        title.autowrap_mode = TextServer.AUTOWRAP_OFF
        title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(title)
        var amount := _label("0.0", 12)
        amount.autowrap_mode = TextServer.AUTOWRAP_OFF
        amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        amount.custom_minimum_size.x = 54
        amount.add_theme_color_override("font_color", HUD.COLORS[resource])
        row.add_child(amount)
        labels[resource] = amount

func _selected_ship(state: Dictionary) -> Dictionary:
    if selected_ship_id < 0:
        return {}
    for ship in state.get("ships", []):
        if int(ship["id"]) == selected_ship_id:
            return ship
    return {}

func _ship_kind_name(kind: String) -> String:
    return "Logistics ship" if kind == "ship" else ("Mining ship" if kind == "miner" else kind.replace("_", " ").capitalize())

func _ship_is_moving(ship: Dictionary) -> bool:
    return not (ship["route"] as Array).is_empty() or ship.get("mining_mode", "idle") in ["outbound", "return"]

func _remaining_years(state: Dictionary, ship: Dictionary) -> float:
    var points: Array = state["map"]["points"]
    var route: Array = ship["route"]
    var mode: String = ship.get("mining_mode", "idle")
    if mode in ["outbound", "return"]:
        var distance: float = (points[int(ship["at"])] as Vector2).distance_to(ship["mining_target"])
        return distance * (1.0 - float(ship["field_leg"]) if mode == "outbound" else float(ship["field_leg"])) / ECONOMY.SHIP_SPEED
    var path: Array[int] = [int(ship["at"])]
    for index in route:
        path.append(int(index))
    return maxf(0.0, MAP.route_length(state["map"], path) - float(ship["leg"])) / ECONOMY.SHIP_SPEED

func _apply_mining_policy() -> void:
    if selected_field >= 0:
        session.call("request_mining_policy", selected_field, mining_enabled.button_pressed, mining_metals.button_pressed, mining_crystals.button_pressed)

func _refresh_field_panels(state: Dictionary) -> void:
    var field: Dictionary = state["map"]["fields"][selected_field]
    ship_title.text = "Asteroid field %02d" % (selected_field + 1)
    var stock: Dictionary = ECONOMY.field_inventory(field)
    var total: float = float(stock["Metals"]) + float(stock["Crystals"])
    if total <= ECONOMY.EPS:
        ship_detail.text = "Depleted"
    else:
        var metals: int = roundi(100.0 * float(stock["Metals"]) / total)
        ship_detail.text = "Metals ~%d%% · %s\nCrystals ~%d%% · %s" % [metals, _compact_amount(float(stock["Metals"])), 100 - metals, _compact_amount(float(stock["Crystals"]))]
    ship_detail.tooltip_text = "%d chunks remaining · Service system %02d" % [field["chunks"].size(), int(field["anchor"]) + 1]
    ship_cargo.get_parent().hide()
    fleet_title.text = "Mining"
    fleet_detail.hide()
    fleet_cargo.get_parent().hide()
    mining_controls.get_parent().show()
    var policy: Dictionary = ECONOMY.mining_policy(state, _me(), selected_field)
    mining_enabled.set_pressed_no_signal(bool(policy["enabled"]))
    mining_metals.set_pressed_no_signal(bool(policy["Metals"]))
    mining_crystals.set_pressed_no_signal(bool(policy["Crystals"]))
    mining_metals.disabled = not mining_enabled.button_pressed
    mining_crystals.disabled = not mining_enabled.button_pressed

func _refresh_ship_panels(state: Dictionary, ship: Dictionary) -> void:
    mining_controls.get_parent().hide()
    var kind: String = ship.get("kind", "ship")
    var owner: int = int(ship["owner"])
    var roster: Dictionary = session.get("players")
    ship_title.text = "%s #%d" % [_ship_kind_name(kind), int(ship["id"])]
    var route: Array = ship["route"]
    var mode: String = ship.get("mining_mode", "idle")
    var status: String = "Orbiting system %02d" % (int(ship["at"]) + 1)
    if not route.is_empty():
        status = "System %02d → %02d\nETA %.1f yr" % [int(ship["at"]) + 1, int(route.back()) + 1, _remaining_years(state, ship)]
    elif mode in ["outbound", "return"]:
        status = ("To field" if mode == "outbound" else "Returning") + "\nETA %.1f yr" % _remaining_years(state, ship)
    elif mode == "mining":
        status = "Mining field %02d\n%.1f / 5 yr" % [int(ship["field"]) + 1, minf(5.0, float(ship.get("mining_years", 0.0)))]
    ship_detail.text = "%s\n%s" % [str(roster.get(owner, {}).get("name", "Player")), status]
    ship_detail.tooltip_text = ""
    var cargo_capable: bool = kind in ["ship", "miner"]
    ship_cargo.get_parent().visible = cargo_capable
    if cargo_capable:
        var cargo_capacity: float = ECONOMY.CARGO_CAPACITY if kind == "ship" else ECONOMY.MINER_CAPACITY
        ship_cargo.get_child(0).text = "Cargo %.1f / %.0f" % [ECONOMY._cargo_total(ship), cargo_capacity]
        for resource in ECONOMY.RESOURCES:
            ship_cargo_labels[resource].text = "%.1f" % float(ship["cargo"].get(resource, 0.0))
            ship_cargo_labels[resource].get_parent().visible = kind == "ship" or ECONOMY.MINED_RESOURCES.has(resource)
    fleet_title.text = {"ship": "Logistics", "fighter": "Military", "miner": "Mining", "colony_ship": "Colonization"}.get(kind, "Fleet")
    fleet_detail.visible = kind != "fighter"
    fleet_cargo.get_parent().visible = cargo_capable
    if kind == "fighter":
        return
    var total: int = 0
    var traveling: int = 0
    var working: int = 0
    var cargo: Dictionary = ECONOMY.empty_stock()
    for craft in state["ships"]:
        if int(craft["owner"]) != _me() or craft.get("kind", "ship") != kind:
            continue
        total += 1
        if _ship_is_moving(craft):
            traveling += 1
        elif craft.get("mining_mode", "idle") == "mining":
            working += 1
        for resource in ECONOMY.RESOURCES:
            cargo[resource] = float(cargo[resource]) + float(craft["cargo"].get(resource, 0.0))
    fleet_detail.text = "%d %s\n%d traveling · %d idle" % [total, "ship" if total == 1 else "ships", traveling, total - traveling - working]
    if kind == "miner":
        fleet_detail.text += "\n%d mining" % working
    fleet_detail.tooltip_text = "Your empire"
    if cargo_capable:
        for resource in ECONOMY.RESOURCES:
            var amount: float = float(cargo[resource])
            fleet_cargo_labels[resource].text = _compact_amount(amount) if amount >= 1000.0 else "%.1f" % amount
            fleet_cargo_labels[resource].tooltip_text = "%.1f" % amount
            fleet_cargo_labels[resource].get_parent().visible = kind == "ship" or ECONOMY.MINED_RESOURCES.has(resource)

func _build_global_bar(stats: Container) -> void:
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
        value.add_theme_font_size_override("font_size", 12)
        value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        value.add_theme_color_override("font_color", HUD.COLORS[resource])
        line.add_child(value)
        global_resource_labels[resource] = value
        global_resource_tiles[resource] = tile

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
    var rates: Dictionary = state.get("resource_rates", {}).get(_me(), {})
    for resource in ECONOMY.RESOURCES:
        var value: float = float(totals["resources"][resource])
        var rate: float = float(rates.get(resource, 0.0))
        var magnitude: String = "%.1f" % absf(rate) if absf(rate) < 1000.0 else _compact_amount(absf(rate))
        var rate_text: String = ("-" if rate < -0.05 else "+") + magnitude
        global_resource_labels[resource].text = "%s (%s)" % [_compact_amount(value), rate_text]
        global_resource_tiles[resource].tooltip_text = "%s: %.1f\nSystems: %.1f • Cargo: %.1f\nNet: %+.2f/year (last 5 years)" % [
            resource, value, float(totals["stock"][resource]), float(totals["cargo"][resource]), rate]
    global_population_label.text = "POP  %s" % _compact_amount(float(totals["population"]))
    global_population_label.tooltip_text = "Population across owned systems: %.0f" % float(totals["population"])

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

func _load_thresholds() -> void:
    var p: Dictionary = _planet()
    if p.is_empty():
        return
    for resource in ECONOMY.RESOURCES:
        var t: Dictionary = p["thresholds"][resource]
        var slider: TradeRange = trade_sliders[resource]
        slider.set_range(float(t["min"]), float(t["max"]))
    _update_trade_stock(p)

func _update_trade_stock(p: Dictionary) -> void:
    for resource in ECONOMY.RESOURCES:
        var slider: TradeRange = trade_sliders[resource]
        var stock: float = float(p["stock"][resource])
        slider.set_stock(stock, ECONOMY.TRADE_REFERENCE, HUD.COLORS[resource])
        trade_stock_labels[resource].text = "%.1f / %.0f" % [stock, ECONOMY.TRADE_REFERENCE]
        # Preserve this handle while dragging, even when a snapshot arrives.
        if slider.active_handle < 0:
            var t: Dictionary = p["thresholds"][resource]
            if not is_equal_approx(slider.lower, float(t["min"])) or not is_equal_approx(slider.upper, float(t["max"])):
                slider.set_range(float(t["min"]), float(t["max"]))

func _apply_thresholds(minimum: float, maximum: float, resource: String) -> void:
    session.call("request_thresholds", selected, resource, minimum, maximum)

func _operation(kind: String, target: String = "") -> void:
    session.call("request_operation", selected, kind, target)

func _cancel_job(id: int) -> void:
    session.call("request_cancel", selected, id)

func _refresh() -> void:
    if is_instance_valid(map_canvas):
        map_canvas.queue_redraw()
    if not is_instance_valid(year_label):
        return
    var state: Dictionary = _state()
    var phase: String = str(session.get("phase"))
    _refresh_global_bar(state)
    menu_exit.text = "Main menu" if bool(session.get("is_solo")) else ("Return to lobby" if multiplayer.is_server() else "Leave match")
    if phase == "loading" and multiplayer.is_server():
        menu_exit.text = "Cancel start"
    var planets: Array = state.get("planets", [])
    if not initial_selection_done and not planets.is_empty():
        initial_selection_done = true
        for i in range(planets.size()):
            if int(planets[i]["owner"]) == _me():
                selected = i
                _load_thresholds()
                break
    var ship: Dictionary = _selected_ship(state)
    if ship.is_empty():
        selected_ship_id = -1
    var p: Dictionary = _planet()
    var field_selected: bool = selected_field >= 0 and ECONOMY.discovered(state, _me(), "fields", selected_field)
    var ship_selected: bool = not ship.is_empty()
    var other_selected: bool = ship_selected or field_selected
    inspector_panel.visible = not p.is_empty() or other_selected
    overview_panel.visible = inspector_panel.visible
    planet_overview.visible = not other_selected
    inspector_tabs.visible = not other_selected
    ship_overview.visible = other_selected
    fleet_scroll.visible = other_selected
    fleet_overview.visible = other_selected
    if field_selected:
        _refresh_field_panels(state)
        return
    if ship_selected:
        _refresh_ship_panels(state, ship)
        return
    _refresh_yard_activity(p)
    var owned: bool = not p.is_empty() and int(p["owner"]) == _me() and phase == "match"
    _refresh_colony_choices(state, p, phase)
    var full: bool = (p.get("queue", []) as Array).size() >= ECONOMY.MAX_QUEUE
    for kind in continuous_checks:
        var check: Button = continuous_checks[kind]
        _sync_repeat(check, p, kind, owned and (kind != "ship" or bool(p.get("home", false))))
    queue_title.text = "Queue  %d/%d" % [(p.get("queue", []) as Array).size(), ECONOMY.MAX_QUEUE]
    colony_button.disabled = not owned or full
    for slider in trade_sliders.values():
        slider.enabled = owned
        if not owned:
            slider.active_handle = -1
        slider.queue_redraw()
    fighter_button.disabled = not owned or full
    miner_button.disabled = not owned or full
    ship_button.disabled = true
    yard_button.disabled = not owned or full
    if p.is_empty():
        info.text = "Select a system."
        population_label.text = ""
        resource_detail.text = ""
        _refresh_queue(p, false)
        inventory.hide()
        return
    var owner: int = int(p["owner"])
    var roster: Dictionary = session.get("players")
    var name_text: String = "Neutral" if owner == 0 else str(roster.get(owner, {}).get("name", "Player"))
    info.text = "System %02d%s\n%s" % [selected + 1, "  /  Home" if bool(p["home"]) else "", name_text]
    environment_label.text = _system_bonus_text(p)
    environment_label.visible = not environment_label.text.is_empty()
    environment_label.tooltip_text = "Natural production modifiers; advanced manufacturing is reserved for future recipes."
    for resource in ECONOMY.RESOURCES:
        production_values[resource]["level"].text = "Lv %d" % int(p["levels"][resource])
        var annual: float = ECONOMY.rate(p, resource)
        production_values[resource]["rate"].text = (_compact_amount(annual) if annual >= 1000.0 else "%.1f" % annual) + "/yr"
        production_values[resource]["rate"].tooltip_text = "%.2f/yr" % annual
    var population: float = float(p["population"])
    population_label.text = "Population %s\n%+.0f/yr" % [_compact_amount(population), ECONOMY.population_growth(p)]
    population_label.tooltip_text = "%.0f people" % population
    inventory.show()
    for r in ECONOMY.RESOURCES:
        stock_labels[r].text = "%.1f" % float(p["stock"][r])
        level_labels[r].text = str(int(p["levels"][r]))
    var resource: String = _resource()
    var detail: String = "Production rules not defined yet."
    if ECONOMY.EXTRACTED.has(resource):
        detail = "Production %.1f/yr" % ECONOMY.rate(p, resource)
    elif resource == "Organics":
        var output: float = ECONOMY.rate(p, resource)
        var demand: float = ECONOMY.organics_demand(p)
        detail = "Farming: %.2f/yr  •  Demand: %.2f/yr\nNet: %+.2f/yr" % [output, demand, output - demand]
    resource_detail.text = detail
    _update_trade_stock(p)
    _refresh_upgrade_cards(p, owned)
    ship_button.disabled = not owned or full or not bool(p["home"])
    _refresh_queue(p, owned)

func _upgrade_yard_at(index: int) -> void:
    if index >= 0:
        _operation("yard_upgrade", str(index))

func _refresh_yard_activity(p: Dictionary) -> void:
    var active: Dictionary = {}
    if not p.is_empty():
        var yards: Array = p["yards"]
        for i in range(yards.size()):
            var yard: Dictionary = yards[i]
            active[i] = {}
            for job in p["queue"]:
                if int(job["id"]) == int(yard["job"]):
                    active[i] = job
                    break
        for job in p["queue"]:
            if job["kind"] == "yard":
                active[-int(job["id"])] = job
    yard_activity.get_parent().visible = not active.is_empty()
    for index in yard_activity_rows.keys():
        if not active.has(index):
            var obsolete: Control = yard_activity_rows[index]["row"]
            yard_activity.remove_child(obsolete)
            obsolete.queue_free()
            yard_activity_rows.erase(index)
    var pending_number: int = (p.get("yards", []) as Array).size()
    for index in active:
        var job: Dictionary = active[index]
        var number: int = int(index) + 1
        if int(index) < 0:
            pending_number += 1
            number = pending_number
        if not yard_activity_rows.has(index):
            var row := VBoxContainer.new()
            var title := _label("", 12)
            row.add_child(title)
            var progress := ProgressBar.new()
            progress.custom_minimum_size.y = 16
            row.add_child(progress)
            var actions := HBoxContainer.new()
            row.add_child(actions)
            var upgrade: Button = _button("UPGRADE", _upgrade_yard_at.bind(int(index)), actions)
            upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            var repeat: Button = _repeat_button(actions, "yard_upgrade:" + str(index))
            upgrade.custom_minimum_size.y = 24
            upgrade.add_theme_font_size_override("font_size", 11)
            yard_activity.add_child(row)
            yard_activity_rows[index] = {"row": row, "label": title, "progress": progress, "upgrade": upgrade, "repeat": repeat}
        var label: Label = yard_activity_rows[index]["label"]
        var bar: ProgressBar = yard_activity_rows[index]["progress"]
        var upgrade: Button = yard_activity_rows[index]["upgrade"]
        var existing: bool = int(index) >= 0
        var level: int = int(p["yards"][index]["level"]) if existing else 1
        var pending: bool = existing and ECONOMY._has_job(p, "yard_upgrade", str(index))
        upgrade.visible = existing and int(p["owner"]) == _me()
        var repeat: Button = yard_activity_rows[index]["repeat"]
        repeat.visible = upgrade.visible
        _sync_repeat(repeat, p, "yard_upgrade:" + str(index), upgrade.visible and str(session.get("phase")) == "match")
        upgrade.disabled = not upgrade.visible or pending or (p["queue"] as Array).size() >= ECONOMY.MAX_QUEUE or str(session.get("phase")) != "match"
        upgrade.text = "UPGRADE QUEUED" if pending else "UPGRADE TO LV %d" % (level + 1)
        upgrade.tooltip_text = "Lv %d • %.0f Metals • %.0f years" % [level, float(ECONOMY._cost("yard_upgrade", level + 1)["Metals"]), ECONOMY._work("yard_upgrade", level + 1)]
        if job.is_empty():
            label.text = "Shipyard %d · Lv %d · Idle" % [number, level]
            bar.value = 0.0
            bar.show_percentage = false
            bar.tooltip_text = "Shipyard %d" % (int(index) + 1)
            continue
        bar.show_percentage = true
        var name_text: String = "Logistics ship" if job["kind"] == "ship" else str(job["kind"]).replace("_", " ").capitalize()
        if job["kind"] == "yard_upgrade":
            name_text = "Upgrade to Lv %d" % int(job["level"])
        elif job["kind"] == "yard":
            name_text = "Construction"
        label.text = "Shipyard %d · Lv %d · %s" % [number, level, name_text] if existing else "Shipyard %d · %s" % [number, name_text]
        bar.value = 100.0 * float(job["progress"]) / float(job["work"])
        bar.tooltip_text = "Waiting for materials" if ECONOMY._possible(p, job) <= ECONOMY.EPS else "Shipyard %d" % number

func _job_name(item: Dictionary) -> String:
    match str(item["kind"]):
        "ship": return "Logistics ship"
        "yard": return "New shipyard"
        "yard_upgrade": return "Shipyard %d → Lv %d" % [int(item["target"]) + 1, int(item["level"])]
        "production": return "%s → Lv %d" % [str(item["target"]), int(item["level"])]
        _: return str(item["kind"]).replace("_", " ").capitalize()

func _cost_text(cost: Dictionary, allocated: Dictionary = {}) -> String:
    var parts: PackedStringArray = []
    for resource in cost:
        if allocated.is_empty():
            parts.append("%.0f %s" % [float(cost[resource]), resource])
        else:
            parts.append("%.0f / %.0f %s" % [float(allocated.get(resource, 0.0)), float(cost[resource]), resource])
    return " · ".join(parts)

func _refresh_queue(p: Dictionary, owned: bool) -> void:
    var entries: Array = p.get("queue", [])
    var ids: Dictionary = {}
    for item in entries:
        ids[int(item["id"])] = true
    for id in queue_rows.keys():
        if not ids.has(id):
            var obsolete: Control = queue_rows[id]["row"]
            queue_list.remove_child(obsolete)
            obsolete.queue_free()
            queue_rows.erase(id)
    for item in entries:
        var id: int = int(item["id"])
        if not queue_rows.has(id):
            var row := VBoxContainer.new()
            var top := HBoxContainer.new()
            row.add_child(top)
            var name_label := _label("", 12)
            name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            top.add_child(name_label)
            var cancel: Button = _button("×", _cancel_job.bind(id), top)
            cancel.custom_minimum_size = Vector2(28, 24)
            cancel.tooltip_text = "Cancel and refund allocated materials"
            HUD.action(cancel, Color("#e9a276"))
            var progress := ProgressBar.new()
            progress.custom_minimum_size.y = 15
            row.add_child(progress)
            var cost_label := _label("", 11)
            cost_label.add_theme_color_override("font_color", HUD.MUTED)
            row.add_child(cost_label)
            queue_list.add_child(row)
            queue_rows[id] = {"row": row, "title": name_label, "cancel": cancel, "progress": progress, "cost": cost_label}
        var card: Dictionary = queue_rows[id]
        card["title"].text = _job_name(item)
        card["cancel"].disabled = not owned
        card["progress"].value = 100.0 * float(item["progress"]) / float(item["work"])
        card["cost"].text = _cost_text(item["cost"], item["allocated"])
        var blocked: bool = ECONOMY._possible(p, item) <= ECONOMY.EPS
        card["progress"].tooltip_text = "Waiting for materials" if blocked else ""
        card["cost"].add_theme_color_override("font_color", Color("#e9a276") if blocked else HUD.MUTED)

func _open_menu() -> void:
    drag_button = 0
    match_menu.popup_centered(Vector2i(330, 100))

func _menu_action(action: StringName) -> void:
    if action == &"leave":
        match_menu.hide()
        _leave()

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
                labels.append("Colony ship #%d • System %02d" % [int(ship["id"]), int(ship["at"]) + 1])
    if choices != colony_choices or colony_picker.item_count == 0:
        var previous: int = -1
        if colony_picker.selected >= 0 and colony_picker.selected < colony_choices.size():
            previous = colony_choices[colony_picker.selected]
        colony_choices = choices
        colony_picker.clear()
        for label_text in labels:
            colony_picker.add_item(label_text)
        if choices.is_empty():
            colony_picker.add_item("No available colony ships")
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

# Fixed reference viewport: opening or closing the inspector only changes clipping.
func _projection_size() -> Vector2:
    return Vector2(maxf(1.0, size.x - PANEL_WIDTH - OVERVIEW_WIDTH - 32.0), map_canvas.size.y)

func _map_size() -> Vector2:
    return _state().get("map", {}).get("size", MAP.SIZE)

func _fit() -> float:
    var area: Vector2 = _projection_size() - Vector2(24, 52)
    var bounds: Vector2 = _map_size()
    return maxf(0.0001, minf(area.x / bounds.x, area.y / bounds.y))

func _screen_point(point: Vector2) -> Vector2:
    return Vector2(OVERVIEW_WIDTH + 8.0, 0.0) + _projection_size() * 0.5 + pan + (point - _map_size() * 0.5) * _fit() * zoom

func _world_point(point: Vector2) -> Vector2:
    return _map_size() * 0.5 + (point - Vector2(OVERVIEW_WIDTH + 8.0, 0.0) - _projection_size() * 0.5 - pan) / (_fit() * zoom)

func _zoom_at(point: Vector2, multiplier: float) -> void:
    var world: Vector2 = _world_point(point)
    zoom = clampf(zoom * multiplier, MIN_ZOOM, MAX_ZOOM)
    pan += point - _screen_point(world)
    map_canvas.queue_redraw()

func _system_visual(index: int, state: Dictionary) -> Dictionary:
    var seed_value: int = int(state["map"]["seed"])
    if system_visual_seed != seed_value:
        system_visual_seed = seed_value
        system_visuals.clear()
    if not system_visuals.has(index):
        var points: Array = state["map"]["points"]
        var closest: float = INF
        for i in range(points.size()):
            if i != index:
                closest = minf(closest, (points[index] as Vector2).distance_to(points[i]))
        system_visuals[index] = {"bodies": ECONOMY.system_bodies(state["planets"][index], seed_value, index), "spacing": closest}
    return system_visuals[index]

func _planet_radius(index: int, state: Dictionary) -> float:
    var system: Dictionary = state["planets"][index]
    var ideal: float = RADIUS * float(system.get("size_factor", 1.0)) * zoom
    var spacing: float = float(_system_visual(index, state)["spacing"]) * _fit() * zoom
    return clampf(minf(ideal, spacing * 0.39), 4.0, 720.0)

func _body_position(body: Dictionary, radius: float, time: float) -> Vector2:
    return Vector2.from_angle(float(body["phase"]) + time * float(body["speed"]) * 0.22) * radius * float(body["orbit"])

# Generate a unique shaded surface once per visible body; no separate highlight dot.
func _body_texture(body: Dictionary) -> Texture2D:
    if body.has("texture"):
        return body["texture"]
    var noise := FastNoiseLite.new()
    noise.seed = int(body["surface_seed"])
    noise.frequency = 0.065
    noise.fractal_octaves = 3
    var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
    var material: String = body["resource"]
    var base: Color = HUD.COLORS.get(material, Color("#7d8b9b"))
    base = base.lerp(Color("#7b8790"), float(body["muted"]))
    var light := Vector3(-0.55, -0.45, 0.70).normalized()
    var angle: float = float(body["surface_angle"])
    var bands: bool = bool(body["bands"])
    for y in range(96):
        for x in range(96):
            var q := (Vector2(x + 0.5, y + 0.5) - Vector2(48, 48)) / 47.0
            var rr: float = q.length_squared()
            if rr >= 1.0:
                continue
            var z: float = sqrt(1.0 - rr)
            var uv: Vector2 = q.rotated(angle)
            var grain: float = noise.get_noise_2d(uv.x * 90.0 + 300.0 * z, uv.y * 90.0)
            var terrain: float = grain * 0.7
            if bands:
                terrain = sin(uv.y * 29.0 + grain * 2.0) * 0.24 + grain * 0.2
            var diffuse: float = maxf(0.0, Vector3(q.x, q.y, z).dot(light))
            var color: Color = base.lerp(Color("#d6e1e9"), maxf(0.0, terrain) * 0.7).darkened(clampf(0.74 - diffuse * 0.64 - terrain * 0.18, 0.0, 0.85))
            color.a = clampf((1.0 - sqrt(rr)) * 47.0, 0.0, 1.0)
            image.set_pixel(x, y, color)
    body["texture"] = ImageTexture.create_from_image(image)
    return body["texture"]

func _draw_system(index: int, state: Dictionary, pos: Vector2, radius: float, tint: Color) -> void:
    if not get_viewport_rect().grow(radius + 32.0).has_point(pos):
        return
    var system: Dictionary = state["planets"][index]
    var color: Color = _planet_color(system)
    var star_radius: float = maxf(3.0, radius * 0.13) if zoom >= 2.0 and radius >= 18.0 else radius * 0.48
    var star_color: Color = Color("#fff0c4").lerp(color.lightened(0.25), 0.30)
    if zoom >= 2.0 and radius >= 18.0:
        for body in _system_visual(index, state)["bodies"]:
            var orbit: float = radius * float(body["orbit"])
            map_canvas.draw_arc(pos, orbit, 0.0, TAU, 48, Color(tint, 0.24), 0.8, true)
            var point: Vector2 = pos + _body_position(body, radius, visual_clock)
            var body_radius: float = maxf(2.1, radius * float(body["size"]))
            if get_viewport_rect().grow(body_radius).has_point(point):
                if body_radius >= 5.0:
                    map_canvas.draw_texture_rect(_body_texture(body), Rect2(point - Vector2.ONE * body_radius, Vector2.ONE * body_radius * 2.0), false)
                else:
                    map_canvas.draw_circle(point, body_radius, HUD.COLORS.get(body["resource"], Color("#7d8b9b")).darkened(0.18), true)
    var pulse: float = 0.96 + 0.04 * sin(visual_clock * 1.2 + float(index))
    for layer in range(5, 0, -1):
        map_canvas.draw_circle(pos, star_radius * (1.0 + float(layer) * 0.33) * pulse, Color(star_color, 0.05), true)
    map_canvas.draw_circle(pos, star_radius * pulse, star_color, true)
    map_canvas.draw_circle(pos, star_radius * 0.55 * pulse, Color("#fffdf1"), true)
    map_canvas.draw_arc(pos, radius + 1.5, 0.0, TAU, 48, Color(tint, 0.65), 1.5, true)

func _planet_color(planet: Dictionary) -> Color:
    var sum := Vector3.ZERO
    var weight: float = 0.0
    for resource in ECONOMY.EXTRACTED:
        var amount: float = float(planet["abundance"].get(resource, 0.0))
        var tint: Color = HUD.COLORS[resource]
        sum += Vector3(tint.r, tint.g, tint.b) * amount
        weight += amount
    var organic: float = maxf(0.0, float(planet["bonuses"].get("Organics", 1.0)) - 1.0)
    var green: Color = HUD.COLORS["Organics"]
    sum += Vector3(green.r, green.g, green.b) * organic
    weight += organic
    if weight <= ECONOMY.EPS:
        return Color("#617587")
    var mix: Vector3 = sum / weight
    return Color(mix.x, mix.y, mix.z)

func _select_at(point: Vector2) -> void:
    var state: Dictionary = _state()
    if state.is_empty() or str(session.get("phase")) != "match":
        return
    var points: Array = state["map"]["points"]
    var nearest: float = INF
    var hit: int = -1
    for i in range(points.size()):
        if not ECONOMY.discovered(state, _me(), "planets", i):
            continue
        var distance: float = point.distance_to(_screen_point(points[i]))
        if distance <= _planet_radius(i, state) + 4.0 and distance < nearest:
            nearest = distance
            hit = i
    # Use the same rendered pose (including orbital offsets) for hit testing.
    var poses: Dictionary = _ship_poses(state)
    var ship_hit: int = -1
    var ship_distance: float = INF
    for id in poses:
        var distance: float = point.distance_to(poses[id]["point"])
        if distance <= 12.0 and distance < ship_distance:
            ship_distance = distance
            ship_hit = int(id)
    selected_ship_id = ship_hit if hit < 0 or nearest > 5.0 or ship_distance < nearest else -1
    selected_field = -1
    if selected_ship_id < 0 and hit < 0:
        var fields: Array = state["map"].get("fields", [])
        for i in range(fields.size()):
            if not ECONOMY.discovered(state, _me(), "fields", i):
                continue
            var distance: float = point.distance_to(_screen_point(fields[i]["position"]))
            if distance <= maxf(9.0, float(fields[i]["radius"]) * _fit() * zoom):
                selected_field = i
                break
    selected = -1 if selected_ship_id >= 0 or selected_field >= 0 else hit
    var focused: Control = get_viewport().gui_get_focus_owner()
    if is_instance_valid(focused):
        focused.release_focus()
    if selected >= 0:
        _load_thresholds()
    _refresh()

func _map_input(event: InputEvent) -> void:
    if match_menu.visible:
        return
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
    if ship.get("kind", "ship") == "miner" and ship.get("mining_mode", "idle") in ["outbound", "mining", "return"]:
        return pos.lerp(ship["mining_target"], float(ship["field_leg"]))
    if not route.is_empty():
        var next: Vector2 = points[int(route[0])]
        pos = pos.lerp(next, clampf(float(ship["leg"]) / maxf(1.0, pos.distance_to(next)), 0.0, 1.0))
    return pos

func _visual_position(visual: Dictionary) -> Vector2:
    return (visual["from"] as Vector2).lerp(visual["to"], clampf(float(visual["age"]) / SNAPSHOT_SECONDS, 0.0, 1.0))

# React to accepted orders in authority snapshots, not speculative UI clicks.
# Only local system-production orders play audio; initial state is silent.
func _sync_upgrade_audio(state: Dictionary) -> void:
    if state.is_empty() or str(session.get("phase")) != "match":
        return
    var active: Dictionary = {}
    var added: bool = false
    for system in state.get("planets", []):
        if int(system["owner"]) != _me():
            continue
        for job in system["queue"]:
            if job["kind"] != "production":
                continue
            var id: int = int(job["id"])
            active[id] = true
            if not known_upgrade_jobs.has(id):
                added = true
    if upgrade_audio_initialized and added:
        upgrade_audio.play()
    known_upgrade_jobs = active
    upgrade_audio_initialized = true

func _on_economy_changed() -> void:
    var state: Dictionary = _state()
    _sync_upgrade_audio(state)
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
    if str(session.get("phase")) != "match" or match_menu.visible:
        return
    if not get_window().has_focus():
        return
    var focus: Control = get_viewport().gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit:
        return
    for picker in [resource_picker, colony_picker]:
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

func _orbit_offset(slot: int, radius: float, time: float) -> Vector2:
    var ring: int = floori(float(slot) / 8.0)
    var angle: float = TAU * float(slot % 8) / 8.0 + time * (0.48 / (1.0 + float(ring) * 0.2)) + float(ring) * 0.35
    return Vector2.from_angle(angle) * (radius + 12.0 + float(ring) * 13.0)

func _orbit_direction(offset: Vector2) -> Vector2:
    return Vector2(-offset.y, offset.x).normalized()

func _ship_poses(state: Dictionary) -> Dictionary:
    var points: Array = state["map"]["points"]
    var docked: Dictionary = {}
    var poses: Dictionary = {}

    for ship in state["ships"]:
        var at: int = int(ship["at"])
        if int(ship["owner"]) != _me() and not ECONOMY.discovered(state, _me(), "planets", at):
            continue
        var route: Array = ship["route"]
        var visual: Dictionary = ship_visuals.get(int(ship["id"]), {})
        var pos: Vector2 = _ship_position(ship, points) if visual.is_empty() else _visual_position(visual)
        var direction: Vector2 = Vector2.UP
        var point: Vector2 = _screen_point(pos)
        var mining: bool = ship.get("kind", "ship") == "miner" and ship.get("mining_mode", "idle") in ["outbound", "mining", "return"]
        if mining:
            direction = ((ship["mining_target"] as Vector2) - (points[at] as Vector2)).normalized()
            if ship["mining_mode"] == "return":
                direction = -direction
            if ship["mining_mode"] == "mining":
                var mining_offset: Vector2 = Vector2.from_angle(float(int(ship["id"])) * 2.399963 + visual_clock * 0.3) * 6.0
                point += mining_offset
                direction = _orbit_direction(mining_offset)
        elif route.is_empty():
            # Idle craft orbit visually; logistics positions remain authoritative planet nodes.
            var slot: int = int(docked.get(at, 0))
            docked[at] = slot + 1
            var offset: Vector2 = _orbit_offset(slot, _planet_radius(at, state), visual_clock)
            direction = _orbit_direction(offset)
            point += offset
        else:
            var next: Vector2 = points[int(route[0])]
            direction = (next - (points[at] as Vector2)).normalized()
            point += direction.orthogonal() * (5.0 + float(int(ship["id"]) % 5) * 4.0)
        poses[int(ship["id"])] = {"point": point, "direction": direction, "mining": mining}
    return poses

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
        var known: bool = ECONOMY.discovered(state, _me(), "planets", a) and ECONOMY.discovered(state, _me(), "planets", b)
        var color: Color = COLORS[teams[a]].darkened(0.3) if known and teams[a] > 0 and teams[a] == teams[b] else Color("#40566b")
        var a_pos: Vector2 = _screen_point(points[a])
        var b_pos: Vector2 = _screen_point(points[b])
        map_canvas.draw_line(a_pos, b_pos, Color(color, 0.10), 7.0, true)
        map_canvas.draw_line(a_pos, b_pos, Color(color, 0.78), 1.5, true)
    var font: Font = ThemeDB.fallback_font
    var fields: Array = state["map"].get("fields", [])
    for field_index in range(fields.size()):
        var field: Dictionary = fields[field_index]
        var center: Vector2 = _screen_point(field["position"])
        if not ECONOMY.discovered(state, _me(), "fields", field_index):
            map_canvas.draw_string(font, center + Vector2(-10, 5), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, HUD.MUTED)
            continue
        var boundary := PackedVector2Array()
        for vertex in field["outline"]:
            boundary.append(_screen_point(vertex))
        if not boundary.is_empty():
            map_canvas.draw_colored_polygon(boundary, Color("#7b796512"))
            boundary.append(boundary[0])
            map_canvas.draw_polyline(boundary, HUD.ACCENT if selected_field == field_index else Color("#b9ac7740"), 1.5, true)
        for chunk in field["chunks"]:
            var rock_pos: Vector2 = _screen_point(chunk["position"])
            var fraction: float = float(chunk["remaining"]) / float(chunk["initial"])
            var rock_radius: float = maxf(1.3, float(chunk["radius"]) * _fit() * zoom * sqrt(fraction))
            var rock := PackedVector2Array()
            for k in range(chunk["shape"].size()):
                var angle: float = TAU * float(k) / float(chunk["shape"].size()) + float(chunk["rotation"])
                rock.append(rock_pos + Vector2.from_angle(angle) * rock_radius * float(chunk["shape"][k]))
            var tint: Color = HUD.COLORS[chunk["resource"]]
            map_canvas.draw_colored_polygon(rock, tint.darkened(0.25))
            rock.append(rock[0])
            map_canvas.draw_polyline(rock, tint, 0.8, true)
    for i in range(points.size()):
        var pos: Vector2 = _screen_point(points[i])
        if not ECONOMY.discovered(state, _me(), "planets", i):
            map_canvas.draw_string(font, pos + Vector2(-10, 5), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, HUD.MUTED)
            continue
        var radius: float = _planet_radius(i, state)
        var tint: Color = COLORS[teams[i]]
        _draw_system(i, state, pos, radius, tint)
        if bool(state["planets"][i]["home"]):
            map_canvas.draw_arc(pos, radius + 5.0, 0.0, TAU, 48, Color(tint, 0.5), 1.0, true)
        if i == selected:
            var phase: float = 0.6 + 0.35 * sin(visual_clock * 3.0)
            for angle in range(4):
                var start: float = float(angle) * TAU / 4.0 + 0.1
                map_canvas.draw_arc(pos, radius + 8.0, start, start + 1.15, 14, Color(HUD.ACCENT, phase), 2.0, true)
        if i == selected:
            map_canvas.draw_string(font, pos + Vector2(-20, -radius - 8), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 40, 11, Color("#f4faff"))
    var poses: Dictionary = _ship_poses(state)
    for ship in state["ships"]:
        if not poses.has(int(ship["id"])):
            continue
        var pose: Dictionary = poses[int(ship["id"])]
        var point: Vector2 = pose["point"]
        var direction: Vector2 = pose["direction"]
        var mining: bool = pose["mining"]
        var route: Array = ship["route"]
        var team: int = int(state["teams"].get(int(ship["owner"]), 0))
        var loaded: bool = ECONOMY._cargo_total(ship) > ECONOMY.EPS
        var hull: Color = COLORS[team].lightened(0.35) if not loaded else Color("#f8df8c")
        var colony: bool = ship.get("kind", "ship") == "colony_ship"
        var fighter: bool = ship.get("kind", "ship") == "fighter"
        if colony:
            hull = Color("#c7a4ff")
        elif fighter:
            hull = Color("#f2b57e")
        elif ship.get("kind", "ship") == "miner":
            hull = Color("#d8e58b")
        var side: Vector2 = direction.orthogonal()
        var shape := PackedVector2Array([point + direction * 9, point - direction * 6 + side * 5,
            point - direction * 3, point - direction * 6 - side * 5])
        if colony:
            shape = PackedVector2Array([point + direction * 12, point + side * 7, point - direction * 9, point - side * 7])
        if fighter:
            shape = PackedVector2Array([point + direction * 12, point - direction * 7 + side * 8, point - direction * 3, point - direction * 7 - side * 8])
        if ship.get("kind", "ship") == "miner":
            shape = PackedVector2Array([point + direction * 8 + side * 4, point + direction * 8 - side * 4, point - direction * 6 - side * 7, point - direction * 6 + side * 7])
        if not route.is_empty() or fighter or mining:
            var engine: Vector2 = point - direction * 9.0
            map_canvas.draw_circle(engine, 5.0, Color("#43a5ff30"), true)
            map_canvas.draw_line(engine, engine - direction * (5.0 + 2.0 * sin(visual_clock * 9.0)), Color("#79dfff"), 2.0, true)
        if int(ship["id"]) == selected_ship_id:
            map_canvas.draw_arc(point, 15.0, 0.0, TAU, 32, HUD.ACCENT, 2.0, true)
        map_canvas.draw_colored_polygon(shape, hull)
        var outline: PackedVector2Array = shape.duplicate()
        outline.append(shape[0])
        map_canvas.draw_polyline(outline, Color("#08111b"), 1.5, true)

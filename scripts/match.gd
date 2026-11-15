extends Control
## Planet map and inspector. Host/solo session owns all simulation mutations.
const MAP = preload("res://scripts/planet_map.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const BACKDROP = preload("res://scripts/space_background.gd")
const PLANET = preload("res://assets/ui/planet.svg")
const UPGRADE_SOUND = preload("res://assets/sfx/detail.wav")
const ECONOMY = preload("res://scripts/economy_rules.gd")
const RULES = preload("res://scripts/lobby_rules.gd")
const COLORS = RULES.EMPIRE_COLORS
const PANEL_WIDTH: float = 368.0
const OVERVIEW_WIDTH: float = 316.0
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
var territory_layer: Control
var territory_image: ColorRect
var territory_material: ShaderMaterial
var territory_sites: ImageTexture
var territory_site_count: int = 0
var territory_radius: float = 1.0
var territory_last: Array[int] = []
var territory_seed: int = -1
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
var ship_offsets: Dictionary = {}
const SHIP_WORLD_SCALE: float = 3.0
var interaction_panel: VBoxContainer
var military_lens: Button
var logistics_lens: Button
var active_lens: String = ""
var military_drag: int = -1
var military_drag_weights: Dictionary = {}
var military_preview: Dictionary = {}
var global_resource_fills: Dictionary = {}
var colony_picker: OptionButton
var send_colony_button: Button
var colony_button: Button
var colony_choices: Array[int] = []
var selected: int = -1
var last_system_tab_selection: int = -1
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
var time_buttons: Dictionary = {}
var game_visual_clock: float = 0.0
var info: Label
var visual_clock: float = 0.0
var system_visuals: Dictionary = {}
var system_visual_seed: int = -1
var trade_sliders: Dictionary = {}
var trade_stock_labels: Dictionary = {}
var upgrade_cards: Dictionary = {}
var economy_cards: Dictionary = {}
var warehouse_card: Dictionary = {}
var continuous_checks: Dictionary = {}
var repeat_icon: Texture2D
var production_summary: VBoxContainer
var production_values: Dictionary = {}
var fighter_button: Button
var miner_button: Button
var system_owner_label: Label
var ship_button: Button
var leave: Button
var match_menu: AcceptDialog
var menu_exit: Button
var build_cards: Dictionary = {}

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
    _build_territory_layer()
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
    _build_lens_buttons()
    match_menu = AcceptDialog.new()
    match_menu.title = "Menu"
    match_menu.theme = theme
    match_menu.exclusive = true
    match_menu.unresizable = true
    match_menu.ok_button_text = "Resume"
    add_child(match_menu)
    menu_exit = match_menu.add_button("Leave match", false, "leave")
    HUD.action(match_menu.get_ok_button())
    HUD.action(menu_exit, Color("#e9a276"))
    match_menu.custom_action.connect(_menu_action)
    inspector_panel = PanelContainer.new()
    add_child(inspector_panel)
    inspector_panel.anchor_left = 1.0
    inspector_panel.anchor_right = 1.0
    inspector_panel.anchor_bottom = 1.0
    inspector_panel.offset_left = -PANEL_WIDTH
    inspector_panel.offset_right = -8
    inspector_panel.offset_top = HEADER_HEIGHT + 16
    inspector_panel.offset_bottom = -52
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 8)
    inspector_panel.add_child(body)
    overview_panel = PanelContainer.new()
    add_child(overview_panel)
    overview_panel.anchor_bottom = 1.0
    overview_panel.offset_left = 8
    overview_panel.offset_right = OVERVIEW_WIDTH + 8
    overview_panel.offset_top = HEADER_HEIGHT + 16
    overview_panel.offset_bottom = -52
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
    var system_header := HBoxContainer.new()
    planet_overview.add_child(system_header)
    info = _label("", 16)
    info.clip_text = true
    info.autowrap_mode = TextServer.AUTOWRAP_OFF
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    system_header.add_child(info)
    system_owner_label = _label("", 11)
    system_owner_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    system_owner_label.clip_text = true
    system_owner_label.custom_minimum_size.x = 90
    system_owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    system_header.add_child(system_owner_label)
    population_label = _label("", 13)
    planet_overview.add_child(population_label)
    production_summary = HUD.section(planet_overview, "Resources")
    _build_production_summary()
    interaction_panel = VBoxContainer.new()
    interaction_panel.add_theme_constant_override("separation", 8)
    body.add_child(interaction_panel)
    colony_picker = OptionButton.new()
    interaction_panel.add_child(colony_picker)
    send_colony_button = _button("SEND COLONY SHIP", _send_colony, interaction_panel)
    HUD.action(send_colony_button, Color("#c7a4ff"))
    yard_activity = HUD.section(planet_overview, "Shipyards")
    inspector_tabs = TabContainer.new()
    inspector_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    inspector_tabs.clip_contents = true
    body.add_child(inspector_tabs)
    var shipyard_page: VBoxContainer = _inspector_page("Shipyards")
    var economy_page: VBoxContainer = _inspector_page("Economy")
    _build_economy_cards(economy_page)
    var trade_page: VBoxContainer = _inspector_page("Trade")
    var upgrades_page: VBoxContainer = _inspector_page("Upgrades")
    _build_upgrade_cards(upgrades_page)
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
        name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_label.add_theme_color_override("font_color", HUD.COLORS[resource])
        trade_row.add_child(name_label)
        var stock_label := _label("", 12)
        stock_label.autowrap_mode = TextServer.AUTOWRAP_OFF
        stock_label.custom_minimum_size.x = 88
        stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
    fighter_button.tooltip_text = "Assign fighters to points of interest using the military lens."
    miner_button = _ship_build_row(shipyards, "BUILD MINING SHIP", "miner")
    HUD.action(miner_button, Color("#d8e58b"))
    miner_button.tooltip_text = "Automatically mines accessible fields from owned service systems."
    _build_time_controls()


func _make_disclosure(parent: Container, title_text: String) -> Dictionary:
    var header := Button.new()
    header.alignment = HORIZONTAL_ALIGNMENT_LEFT
    header.custom_minimum_size.y = 28
    header.add_theme_font_size_override("font_size", 12)
    parent.add_child(header)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 4)
    parent.add_child(body)
    body.hide()
    header.set_meta("caption", title_text)
    header.text = "▸ " + title_text
    header.pressed.connect(func() -> void:
        body.visible = not body.visible
        header.text = ("▾ " if body.visible else "▸ ") + str(header.get_meta("caption")))
    return {"header": header, "body": body}

func _disclosure_title(card: Dictionary, caption: String) -> void:
    var header: Button = card["header"]
    header.set_meta("caption", caption)
    header.text = ("▾ " if card["body"].visible else "▸ ") + caption

func _collapse_card(card: Dictionary) -> void:
    if card.has("body"):
        card["body"].hide()
        _disclosure_title(card, str(card["header"].get_meta("caption")))

func _style_progress(bar: ProgressBar, p: Dictionary, job: Dictionary) -> void:
    var blocked: Array[String] = [] if job.is_empty() else ECONOMY.construction_blockers(p, job)
    bar.set_meta("blocked", not blocked.is_empty())
    if blocked.is_empty():
        bar.remove_theme_stylebox_override("fill")
        bar.remove_theme_stylebox_override("background")
    else:
        bar.add_theme_stylebox_override("background", HUD.surface(Color("#33251a"), Color("#db9b54"), 0, 3))
        bar.add_theme_stylebox_override("fill", HUD.surface(Color("#b56b35"), Color("#f2b57e"), 0, 3))
        bar.tooltip_text = "Blocked: " + ", ".join(blocked)

func _cost_grid(parent: Container) -> GridContainer:
    var grid := GridContainer.new()
    grid.columns = 3
    parent.add_child(grid)
    return grid

func _show_cost(grid: GridContainer, cost: Dictionary, crew: float = 0.0) -> void:
    var signature: Array = [cost, crew]
    if grid.get_meta("recipe", []) == signature:
        return
    grid.set_meta("recipe", signature.duplicate(true))
    for child in grid.get_children():
        grid.remove_child(child)
        child.queue_free()
    var entries: Dictionary = cost.duplicate()
    if crew > 0.0:
        entries["Population"] = crew
    for resource in entries:
        var pair := HBoxContainer.new()
        pair.add_theme_constant_override("separation", 3)
        grid.add_child(pair)
        var symbol := TextureRect.new()
        if resource == "Population":
            var image := Image.new()
            image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="#b9d9ed"><circle cx="12" cy="6" r="4"/><path d="M4 22v-4a8 8 0 0 1 16 0v4z"/></svg>')
            symbol.texture = ImageTexture.create_from_image(image)
        else:
            symbol.texture = HUD.ICONS[resource]
        symbol.custom_minimum_size = Vector2(14, 14)
        symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        pair.add_child(symbol)
        var value: float = float(entries[resource])
        var amount := _label(_compact_amount(value) if value >= 1000.0 else "%.0f" % value, 11)
        amount.autowrap_mode = TextServer.AUTOWRAP_OFF
        pair.add_child(amount)
        pair.tooltip_text = "%.0f %s" % [value, resource]

func _ship_stats(kind: String) -> String:
    var details: String = ""
    match kind:
        "ship": details = "Transports resources · Cargo %.0f" % ECONOMY.CARGO_CAPACITY
        "colony_ship": details = "Settles a neutral system · %.0f settlers" % ECONOMY.COLONY_POPULATION
        "fighter": details = "Engages hostile ships · Damage %.0f · Range %.0f" % [ECONOMY.LASER_DAMAGE, ECONOMY.LASER_RANGE]
        "miner": details = "Extracts asteroids · Cargo %.0f · Mining %.0f/yr" % [ECONOMY.MINER_CAPACITY, ECONOMY.MINER_RATE]
    return "%s\nHP %.0f · Speed %.0f/yr · Size %d\nBuild work %.0f" % [details, ECONOMY.SHIP_HP, ECONOMY.SHIP_SPEED, ECONOMY.SHIP_SIZE, ECONOMY._work(kind, 1)]

func _ship_build_row(parent: Container, title_text: String, kind: String) -> Button:
    var section: VBoxContainer = HUD.section(parent, "")
    section.get_child(0).hide()
    var disclosure: Dictionary = _make_disclosure(section, title_text.trim_prefix("BUILD ").capitalize())
    var body: VBoxContainer = disclosure["body"]
    var build_progress := ProgressBar.new()
    build_progress.custom_minimum_size.y = 12
    section.add_child(build_progress)
    section.move_child(build_progress, body.get_index())
    build_progress.hide()
    body.add_child(_label(_ship_stats(kind), 12))
    var requirements := _label("", 12)
    body.add_child(requirements)
    var costs: GridContainer = _cost_grid(body)
    _show_cost(costs, ECONOMY._cost(kind, 1), float(ECONOMY.CREW_COSTS[kind]))
    var row := HBoxContainer.new()
    body.add_child(row)
    var button: Button = _button(title_text, _operation.bind(kind), row)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if kind != "yard":
        var check: Button = _repeat_button(row, kind)
        continuous_checks[kind] = check
    var cancel: Button = _button("×", _cancel_kind.bind(kind, ""), row)
    cancel.custom_minimum_size.x = 26
    cancel.tooltip_text = "Cancel one order and stop repeat"
    disclosure.merge({"button": button, "cancel": cancel, "title": title_text, "requirements": requirements, "costs": costs, "build_progress": build_progress})
    build_cards[kind] = disclosure
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
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 3)
    production_summary.add_child(header)
    var blank := Control.new()
    blank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(blank)
    for column in [["Stock", 49], ["Lv", 22], ["/yr", 44], ["Bonus", 46]]:
        var title_label := _label(str(column[0]), 10)
        title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
        title_label.custom_minimum_size.x = float(column[1])
        title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        title_label.add_theme_color_override("font_color", HUD.MUTED)
        header.add_child(title_label)
    for resource in ECONOMY.RESOURCES:
        var row := HBoxContainer.new()
        production_summary.add_child(row)
        row.add_theme_constant_override("separation", 3)
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
        var stock := _label("", 11)
        stock.autowrap_mode = TextServer.AUTOWRAP_OFF
        stock.custom_minimum_size.x = 49
        stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(stock)
        var level := _label("", 11)
        level.autowrap_mode = TextServer.AUTOWRAP_OFF
        level.custom_minimum_size.x = 22
        level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(level)
        var rate_label := _label("", 11)
        rate_label.autowrap_mode = TextServer.AUTOWRAP_OFF
        rate_label.custom_minimum_size.x = 44
        rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(rate_label)
        var bonus := _label("", 11)
        bonus.autowrap_mode = TextServer.AUTOWRAP_OFF
        bonus.custom_minimum_size.x = 46
        bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(bonus)
        production_values[resource] = {"stock": stock, "level": level, "rate": rate_label, "bonus": bonus}

func _system_bonus_text(p: Dictionary) -> String:
    var lines: PackedStringArray = []
    var names: Dictionary = {"Metals": "Metal production", "Plastics": "Plastic production", "Crystals": "Crystal production", "Organics": "Organics production", "Tech": "Tech production", "Textiles": "Textile production"}
    for resource in ECONOMY.ACTIVE_PRODUCTION:
        var percent: int = roundi(ECONOMY.production_modifier(p, resource) * 100.0)
        if percent != 100:
            lines.append("%s %d%%" % [names[resource], percent])
    var advanced: int = roundi(float(p.get("advanced_bonus", 1.0)) * 100.0)
    if advanced != 100:
        lines.append("Advanced manufacturing %d%% (future)" % advanced)
    return "\n".join(lines)

func _build_economy_cards(parent: Container) -> void:
    var warehouse_section: VBoxContainer = HUD.section(parent, "")
    warehouse_section.get_child(0).hide()
    warehouse_card = _make_disclosure(warehouse_section, "Warehouse logistics")
    var warehouse: VBoxContainer = warehouse_card["body"]
    var warehouse_detail: Label = _label("", 12)
    warehouse.add_child(warehouse_detail)
    var warehouse_button: Button = _button("UPGRADE", _operation.bind("economy", "warehouse"), warehouse)
    HUD.action(warehouse_button)
    warehouse_card.merge({"button": warehouse_button, "detail": warehouse_detail, "costs": _cost_grid(warehouse)})
    for resource in ECONOMY.RESOURCES:
        var definition: Dictionary = ECONOMY.ECONOMY_BUILDINGS[resource]
        var section: VBoxContainer = HUD.section(parent, "")
        section.get_child(0).hide()
        var disclosure: Dictionary = _make_disclosure(section, str(definition["name"]))
        var card: VBoxContainer = disclosure["body"]
        var effect: Label = _label("+25% farm capacity" if resource == "Organics" else "+25%% %s output" % resource, 12)
        card.add_child(effect)
        var detail: Label = _label("", 12)
        card.add_child(detail)
        var button: Button = _button("BUY", _operation.bind("economy", resource), card)
        HUD.action(button)
        disclosure.merge({"button": button, "detail": detail, "costs": _cost_grid(card)})
        economy_cards[resource] = disclosure

func _refresh_economy_cards(p: Dictionary, owned: bool) -> void:
    var level: int = int(p.get("warehouse_level", 0))
    var warehouse_button: Button = warehouse_card["button"]
    warehouse_button.disabled = not owned or not ECONOMY.warehouse_available(p)
    warehouse_button.text = "MAX LEVEL" if level >= 3 else "UPGRADE TO LV %d" % (level + 1)
    var warehouse_detail: String = "%s / resource" % _compact_amount(ECONOMY.storage_capacity(p))
    if level < 3:
        warehouse_detail += " → %s" % _compact_amount(float(ECONOMY.WAREHOUSE_CAPACITIES[level + 1]))
        if float(p["population"]) + ECONOMY.EPS < float(ECONOMY.WAREHOUSE_POPULATIONS[level]):
            warehouse_detail += "\nRequires %s population" % _compact_amount(float(ECONOMY.WAREHOUSE_POPULATIONS[level]))
        if not ECONOMY.affordable(p, ECONOMY.WAREHOUSE_COSTS[level]):
            warehouse_detail += "\nInsufficient local materials"
        _show_cost(warehouse_card["costs"], ECONOMY.WAREHOUSE_COSTS[level])
    warehouse_card["costs"].visible = level < 3
    _disclosure_title(warehouse_card, "Warehouse logistics · Lv %d" % level)
    warehouse_card["detail"].text = warehouse_detail
    warehouse_button.tooltip_text = warehouse_detail + ("\n" + _cost_text(ECONOMY.WAREHOUSE_COSTS[level]) if level < 3 else "")
    for resource in economy_cards:
        var card: Dictionary = economy_cards[resource]
        var definition: Dictionary = ECONOMY.ECONOMY_BUILDINGS[resource]
        var installed: bool = bool(p.get("buildings", {}).get(resource, false))
        var button: Button = card["button"]
        button.text = "BUILT" if installed else "BUY"
        button.disabled = not owned or not ECONOMY.building_available(p, resource)
        var cost: String = _cost_text(definition["cost"])
        var requirement: String = "%s population" % _compact_amount(float(definition["population"]))
        var unmet: PackedStringArray = []
        if not installed:
            if float(p["population"]) + ECONOMY.EPS < float(definition["population"]):
                unmet.append("Requires " + requirement)
            if not ECONOMY.production_available(p, resource):
                unmet.append("No local deposit")
            if not ECONOMY.affordable(p, definition["cost"]):
                unmet.append("Insufficient local materials")
        card["detail"].text = "\n".join(unmet)
        card["detail"].visible = not unmet.is_empty()
        card["costs"].visible = not installed
        _show_cost(card["costs"], definition["cost"])
        _disclosure_title(card, str(definition["name"]) + (" · Built" if installed else ""))
        button.tooltip_text = "Permanent local improvement" if installed else "%s\n%s" % [requirement, cost]

func _build_upgrade_cards(parent: Container) -> void:
    var labels: Dictionary = {"Metals": "Metal extraction", "Plastics": "Plastic production",
        "Textiles": "Textile production", "Organics": "Organics farming",
        "Tech": "Tech production", "Crystals": "Crystal extraction"}
    for resource in ECONOMY.RESOURCES:
        var section: VBoxContainer = HUD.section(parent, "")
        section.get_child(0).hide()
        var disclosure: Dictionary = _make_disclosure(section, labels[resource])
        var card: VBoxContainer = disclosure["body"]
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
        disclosure.merge({"title": disclosure["header"], "name": labels[resource], "detail": detail, "progress": progress, "button": action, "repeat": repeat, "costs": _cost_grid(card)})
        upgrade_cards[resource] = disclosure

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
        _disclosure_title(card, "%s · Lv %d" % [card["name"], level])
        var job: Dictionary = _upgrade_job(planet, resource)
        var button: Button = card["button"]
        var progress: ProgressBar = card["progress"]
        progress.visible = not job.is_empty()
        var detail: Label = card["detail"]
        var available: bool = ECONOMY.production_available(planet, resource)
        var unlocked: bool = ECONOMY.production_unlocked(planet, resource)
        var repeating: bool = bool(planet["continuous"].get("production:" + resource, false))
        _sync_repeat(card["repeat"], planet, "production:" + resource, owned and available and (unlocked or repeating))
        if not job.is_empty():
            progress.value = 100.0 * float(job["progress"]) / float(job["work"])
            progress.tooltip_text = _cost_text(job["cost"], job["allocated"])
            _style_progress(progress, planet, job)
            detail.text = "+1 production level · %.0f work\n%.0f%% complete%s" % [float(job["work"]), progress.value, " · Waiting" if ECONOMY._possible(planet, job) <= ECONOMY.EPS else ""]
            _show_cost(card["costs"], job["cost"])
            button.text = "CANCEL / REFUND"
            button.disabled = not owned
        else:
            button.text = "UPGRADE TO LV %d" % (level + 1)
            button.disabled = not owned or not unlocked
            if not available:
                detail.text = "No local deposit"
            else:
                var minimum: int = ECONOMY.production_population(resource, level + 1)
                var upgraded: Dictionary = planet.duplicate(true)
                upgraded["levels"][resource] = level + 1
                detail.text = "Output %.2f → %.2f/yr · %.0f yr" % [ECONOMY.rate(planet, resource), ECONOMY.rate(upgraded, resource), ECONOMY._work("production", level + 1)]
                if not unlocked:
                    detail.text += "\nRequires %s population" % _compact_amount(float(minimum))
                button.tooltip_text = _cost_text(ECONOMY._cost("production", level + 1))
            _show_cost(card["costs"], ECONOMY._cost("production", level + 1))

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
    var points: Array = ECONOMY.military_graph(state)["points"] if ship.get("kind", "") == "fighter" else state["map"]["points"]
    var pos: Vector2 = ECONOMY.combat_position(state, ECONOMY.military_graph(state), ship)
    var mode: String = ship.get("mining_mode", "idle")
    if mode == "outbound":
        return pos.distance_to(ship["mining_target"]) / ECONOMY.SHIP_SPEED
    if mode == "return":
        return pos.distance_to(points[int(ship["at"])]) / ECONOMY.SHIP_SPEED
    var remaining: float = 0.0
    for index in ship["route"]:
        var next: Vector2 = points[int(index)]
        remaining += pos.distance_to(next)
        pos = next
    return remaining / ECONOMY.SHIP_SPEED

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
    ship_detail.tooltip_text = "%d chunks remaining · %s" % [field["chunks"].size(), _system_name(int(field["anchor"]))]
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
    var status: String = "Orbiting %s" % _system_name(int(ship["at"]))
    if not route.is_empty():
        status = "%s → %s\nETA %.1f yr" % [_system_name(int(ship["at"])), _system_name(int(route.back())), _remaining_years(state, ship)]
    elif mode in ["outbound", "return"]:
        status = ("To field" if mode == "outbound" else "Returning") + "\nETA %.1f yr" % _remaining_years(state, ship)
    elif mode == "mining":
        status = "Mining field %02d\n%.1f / 5 yr" % [int(ship["field"]) + 1, minf(5.0, float(ship.get("mining_years", 0.0)))]
    if kind == "fighter":
        status = "Stationed at %s" % _poi_name(int(ship["at"])) if route.is_empty() else "%s\nETA %.1f yr" % [_poi_name(int(route.back())), _remaining_years(state, ship)]
    if bool(ship.get("retreating", false)):
        var site: int = int(ship.get("repair_site", -1))
        status = "Repairing" if route.is_empty() and site >= 0 and (ship["position"] as Vector2).distance_to(state["map"]["points"][site]) <= ECONOMY.EPS and ECONOMY._repair_site_safe(state, ECONOMY.military_graph(state), owner, site) else "Withdrawing"
    elif int(ship.get("pursuit_target", -1)) >= 0:
        status = "Pursuing"
    elif int(ship.get("combat_target", -1)) >= 0:
        status = "Engaged"
    ship_detail.text = "%s\n%s\nHP %.0f / %.0f" % [str(roster.get(owner, {}).get("name", "Player")), status, float(ship.get("hp", ECONOMY.SHIP_HP)), ECONOMY.SHIP_HP]
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
        fleet_detail.visible = true
        fleet_detail.text = "%d fighters" % int(ECONOMY.empire_totals(state, _me())["fighters"])
        fleet_detail.tooltip_text = "Assign forces using the Military lens."
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

func _build_lens_buttons() -> void:
    var lens_row := HBoxContainer.new()
    add_child(lens_row)
    lens_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    lens_row.offset_left = -112
    lens_row.offset_right = 112
    lens_row.offset_top = HEADER_HEIGHT + 16
    lens_row.offset_bottom = HEADER_HEIGHT + 48
    lens_row.add_theme_constant_override("separation", 6)
    military_lens = _button("MILITARY", _toggle_lens.bind("military"), lens_row)
    logistics_lens = _button("LOGISTICS", _toggle_lens.bind("logistics"), lens_row)
    for button in [military_lens, logistics_lens]:
        button.toggle_mode = true
        button.focus_mode = Control.FOCUS_NONE
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    military_lens.tooltip_text = "Fleet allocation at systems and asteroid fields"
    logistics_lens.tooltip_text = "System resource storage"

func _build_time_controls() -> void:
    var panel := PanelContainer.new()
    add_child(panel)
    panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928ed"), Color("#284661"), 4))
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    panel.offset_left = -116
    panel.offset_right = 116
    panel.offset_top = -48
    panel.offset_bottom = -8
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    panel.add_child(row)
    for speed in [0, 1, 2, 5]:
        var label: String = "Ⅱ" if speed == 0 else "%d×" % speed
        var button: Button = _button(label, _set_time_speed.bind(int(speed)), row)
        button.toggle_mode = true
        button.focus_mode = Control.FOCUS_NONE
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        time_buttons[speed] = button

func _set_time_speed(speed: int) -> void:
    session.call("request_time_speed", speed)
    _refresh_time_controls(_state())

func _refresh_time_controls(state: Dictionary) -> void:
    var current: int = int(state.get("time_speed", 1))
    var can_change: bool = str(session.get("phase")) == "match" and (bool(session.get("is_solo")) or multiplayer.is_server())
    for speed in time_buttons:
        var button: Button = time_buttons[speed]
        var active: bool = int(speed) == current
        button.disabled = not can_change
        button.set_pressed_no_signal(active)
        # Disabled guest buttons must still show which speed the host selected.
        if active:
            button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("pressed"))
            button.add_theme_color_override("font_disabled_color", HUD.ACCENT)
        else:
            button.remove_theme_stylebox_override("disabled")
            button.remove_theme_color_override("font_disabled_color")
        button.tooltip_text = ("Pause simulation" if int(speed) == 0 else "%d× simulation speed" % int(speed)) + ("" if can_change else " (host controlled)")

func _toggle_lens(kind: String) -> void:
    military_drag = -1
    military_preview.clear()
    active_lens = "" if active_lens == kind else kind
    military_lens.set_pressed_no_signal(active_lens == "military")
    logistics_lens.set_pressed_no_signal(active_lens == "logistics")
    map_canvas.queue_redraw()

func _draw_resource_fill(tile: PanelContainer, resource: String) -> void:
    var fraction: float = float(global_resource_fills.get(resource, 0.0))
    if fraction <= 0.0:
        return
    var inner: Vector2 = tile.size - Vector2(2.0, 2.0)
    tile.draw_rect(Rect2(Vector2.ONE, Vector2(maxf(0.0, inner.x * fraction), maxf(0.0, inner.y))), Color(HUD.COLORS[resource], 0.18))

func _build_territory_layer() -> void:
    territory_layer = Control.new()
    add_child(territory_layer)
    territory_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    territory_layer.offset_left = 8
    territory_layer.offset_top = HEADER_HEIGHT + 16
    territory_layer.offset_right = -8
    territory_layer.offset_bottom = -8
    territory_layer.clip_contents = true
    territory_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    territory_image = ColorRect.new()
    territory_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    territory_layer.add_child(territory_image)
    # The texture stores site coordinates, NOT a spatial raster. Every output
    # pixel evaluates continuous circle distances in world space.
    var shader := Shader.new()
    shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D site_data : filter_nearest, repeat_disable;
uniform int site_count = 0;
uniform vec2 world_extent = vec2(1.0);
uniform float padding = 1.0;

float smooth_min(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}
vec3 team_color(int team) {
    if (team == 1) return vec3(0.404, 0.831, 0.663);
    if (team == 2) return vec3(0.957, 0.643, 0.416);
    if (team == 3) return vec3(0.467, 0.667, 0.996);
    if (team == 4) return vec3(0.808, 0.569, 0.929);
    if (team == 5) return vec3(0.933, 0.820, 0.420);
    if (team == 6) return vec3(0.941, 0.518, 0.651);
    if (team == 7) return vec3(0.420, 0.796, 0.831);
    return vec3(0.929, 0.459, 0.467);
}
void fragment() {
    vec2 p = UV * world_extent - vec2(padding);
    float fields[8];
    for (int j = 0; j < 8; j++) { fields[j] = 10000.0; }
    float neutral = 10000.0;
    for (int i = 0; i < site_count; i++) {
        vec4 site = texelFetch(site_data, ivec2(i, 0), 0);
        float d = length(p - site.xy) - site.z;
        int team = int(site.w + 0.5);
        if (team == 0) {
            neutral = smooth_min(neutral, d, 0.16);
        } else {
            fields[team - 1] = smooth_min(fields[team - 1], d, 0.48);
        }
    }
    float best = 10000.0;
    float other = 10000.0;
    int winner = 1;
    for (int j = 0; j < 8; j++) {
        float d = fields[j];
        if (d < best) {
            other = best;
            best = d;
            winner = j + 1;
        } else {
            other = min(other, d);
        }
    }
    // Rival fields never overlap; keep a narrow neutral seam. Neutral and
    // contested sites are excluded with a rounded subtraction.
    float d = max(best, 0.045 + (best - other) * 0.5);
    d = -smooth_min(-d, neutral, 0.12);
    float aa = max(fwidth(d), 0.00001);
    float inside = 1.0 - smoothstep(-aa * 0.65, aa * 0.65, d);
    float border = 1.0 - smoothstep(aa * 0.45, aa * 1.45, abs(d));
    COLOR = vec4(team_color(winner), inside * 0.12 + border * 0.52);
}
"""
    territory_material = ShaderMaterial.new()
    territory_material.shader = shader
    territory_image.material = territory_material
    territory_image.hide()

# One consistent radius per galaxy, based on median nearest-system spacing.
# Outlier systems cannot create enormous wedges; asteroid fields are smaller.
func _territory_base_radius(state: Dictionary) -> float:
    var points: Array = state["map"]["points"]
    var spacings: Array[float] = []
    for i in range(points.size()):
        var point: Vector2 = points[i]
        var shortest: float = INF
        for j in range(points.size()):
            if i != j:
                shortest = minf(shortest, point.distance_to(points[j]))
        if is_finite(shortest) and shortest > 0.0:
            spacings.append(shortest)
    spacings.sort()
    if spacings.is_empty():
        return 300.0
    return maxf(100.0, spacings[floori(float(spacings.size()) * 0.5)] * 0.73)

func _refresh_territory(state: Dictionary) -> void:
    if state.is_empty():
        territory_image.hide()
        territory_seed = -1
        territory_last.clear()
        return
    var seed_value: int = int(state["map"]["seed"])
    if territory_seed != seed_value:
        territory_radius = _territory_base_radius(state)
        territory_seed = seed_value
        territory_last.clear()
    var empires: Array[int] = ECONOMY.territory_empires(state)
    var claims: Array[int] = []
    for owner in empires:
        claims.append(_empire_color_index(owner))
    if claims == territory_last:
        return
    territory_last = claims
    var points: Array = ECONOMY.military_graph(state)["points"]
    var system_count: int = (state["planets"] as Array).size()
    var sources: Array[int] = []
    for i in range(points.size()):
        if claims[i] > 0:
            sources.append(i)
    var sites: Array[Color] = []
    for i in range(points.size()):
        var point: Vector2 = points[i]
        var radius: float = 1.0 if i < system_count else 0.68
        if claims[i] <= 0:
            # Only nearby neutral sites need exclusion, bounding shader work.
            var nearest: float = INF
            for source in sources:
                nearest = minf(nearest, point.distance_to(points[source]) / territory_radius)
            if nearest > 1.65:
                continue
            radius = minf(radius * 0.36, nearest * 0.38)
            if radius <= 0.01:
                continue
        sites.append(Color(point.x / territory_radius, point.y / territory_radius, radius, float(claims[i])))
    territory_site_count = sites.size()
    if sources.is_empty():
        territory_image.hide()
        return
    var data: Image = Image.create_empty(sites.size(), 1, false, Image.FORMAT_RGBAF)
    for i in range(sites.size()):
        data.set_pixel(i, 0, sites[i])
    territory_sites = ImageTexture.create_from_image(data)
    territory_material.set_shader_parameter("site_data", territory_sites)
    territory_material.set_shader_parameter("site_count", territory_site_count)
    territory_material.set_shader_parameter("world_extent", _map_size() / territory_radius + Vector2.ONE * 3.0)
    territory_material.set_shader_parameter("padding", 1.5)
    territory_image.show()
    _position_territory()

func _position_territory() -> void:
    var padding: Vector2 = Vector2.ONE * territory_radius * 1.5
    territory_image.position = _screen_point(-padding)
    territory_image.size = (_map_size() + padding * 2.0) * _fit() * zoom

func _show_system_rings(index: int) -> bool:
    return index == selected

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
        global_resource_fills[resource] = 0.0
        tile.draw.connect(_draw_resource_fill.bind(tile, resource))

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
        var stored: float = float(totals["stock"][resource])
        var reference: float = float(totals["storage_reference"][resource])
        global_resource_fills[resource] = clampf(stored / reference, 0.0, 1.0) if reference > 0.0 else 0.0
        var tile: PanelContainer = global_resource_tiles[resource]
        tile.queue_redraw()
        tile.tooltip_text = "%s: %.1f\nStored: %.1f / %.0f • Cargo: %.1f\nNet: %+.2f/year (last 5 years)\nStorage capacity" % [
            resource, value, stored, reference, float(totals["cargo"][resource]), rate]
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
        var capacity: float = ECONOMY.storage_capacity(p)
        slider.set_stock(stock, capacity, HUD.COLORS[resource])
        trade_stock_labels[resource].text = "%s / %s" % [_compact_amount(stock) if stock >= 1000.0 else "%.1f" % stock, _compact_amount(capacity)]
        trade_stock_labels[resource].tooltip_text = "%.1f / %.0f" % [stock, capacity]
        slider.tooltip_text = "Import below the left handle; export above the right handle. 100%% = %.0f units." % capacity
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
    _refresh_time_controls(state)
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
    var own_system: bool = not p.is_empty() and int(p.get("owner", -1)) == _me()
    inspector_tabs.visible = not other_selected and own_system
    var current_system: int = selected if not other_selected and not p.is_empty() else -1
    if current_system != last_system_tab_selection:
        if current_system >= 0:
            inspector_tabs.current_tab = 0
        for card in build_cards.values() + economy_cards.values() + upgrade_cards.values() + yard_activity_rows.values() + [warehouse_card]:
            _collapse_card(card)
        last_system_tab_selection = current_system
    interaction_panel.visible = not other_selected and not p.is_empty() and not own_system
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
    for kind in continuous_checks:
        var check: Button = continuous_checks[kind]
        _sync_repeat(check, p, kind, owned and (kind != "ship" or bool(p.get("home", false))))
    colony_button.disabled = not owned
    for slider in trade_sliders.values():
        slider.enabled = owned
        if not owned:
            slider.active_handle = -1
        slider.queue_redraw()
    fighter_button.disabled = not owned
    miner_button.disabled = not owned
    ship_button.disabled = true
    if p.is_empty():
        info.text = "Select a system."
        system_owner_label.text = ""
        population_label.text = ""
        _refresh_build_cards(p, false)
        return
    var owner: int = int(p["owner"])
    var roster: Dictionary = session.get("players")
    var name_text: String = "Neutral" if owner == 0 else str(roster.get(owner, {}).get("name", "Player"))
    info.text = _system_name(selected)
    info.tooltip_text = info.text + (" · Home" if bool(p["home"]) else "")
    system_owner_label.text = name_text
    system_owner_label.tooltip_text = name_text
    system_owner_label.add_theme_color_override("font_color", _empire_color(owner).lerp(HUD.MUTED, 0.28))
    for resource in ECONOMY.RESOURCES:
        var amount: float = float(p["stock"][resource])
        production_values[resource]["stock"].text = _compact_amount(amount) if amount >= 1000.0 else "%.1f" % amount
        production_values[resource]["stock"].tooltip_text = "%.1f %s stored" % [amount, resource]
        production_values[resource]["level"].text = str(int(p["levels"][resource]))
        var percent: int = roundi(100.0 * ECONOMY.production_modifier(p, resource))
        var bonus: Label = production_values[resource]["bonus"]
        bonus.text = "—" if percent == 100 else "%d%%" % (percent - 100) if percent < 100 else "+%d%%" % (percent - 100)
        bonus.add_theme_color_override("font_color", HUD.ACCENT if percent > 100 else (Color("#e4a479") if percent < 100 else HUD.MUTED))
        bonus.tooltip_text = "%.1f%% of baseline output" % (100.0 * ECONOMY.production_modifier(p, resource))
        var annual: float = ECONOMY.net_rate(p, resource)
        production_values[resource]["rate"].text = _compact_amount(annual) if annual >= 1000.0 else "%.1f" % annual
        production_values[resource]["rate"].tooltip_text = "Production %.2f/yr · Consumption %.2f/yr · Net %.2f/yr" % [ECONOMY.rate(p, resource), ECONOMY.consumption(p, resource), annual]
    var population: float = float(p["population"])
    population_label.text = "Population %s" % _compact_amount(population)
    population_label.tooltip_text = "%.0f people" % population
    _update_trade_stock(p)
    _refresh_upgrade_cards(p, owned)
    _refresh_economy_cards(p, owned)
    ship_button.disabled = not owned or not bool(p["home"])
    _refresh_build_cards(p, owned)

func _upgrade_yard_at(index: int) -> void:
    if index < 0:
        _cancel_job(-index)
    elif index >= 100:
        _operation("yard", str(index - 100))
    elif ECONOMY._has_job(_planet(), "yard_upgrade", str(index)):
        _cancel_kind("yard_upgrade", str(index))
    else:
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
        # A queued upgrade with no materials may be unassigned; keep its bar visible.
        for i in range(yards.size()):
            if not active[i].is_empty():
                continue
            for queued in p["queue"]:
                if queued["kind"] == "yard_upgrade" and int(queued["target"]) == i:
                    active[i] = queued
                    break
        var reserved: Dictionary = {}
        for job in p["queue"]:
            if job["kind"] == "yard":
                active[-int(job["id"])] = job
                reserved[int(job["level"])] = true
        for slot in range(yards.size() + 1, ECONOMY.MAX_SHIPYARDS + 1):
            if not reserved.has(slot):
                active[100 + slot] = {}
    yard_activity.get_parent().visible = not p.is_empty()
    for index in yard_activity_rows.keys():
        if not active.has(index):
            var obsolete: Control = yard_activity_rows[index]["row"]
            yard_activity.remove_child(obsolete)
            obsolete.queue_free()
            yard_activity_rows.erase(index)
    for index in active:
        var job: Dictionary = active[index]
        var vacant: bool = int(index) >= 100
        var number: int = int(index) - 100 if vacant else int(index) + 1
        if int(index) < 0:
            number = int(job["level"])
        if not yard_activity_rows.has(index):
            var row := VBoxContainer.new()
            var header := HBoxContainer.new()
            row.add_child(header)
            var title := _label("", 12)
            title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            header.add_child(title)
            var build: Button = _button("Build", _upgrade_yard_at.bind(int(index)), header)
            build.custom_minimum_size = Vector2(48, 22)
            build.add_theme_font_size_override("font_size", 11)
            var costs := GridContainer.new()
            costs.columns = 3
            row.add_child(costs)
            var progress := ProgressBar.new()
            progress.custom_minimum_size.y = 16
            row.add_child(progress)
            var disclosure: Dictionary = _make_disclosure(row, "Upgrade")
            var upgrade_detail := _label("", 11)
            disclosure["body"].add_child(upgrade_detail)
            var upgrade_costs: GridContainer = _cost_grid(disclosure["body"])
            var actions := HBoxContainer.new()
            disclosure["body"].add_child(actions)
            var upgrade: Button = _button("UPGRADE", _upgrade_yard_at.bind(int(index)), actions)
            upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            var repeat: Button = _repeat_button(actions, "yard_upgrade:" + str(index))
            upgrade.custom_minimum_size.y = 24
            upgrade.add_theme_font_size_override("font_size", 11)
            yard_activity.add_child(row)
            disclosure.merge({"row": row, "label": title, "progress": progress, "upgrade": upgrade, "repeat": repeat, "build": build, "costs": costs, "upgrade_detail": upgrade_detail, "upgrade_costs": upgrade_costs})
            yard_activity_rows[index] = disclosure
        var label: Label = yard_activity_rows[index]["label"]
        var bar: ProgressBar = yard_activity_rows[index]["progress"]
        var upgrade: Button = yard_activity_rows[index]["upgrade"]
        yard_activity.move_child(yard_activity_rows[index]["row"], mini(number, yard_activity.get_child_count() - 1))
        var repeat: Button = yard_activity_rows[index]["repeat"]
        var build: Button = yard_activity_rows[index]["build"]
        var costs: GridContainer = yard_activity_rows[index]["costs"]
        var can_build: bool = vacant and number == ECONOMY.next_shipyard_slot(p) and int(p["owner"]) == _me() and str(session.get("phase")) == "match"
        build.visible = can_build
        build.disabled = not can_build
        costs.visible = can_build
        yard_activity_rows[index]["header"].visible = not vacant
        if vacant:
            _collapse_card(yard_activity_rows[index])
            label.text = "Shipyard %d" % number
            bar.visible = false
            upgrade.visible = false
            repeat.visible = false
            var recipe: Dictionary = ECONOMY._cost("yard", number)
            label.tooltip_text = _cost_text(recipe)
            build.tooltip_text = label.tooltip_text
            if costs.get_child_count() == 0:
                for resource in recipe:
                    var pair := HBoxContainer.new()
                    pair.add_theme_constant_override("separation", 3)
                    costs.add_child(pair)
                    var symbol := TextureRect.new()
                    symbol.texture = HUD.ICONS[resource]
                    symbol.custom_minimum_size = Vector2(12, 12)
                    symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                    symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                    pair.add_child(symbol)
                    var amount: Label = _label(_compact_amount(float(recipe[resource])) if float(recipe[resource]) >= 1000.0 else "%.0f" % float(recipe[resource]), 11)
                    amount.autowrap_mode = TextServer.AUTOWRAP_OFF
                    pair.add_child(amount)
                    pair.tooltip_text = "%.0f %s" % [float(recipe[resource]), resource]
            continue
        bar.visible = true
        label.tooltip_text = ""
        var existing: bool = int(index) >= 0
        var level: int = int(p["yards"][index]["level"]) if existing else 1
        var pending: bool = existing and ECONOMY._has_job(p, "yard_upgrade", str(index))
        upgrade.visible = int(p["owner"]) == _me()
        repeat.visible = existing and upgrade.visible
        _sync_repeat(repeat, p, "yard_upgrade:" + str(index), repeat.visible and str(session.get("phase")) == "match")
        upgrade.disabled = not upgrade.visible or str(session.get("phase")) != "match"
        upgrade.text = "CANCEL" if pending or not existing else "UPGRADE TO LV %d" % (level + 1)
        _disclosure_title(yard_activity_rows[index], "Upgrade to Lv %d" % (level + 1) if existing and not pending else ("Upgrade pending" if existing else "Construction details"))
        yard_activity_rows[index]["upgrade_detail"].text = "Build speed %.0f → %.0f work/yr · Max size %d → %d" % [ECONOMY.yard_speed(level), ECONOMY.yard_speed(level + 1), ECONOMY.max_size(level), ECONOMY.max_size(level + 1)] if existing else "Adds a shipyard · %.0f yr" % float(job["work"])
        _show_cost(yard_activity_rows[index]["upgrade_costs"], ECONOMY._cost("yard_upgrade", level + 1) if existing else job["cost"])
        upgrade.tooltip_text = "Lv %d • %.0f Metals • %.0f years" % [level, float(ECONOMY._cost("yard_upgrade", level + 1)["Metals"]), ECONOMY._work("yard_upgrade", level + 1)] if existing else _cost_text(job["cost"], job["allocated"])
        if job.is_empty():
            label.text = "Shipyard %d · Lv %d · Idle" % [number, level]
            bar.value = 0.0
            bar.show_percentage = false
            bar.tooltip_text = "Shipyard %d" % (int(index) + 1)
            _style_progress(bar, p, {})
            continue
        bar.show_percentage = true
        var name_text: String = "Logistics ship" if job["kind"] == "ship" else str(job["kind"]).replace("_", " ").capitalize()
        if job["kind"] == "yard_upgrade":
            name_text = "Upgrade to Lv %d" % int(job["level"])
        elif job["kind"] == "yard":
            name_text = "Construction"
        label.text = "Shipyard %d · Lv %d · %s" % [number, level, name_text] if existing else "Shipyard %d · %s" % [number, name_text]
        bar.value = 100.0 * float(job["progress"]) / float(job["work"])
        bar.tooltip_text = "Shipyard %d" % number
        _style_progress(bar, p, job)

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

func _cancel_kind(kind: String, target: String) -> void:
    var p: Dictionary = _planet()
    # Cancel the newest matching order first, preserving earlier work.
    var orders: Array = p.get("queue", [])
    for i in range(orders.size() - 1, -1, -1):
        var job: Dictionary = orders[i]
        if job["kind"] == kind and job["target"] == target:
            _cancel_job(int(job["id"]))
            return

func _refresh_build_cards(p: Dictionary, owned: bool) -> void:
    var counts: Dictionary = {}
    var first_jobs: Dictionary = {}
    for order in p.get("queue", []):
        var kind: String = order["kind"]
        counts[kind] = int(counts.get(kind, 0)) + 1
        if not first_jobs.has(kind):
            first_jobs[kind] = order
    for kind in build_cards:
        var card: Dictionary = build_cards[kind]
        var count: int = int(counts.get(kind, 0))
        card["button"].text = "%s (%d)" % [card["title"], count] if count > 0 else card["title"]
        _disclosure_title(card, card["title"].trim_prefix("BUILD ").capitalize() + (" (%d)" % count if count > 0 else ""))
        card["button"].tooltip_text = _cost_text(ECONOMY._cost(kind, 1)) + " · %.0f population" % float(ECONOMY.CREW_COSTS[kind])
        var requirements: PackedStringArray = []
        if not p.is_empty():
            if (p["yards"] as Array).is_empty():
                requirements.append("Requires a shipyard")
            if kind == "ship" and not bool(p.get("home", false)):
                requirements.append("Requires home system")
            if float(p["population"]) < float(ECONOMY.CREW_COSTS[kind]) + 1.0:
                requirements.append("Insufficient population")
            if not ECONOMY.affordable(p, ECONOMY._cost(kind, 1)):
                requirements.append("Insufficient local materials · construction waits")
        card["requirements"].text = "\n".join(requirements)
        card["requirements"].visible = not requirements.is_empty()
        var job: Dictionary = first_jobs.get(kind, {})
        var progress: ProgressBar = card["build_progress"]
        progress.visible = not job.is_empty()
        if not job.is_empty():
            progress.value = 100.0 * float(job["progress"]) / float(job["work"])
            progress.tooltip_text = _cost_text(job["cost"], job["allocated"])
            _style_progress(progress, p, job)
        card["cancel"].visible = count > 0
        card["cancel"].disabled = not owned

func _system_name(index: int) -> String:
    var names: Array = _state().get("map", {}).get("names", [])
    return str(names[index]) if index >= 0 and index < names.size() else "Unknown"

func _open_menu() -> void:
    drag_button = 0
    military_drag = -1
    military_preview.clear()
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
                labels.append("Colony ship #%d • %s" % [int(ship["id"]), _system_name(int(ship["at"]))])
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
            if _show_system_rings(index):
                map_canvas.draw_arc(pos, orbit, 0.0, TAU, 48, Color(tint, 0.24), 0.8, true)
            var point: Vector2 = pos + _body_position(body, radius, game_visual_clock)
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
    if _show_system_rings(index):
        map_canvas.draw_arc(pos, radius + 1.5, 0.0, TAU, 48, Color(tint, 0.65), 1.5, true)

func _empire_color_index(owner: int) -> int:
    if owner == 0:
        return 0
    var roster: Dictionary = session.get("players")
    return clampi(int(roster.get(owner, {}).get("color", 0)), 0, RULES.MAX_PLAYERS)

func _empire_color(owner: int) -> Color:
    return COLORS[_empire_color_index(owner)]

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
    # Use the same interpolated physical pose for selection and rendering.
    var poses: Dictionary = _ship_poses(state)
    var ship_hit: int = -1
    var ship_distance: float = INF
    for id in poses:
        var distance: float = point.distance_to(poses[id]["point"])
        if distance <= maxf(5.0, 12.0 * _ship_scale()) and distance < ship_distance:
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
        if mouse.button_index == MOUSE_BUTTON_LEFT and active_lens == "military":
            if mouse.pressed:
                military_drag = _combat_slider_at(mouse.position)
                if military_drag >= 0:
                    military_drag_weights = ECONOMY.military_policy(_state(), _me(), "fighter")
                    _update_combat_drag(mouse.position)
                    map_canvas.accept_event()
                    return
            elif military_drag >= 0:
                _update_combat_drag(mouse.position)
                var node: int = military_drag
                var percent: int = int(military_preview[node])
                military_drag = -1
                military_preview.clear()
                session.call("request_military", "fighter", node, percent)
                map_canvas.queue_redraw()
                map_canvas.accept_event()
                return
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
    elif event is InputEventMouseMotion and military_drag >= 0:
        _update_combat_drag(event.position)
    elif event is InputEventMouseMotion and drag_button != 0:
        var motion: InputEventMouseMotion = event
        if motion.button_mask == 0:
            drag_button = 0
        else:
            pan += motion.relative
            map_canvas.queue_redraw()
    map_canvas.accept_event()

func _fighter_path(ship: Dictionary) -> Array[int]:
    var path: Array[int] = [int(ship["at"])]
    for node in ship["route"]:
        path.append(int(node))
    return path

func _poi_name(node: int) -> String:
    var count: int = (_state().get("planets", []) as Array).size()
    return _system_name(node) if node < count else "Asteroid field %02d" % (node - count + 1)

func _ship_position(ship: Dictionary, _points: Array) -> Vector2:
    if ship.has("position"):
        return ship["position"]
    return ECONOMY.combat_position(_state(), ECONOMY.military_graph(_state()), ship)

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
    _refresh_territory(state)
    _sync_ship_visuals(state)
    _refresh()

func _sync_ship_visuals(state: Dictionary) -> void:
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
    for id in ship_offsets.keys():
        if not updated.has(id):
            ship_offsets.erase(id)

func _keyboard_pan(delta: float) -> void:
    if str(session.get("phase")) != "match" or match_menu.visible:
        return
    if not get_window().has_focus():
        return
    var focus: Control = get_viewport().gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit:
        return
    for picker in [colony_picker]:
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
    visual_clock += delta
    game_visual_clock += delta * float(_state().get("time_speed", 1))
    for visual in ship_visuals.values():
        if float(visual["age"]) < SNAPSHOT_SECONDS:
            visual["age"] = minf(SNAPSHOT_SECONDS, float(visual["age"]) + delta)
    var state: Dictionary = _state()
    if not state.is_empty():
        _ship_poses(state, delta)
    if is_instance_valid(map_canvas):
        _position_territory()
        map_canvas.queue_redraw()

func _orbit_offset(slot: int, radius: float, time: float) -> Vector2:
    var ring: int = floori(float(slot) / 8.0)
    var angle: float = TAU * float(slot % 8) / 8.0 + time * (0.48 / (1.0 + float(ring) * 0.2)) + float(ring) * 0.35
    return Vector2.from_angle(angle) * (radius + 12.0 + float(ring) * 13.0)

func _orbit_direction(offset: Vector2) -> Vector2:
    return Vector2(-offset.y, offset.x).normalized()

func _ship_scale() -> float:
    return SHIP_WORLD_SCALE * _fit() * zoom

func _ship_poses(state: Dictionary, delta: float = 0.0) -> Dictionary:
    _sync_ship_visuals(state)
    var points: Array = state["map"]["points"]
    var poses: Dictionary = {}
    for ship in state["ships"]:
        var id: int = int(ship["id"])
        var visual: Dictionary = ship_visuals.get(id, {})
        var pos: Vector2 = _ship_position(ship, points) if visual.is_empty() else _visual_position(visual)
        var direction: Vector2 = ship.get("heading", Vector2.UP)
        var prior: Dictionary = ship_offsets.get(id, {"angle": direction.angle()})
        var weight: float = 1.0 - exp(-delta / SNAPSHOT_SECONDS * 3.0)
        var angle: float = lerp_angle(float(prior["angle"]), direction.angle(), weight)
        if delta > 0.0 or not ship_offsets.has(id):
            ship_offsets[id] = {"angle": angle}
        var mining: bool = ship.get("kind", "") == "miner" and ship.get("mining_mode", "idle") in ["outbound", "mining", "return"]
        poses[id] = {"point": _screen_point(pos), "direction": Vector2.from_angle(angle), "mining": mining}
    return poses

func _combat_slider_rect(state: Dictionary, node: int, points: Array) -> Rect2:
    var count: int = (state["planets"] as Array).size()
    var radius: float = _planet_radius(node, state) if node < count else maxf(9.0, float(state["map"]["fields"][node - count]["radius"]) * _fit() * zoom)
    var pos: Vector2 = _screen_point(points[node])
    return Rect2(pos + Vector2(-27.0, -radius - 22.0), Vector2(54.0, 18.0))

func _combat_slider_at(point: Vector2) -> int:
    if active_lens != "military":
        return -1
    var state: Dictionary = _state()
    if state.is_empty():
        return -1
    var points: Array = ECONOMY.military_graph(state)["points"]
    var best: float = INF
    var result: int = -1
    for node in ECONOMY.military_pois(state, _me()):
        var rect: Rect2 = _combat_slider_rect(state, node, points)
        if rect.has_point(point):
            var distance: float = rect.get_center().distance_to(point)
            if distance < best:
                best = distance
                result = node
    return result

func _update_combat_drag(point: Vector2) -> void:
    var state: Dictionary = _state()
    var points: Array = ECONOMY.military_graph(state)["points"]
    var rect: Rect2 = _combat_slider_rect(state, military_drag, points)
    var percent: int = roundi(clampf((point.x - rect.position.x - 4.0) / (rect.size.x - 8.0), 0.0, 1.0) * 100.0)
    military_preview = ECONOMY.change_military_weights(military_drag_weights, ECONOMY.military_home(state, _me()), military_drag, percent)
    map_canvas.queue_redraw()

func _draw_combat_lens(state: Dictionary, font: Font) -> void:
    if active_lens != "military":
        return
    var points: Array = ECONOMY.military_graph(state)["points"]
    var weights: Dictionary = military_preview if military_drag >= 0 else ECONOMY.military_policy(state, _me(), "fighter")
    for node in ECONOMY.military_pois(state, _me()):
        var rect: Rect2 = _combat_slider_rect(state, node, points)
        if not Rect2(Vector2.ZERO, map_canvas.size).intersects(rect):
            continue
        var percent: int = int(weights.get(node, 0))
        var tint: Color = Color("#e9a276") if percent > 0 else HUD.MUTED
        map_canvas.draw_rect(rect, Color("#0c1928ed"))
        map_canvas.draw_rect(rect, Color(tint, 0.6), false, 1.0)
        var track := Rect2(rect.position + Vector2(4.0, 12.0), Vector2(rect.size.x - 8.0, 3.0))
        map_canvas.draw_rect(track, Color("#344960"))
        map_canvas.draw_rect(Rect2(track.position, Vector2(track.size.x * float(percent) / 100.0, 3.0)), tint)
        map_canvas.draw_circle(track.position + Vector2(track.size.x * float(percent) / 100.0, 1.5), 3.0, tint)
        map_canvas.draw_string(font, rect.position + Vector2(0, 10), "%d%%" % percent, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, tint)

func _draw_logistics_lens(state: Dictionary, font: Font) -> void:
    if active_lens != "logistics":
        return
    var points: Array = state["map"]["points"]
    for i in range(points.size()):
        var system: Dictionary = state["planets"][i]
        if int(system["owner"]) == 0 or not ECONOMY.discovered(state, _me(), "planets", i):
            continue
        var pos: Vector2 = _screen_point(points[i])
        var radius: float = _planet_radius(i, state)
        if not get_viewport_rect().grow(radius + 80.0).has_point(pos):
            continue
        var spacing: float = float(_system_visual(i, state)["spacing"]) * _fit() * zoom
        var detailed: bool = spacing >= 150.0
        if detailed:
            var origin: Vector2 = pos + Vector2(-69, radius + 9)
            map_canvas.draw_rect(Rect2(origin - Vector2(3, 3), Vector2(144, 38)), Color("#0c1928ec"))
            for r in range(ECONOMY.RESOURCES.size()):
                var resource: String = ECONOMY.RESOURCES[r]
                var cell: Vector2 = origin + Vector2(float(r % 3) * 47.0, floorf(float(r) / 3.0) * 18.0)
                map_canvas.draw_texture_rect(HUD.ICONS[resource], Rect2(cell, Vector2(13, 13)), false)
                map_canvas.draw_string(font, cell + Vector2(15, 11), _compact_amount(float(system["stock"][resource])), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, HUD.COLORS[resource])
        else:
            # At wide zoom, compact resource-colored bars avoid dense labels.
            var bar_width: float = clampf(spacing / 8.0, 2.0, 8.0)
            var width: float = 6.0 * (bar_width + 1.0) - 1.0
            var origin: Vector2 = pos + Vector2(-width * 0.5, radius + 5.0)
            for r in range(ECONOMY.RESOURCES.size()):
                var resource: String = ECONOMY.RESOURCES[r]
                var fraction: float = clampf(float(system["stock"][resource]) / ECONOMY.storage_capacity(system), 0.0, 1.0)
                var cell: Vector2 = origin + Vector2(float(r) * (bar_width + 1.0), 0)
                map_canvas.draw_rect(Rect2(cell, Vector2(bar_width, 4)), Color("#263b50"))
                if fraction > 0.0:
                    map_canvas.draw_rect(Rect2(cell, Vector2(bar_width * fraction, 4)), HUD.COLORS[resource])

func _draw_map() -> void:
    if session == null:
        return
    var state: Dictionary = _state()
    if state.is_empty():
        return
    var points: Array = state["map"]["points"]
    for edge in state["map"]["edges"]:
        var a: int = int(edge[0])
        var b: int = int(edge[1])
        var known: bool = ECONOMY.discovered(state, _me(), "planets", a) and ECONOMY.discovered(state, _me(), "planets", b)
        var owner_a: int = int(state["planets"][a]["owner"])
        var owner_b: int = int(state["planets"][b]["owner"])
        var color: Color = _empire_color(owner_a).darkened(0.3) if known and owner_a > 0 and owner_a == owner_b else Color("#40566b")
        var a_pos: Vector2 = _screen_point(points[a])
        var b_pos: Vector2 = _screen_point(points[b])
        map_canvas.draw_line(a_pos, b_pos, Color(color, 0.30), 1.0, true)
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
        var tint: Color = _empire_color(int(state["planets"][i]["owner"]))
        _draw_system(i, state, pos, radius, tint)
        if i == selected and bool(state["planets"][i]["home"]):
            map_canvas.draw_arc(pos, radius + 5.0, 0.0, TAU, 48, Color(tint, 0.5), 1.0, true)
        if i == selected:
            var phase: float = 0.6 + 0.35 * sin(visual_clock * 3.0)
            for angle in range(4):
                var start: float = float(angle) * TAU / 4.0 + 0.1
                map_canvas.draw_arc(pos, radius + 8.0, start, start + 1.15, 14, Color(HUD.ACCENT, phase), 2.0, true)
        if i == selected:
            map_canvas.draw_string(font, pos + Vector2(-80, -radius - 8), _system_name(i), HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color("#f4faff"))
    _draw_combat_lens(state, font)
    _draw_logistics_lens(state, font)
    var poses: Dictionary = _ship_poses(state)
    for ship in state["ships"]:
        var shooter: int = int(ship["id"])
        var target: int = int(ship.get("combat_target", -1))
        if poses.has(shooter) and poses.has(target) and float(ship.get("laser_until", 0.0)) >= float(state["elapsed"]):
            map_canvas.draw_line(poses[shooter]["point"], poses[target]["point"], Color("#ff6f6060"), 4.0, true)
            map_canvas.draw_line(poses[shooter]["point"], poses[target]["point"], Color("#ffbf96"), 1.0, true)
    for ship in state["ships"]:
        if not poses.has(int(ship["id"])):
            continue
        var pose: Dictionary = poses[int(ship["id"])]
        var point: Vector2 = pose["point"]
        var direction: Vector2 = pose["direction"]
        var mining: bool = pose["mining"]
        var route: Array = ship["route"]
        var empire: Color = _empire_color(int(ship["owner"]))
        var loaded: bool = ECONOMY._cargo_total(ship) > ECONOMY.EPS
        var hull: Color = empire.lightened(0.35) if not loaded else Color("#f8df8c")
        var colony: bool = ship.get("kind", "ship") == "colony_ship"
        var fighter: bool = ship.get("kind", "ship") == "fighter"
        if colony:
            hull = Color("#c7a4ff")
        elif fighter:
            hull = Color("#f2b57e")
        elif ship.get("kind", "ship") == "miner":
            hull = Color("#d8e58b")
        var scale: float = _ship_scale()
        var side: Vector2 = direction.orthogonal() * scale
        direction *= scale
        var shape := PackedVector2Array([point + direction * 9, point - direction * 6 + side * 5,
            point - direction * 3, point - direction * 6 - side * 5])
        if colony:
            shape = PackedVector2Array([point + direction * 12, point + side * 7, point - direction * 9, point - side * 7])
        if fighter:
            shape = PackedVector2Array([point + direction * 12, point - direction * 7 + side * 8, point - direction * 3, point - direction * 7 - side * 8])
        if ship.get("kind", "ship") == "miner":
            shape = PackedVector2Array([point + direction * 8 + side * 4, point + direction * 8 - side * 4, point - direction * 6 - side * 7, point - direction * 6 + side * 7])
        var physical: Vector2 = ship.get("position", Vector2.ZERO)
        var target: Vector2 = ship.get("navigation_target", physical)
        if int(state.get("time_speed", 1)) > 0 and scale >= 0.65 and (not ECONOMY._engaged(ship)) and physical.distance_to(target) > ECONOMY.EPS:
            var engine: Vector2 = point - direction * 9.0
            map_canvas.draw_circle(engine, 5.0 * scale, Color("#43a5ff30"), true)
            map_canvas.draw_line(engine, engine - direction * (5.0 + 2.0 * sin(visual_clock * 9.0)), Color("#79dfff"), 2.0 * scale, true)
        if int(ship["id"]) == selected_ship_id:
            map_canvas.draw_arc(point, maxf(5.0, 15.0 * scale), 0.0, TAU, 32, HUD.ACCENT, 2.0, true)
        map_canvas.draw_colored_polygon(shape, hull)
        var outline: PackedVector2Array = shape.duplicate()
        outline.append(shape[0])
        map_canvas.draw_polyline(outline, Color("#08111b"), 2.5 * scale, true)
        # Keep class colors; identify allegiance on every hull, including loaded ships.
        map_canvas.draw_polyline(outline, empire.lightened(0.2), scale, true)
        var hp: float = clampf(float(ship.get("hp", ECONOMY.SHIP_HP)) / ECONOMY.SHIP_HP, 0.0, 1.0)
        if hp < 1.0 and scale >= 0.65:
            var bar_pos: Vector2 = point + Vector2(-10.0, 13.0)
            map_canvas.draw_rect(Rect2(bar_pos, Vector2(20.0, 3.0)), Color("#182333"))
            map_canvas.draw_rect(Rect2(bar_pos, Vector2(20.0 * hp, 3.0)), Color("#e9a276"))

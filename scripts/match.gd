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
const OVERVIEW_WIDTH: float = 340.0
const HEADER_HEIGHT: float = 54.0
const KEYBOARD_PAN_SPEED: float = 420.0
const RADIUS: float = 12.0
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 64.0
const SNAPSHOT_SECONDS: float = 0.2

var session: Node
var settings := ConfigFile.new()
var ui_percent: int = 90
var music_volume: float = 100.0
var sfx_volume: float = 100.0
var music_muted: bool = false
var sfx_muted: bool = false
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
var asteroid_shape_cache: Dictionary = {}
var asteroid_cache_seed: int = -1
var habitation_card: Dictionary = {}
var population_label: Label
var population_delta_label: Label
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
var global_resource_segments: Dictionary = {}
var global_resource_strips: Dictionary = {}
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
var resource_hover_panel: PanelContainer
var resource_hover_label: Label
var hovered_resource: String = ""
var global_population_label: Label
var year_label: Label
var time_buttons: Dictionary = {}
var game_visual_clock: float = 0.0
var info: Label
var visual_clock: float = 0.0
var system_visuals: Dictionary = {}
var system_visual_seed: int = -1
var trade_sliders: Dictionary = {}
var trade_checks: Dictionary = {}
var trade_stock_labels: Dictionary = {}
var upgrade_cards: Dictionary = {}
var pds_card: Dictionary = {}
var economy_cards: Dictionary = {}
var warehouse_card: Dictionary = {}
var continuous_checks: Dictionary = {}
var repeat_icon: Texture2D
var population_icon: Texture2D
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
    var import_enabled: bool = true
    var export_enabled: bool = true
    var active_handle: int = -1
    const PAD: float = 10.0
    const TRACK_Y: float = 14.0

    func set_range(minimum: float, maximum: float) -> void:
        active_handle = -1
        lower = clampf(minimum, 0.0, 100.0)
        upper = clampf(maximum, 0.0, 100.0)
        queue_redraw()

    func set_stock(amount: float, maximum: float, tint: Color) -> void:
        stock_percent = clampf(100.0 * amount / maxf(maximum, 1.0), 0.0, 100.0)
        stock_color = Color("#b9c8d6")
        queue_redraw()

    func _x(value: float) -> float:
        return PAD + maxf(1.0, size.x - PAD * 2.0) * value / 100.0

    func _value(x: float) -> float:
        return roundf(clampf((x - PAD) / maxf(1.0, size.x - PAD * 2.0) * 100.0, 0.0, 100.0))

    func _draw() -> void:
        var font: Font = ThemeDB.fallback_font
        var low_color := Color("#c9d6e2") if enabled else Color("#667687")
        var high_color := Color("#c9d6e2") if enabled else Color("#667687")
        var left: String = "Import < %d%%" % roundi(lower)
        var right: String = "Export > %d%%" % roundi(upper)

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
        if import_enabled:
            draw_circle(lo, 7.0, low_color)
        if export_enabled:
            draw_circle(hi, 7.0, high_color)

    func _move_handle(x: float) -> void:
        if active_handle == 0:
            lower = _value(x)
            if export_enabled:
                upper = maxf(upper, lower)
        elif active_handle == 1:
            upper = _value(x)
            if import_enabled:
                lower = minf(lower, upper)
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
                if not import_enabled and not export_enabled:
                    return
                active_handle = 0 if import_enabled and (not export_enabled or event.position.distance_to(lo) < event.position.distance_to(hi)) else 1
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
    _load_settings()
    _build_ui()
    _build_resource_hover()
    _apply_settings()
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
    background.name = "SpaceBackdrop"
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
    _build_policy_zone_overlay()
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
    global_population_label = _global_stat(row, "0", Color("#b9d9ed"), true)
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
    _build_settings_menu()
    inspector_panel = PanelContainer.new()
    add_child(inspector_panel)
    inspector_panel.anchor_left = 1.0
    inspector_panel.anchor_right = 1.0
    inspector_panel.anchor_bottom = 1.0
    inspector_panel.offset_left = -PANEL_WIDTH
    inspector_panel.offset_right = -8
    inspector_panel.offset_top = HEADER_HEIGHT + 64
    inspector_panel.offset_bottom = -78
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
    population_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    population_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    population_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var population_row: HBoxContainer = _population_row(planet_overview)
    population_row.add_child(population_label)
    population_delta_label = _label("", 11)
    population_delta_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    population_row.add_child(population_delta_label)
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
    inspector_tabs.tab_changed.connect(func(_tab: int) -> void: _collapse_details())
    body.add_child(inspector_tabs)
    inspector_tabs.visibility_changed.connect(func() -> void:
        if not inspector_tabs.is_visible_in_tree():
            _collapse_details())
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
        stock_label.custom_minimum_size.x = 120
        stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        trade_row.add_child(stock_label)
        trade_stock_labels[resource] = stock_label
        var slider := TradeRange.new()
        slider.custom_minimum_size.y = 28
        slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        slider.tooltip_text = "Import below the left handle; export above the right handle. 100%% = %.0f t." % ECONOMY.TRADE_REFERENCE
        slider.committed.connect(_apply_thresholds.bind(resource))
        logistics.add_child(slider)
        trade_sliders[resource] = slider
        var switches := HBoxContainer.new()
        logistics.add_child(switches)
        logistics.move_child(switches, slider.get_index())
        var incoming := CheckBox.new()
        incoming.text = "Import"
        incoming.button_pressed = true
        switches.add_child(incoming)
        var outgoing := CheckBox.new()
        outgoing.text = "Export"
        outgoing.button_pressed = true
        incoming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        outgoing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        switches.add_child(outgoing)
        trade_checks[resource] = [incoming, outgoing]
        incoming.toggled.connect(_trade_toggle.bind(resource))
        outgoing.toggled.connect(_trade_toggle.bind(resource))
    var shipyards := VBoxContainer.new()
    shipyard_page.add_child(shipyards)
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
    _build_policy_ui()


func _make_disclosure(parent: Container, title_text: String) -> Dictionary:
    var line := HBoxContainer.new()
    line.add_theme_constant_override("separation", 3)
    parent.add_child(line)
    var header := Button.new()
    header.flat = true
    header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.clip_text = true
    header.alignment = HORIZONTAL_ALIGNMENT_LEFT
    header.custom_minimum_size.y = 28
    header.add_theme_font_size_override("font_size", 12)
    line.add_child(header)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 4)
    parent.add_child(body)
    body.hide()
    header.set_meta("caption", title_text)
    header.text = title_text
    var card: Dictionary = {"header": header, "body": body, "actions": line}
    header.pressed.connect(_toggle_disclosure.bind(card))
    return card

func _detail_cards() -> Array:
    return build_cards.values() + economy_cards.values() + upgrade_cards.values() + yard_activity_rows.values() + [warehouse_card, habitation_card, pds_card]

func _card_tab(card: Dictionary) -> Node:
    var node: Node = card["header"]
    while node.get_parent() != null:
        if node.get_parent() == inspector_tabs:
            return node
        node = node.get_parent()
    return null

func _toggle_disclosure(card: Dictionary) -> void:
    var expanded: bool = not card["body"].visible
    if expanded:
        var tab: Node = _card_tab(card)
        for other in _detail_cards():
            if other.has("body") and other["body"] != card["body"] and _card_tab(other) == tab:
                _collapse_card(other)
    card["body"].visible = expanded
    _disclosure_title(card, str(card["header"].get_meta("caption")))

func _collapse_details() -> void:
    for card in _detail_cards():
        _collapse_card(card)

func _card_action(card: Dictionary, caption: String, callback: Callable) -> Button:
    var button: Button = _button(caption, callback, card["actions"])
    button.custom_minimum_size = Vector2(0, 26)
    button.add_theme_font_size_override("font_size", 10)
    return button

func _card_cancel(card: Dictionary, callback: Callable, progress: ProgressBar = null) -> Button:
    var button: Button = _card_action(card, "×", callback)
    var line: HBoxContainer = card["actions"]
    line.move_child(button, 1)
    if progress != null:
        progress.reparent(line, false)
        line.move_child(progress, 0)
        progress.custom_minimum_size = Vector2(5, 0)
        progress.show_percentage = false
        progress.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
        progress.step = 0.0
        progress.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
        progress.size_flags_vertical = Control.SIZE_FILL
        progress.add_theme_stylebox_override("background", HUD.surface(Color("#14283a"), Color("#14283a"), 0, 0))
        progress.add_theme_stylebox_override("fill", HUD.surface(HUD.ACCENT, HUD.ACCENT, 0, 0))
    button.hide()
    button.custom_minimum_size.x = 23
    button.tooltip_text = "Cancel / refund"
    button.disabled = true
    return button

func _population_texture() -> Texture2D:
    if population_icon == null:
        var image := Image.new()
        image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="#b9d9ed"><circle cx="12" cy="6" r="4"/><path d="M4 22v-4a8 8 0 0 1 16 0v4z"/></svg>')
        population_icon = ImageTexture.create_from_image(image)
    return population_icon

func _population_row(parent: Container) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    parent.add_child(row)
    var icon := TextureRect.new()
    icon.texture = _population_texture()
    icon.custom_minimum_size = Vector2(14, 14)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.tooltip_text = "Population"
    row.add_child(icon)
    return row

func _disclosure_title(card: Dictionary, caption: String) -> void:
    var header: Button = card["header"]
    header.set_meta("caption", caption)
    header.text = caption

func _collapse_card(card: Dictionary) -> void:
    if card.has("body"):
        card["body"].hide()
        _disclosure_title(card, str(card["header"].get_meta("caption")))

func _style_progress(bar: ProgressBar, p: Dictionary, job: Dictionary) -> void:
    var blocked: Array[String] = []
    if not job.is_empty():
        blocked = ECONOMY.construction_blockers(p, job)
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
            symbol.texture = _population_texture()
        else:
            symbol.texture = HUD.ICONS[resource]
        symbol.custom_minimum_size = Vector2(14, 14)
        symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        pair.add_child(symbol)
        var value: float = float(entries[resource])
        var amount := _label(_compact_amount(value) if resource == "Population" else _tons(value, 0), 11)
        amount.autowrap_mode = TextServer.AUTOWRAP_OFF
        pair.add_child(amount)
        pair.tooltip_text = ("%.0f people" % value) if resource == "Population" else "%.0f t %s" % [value, resource]

func _ship_stats(kind: String) -> String:
    var details: String = ""
    match kind:
        "ship": details = "Transports resources · Cargo %.0f t" % ECONOMY.CARGO_CAPACITY
        "colony_ship": details = "Settles a neutral system · %.0f settlers" % ECONOMY.COLONY_POPULATION
        "fighter": details = "Engages hostile ships · Damage %.0f · Range %.0f" % [ECONOMY.LASER_DAMAGE, ECONOMY.LASER_RANGE]
        "miner": details = "Extracts asteroids · Cargo %.0f t · Mining %.0f t/yr" % [ECONOMY.MINER_CAPACITY, ECONOMY.MINER_RATE]
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
    var row: HBoxContainer = disclosure["actions"]
    var maintained := _label("(0 / 0)", 11)
    maintained.autowrap_mode = TextServer.AUTOWRAP_OFF
    row.add_child(maintained)
    var maintain_row := HBoxContainer.new()
    body.add_child(maintain_row)
    var maintain_caption := _label("Maintain", 12)
    maintain_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
    maintain_row.add_child(maintain_caption)
    var amount := SpinBox.new()
    amount.min_value = 0
    amount.max_value = 9999
    amount.step = 1
    amount.custom_minimum_size = Vector2(72, 28)
    amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    amount.get_line_edit().add_theme_font_size_override("font_size", 12)
    amount.get_line_edit().text_changed.connect(_filter_ship_limit.bind(amount.get_line_edit()))
    maintain_row.add_child(amount)
    var ships_caption := _label("ships", 12)
    ships_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
    maintain_row.add_child(ships_caption)
    amount.value_changed.connect(func(value: float) -> void:
        session.call("request_maintain", selected, kind, int(value)))
    var infinity := _label("∞", 14)
    maintain_row.add_child(infinity)
    infinity.hide()
    infinity.mouse_filter = Control.MOUSE_FILTER_STOP
    infinity.gui_input.connect(func(event: InputEvent) -> void:
        if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and event.relative.y > 0.0:
            session.call("request_maintain", selected, kind, maxi(0, int(amount.value) - maxi(1, roundi(event.relative.y / 4.0)))))
    var button: Button = _card_action(disclosure, "Build", _operation.bind(kind))
    if kind != "yard":
        var check: Button = _repeat_button(row, kind)
        continuous_checks[kind] = check
    var cancel: Button = _card_cancel(disclosure, _cancel_kind.bind(kind, ""), build_progress)
    cancel.tooltip_text = "Cancel one order and stop repeat"
    disclosure.merge({"maintained": maintained, "maintain_amount": amount, "infinity": infinity, "button": button, "cancel": cancel, "title": title_text, "requirements": requirements, "costs": costs, "build_progress": build_progress})
    build_cards[kind] = disclosure
    return button

func _filter_ship_limit(value: String, field: LineEdit) -> void:
    var digits: String = ""
    var caret: int = 0
    for i in range(value.length()):
        var character: String = value.substr(i, 1)
        if character >= "0" and character <= "9" and digits.length() < 4:
            digits += character
            if i < field.caret_column:
                caret += 1
    if digits != value:
        field.text = digits
        field.caret_column = caret

func _repeat_button(parent: Container, key: String) -> Button:
    if repeat_icon == null:
        var image := Image.new()
        image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#dbeaff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 2l4 4-4 4M3 11V9a3 3 0 0 1 3-3h15M7 22l-4-4 4-4M21 13v2a3 3 0 0 1-3 3H3"/></svg>')
        repeat_icon = ImageTexture.create_from_image(image)
    var button := Button.new()
    button.icon = repeat_icon
    button.expand_icon = true
    button.toggle_mode = true
    button.custom_minimum_size = Vector2(24, 26)
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
    for column in [["Stock", 62], ["Lv", 22], ["/yr", 55], ["Bonus", 46]]:
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
        stock.custom_minimum_size.x = 62
        stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(stock)
        var level := _label("", 11)
        level.autowrap_mode = TextServer.AUTOWRAP_OFF
        level.custom_minimum_size.x = 22
        level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(level)
        var rate_label := _label("", 11)
        rate_label.autowrap_mode = TextServer.AUTOWRAP_OFF
        rate_label.custom_minimum_size.x = 55
        rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(rate_label)
        var bonus := _label("", 11)
        bonus.autowrap_mode = TextServer.AUTOWRAP_OFF
        bonus.custom_minimum_size.x = 46
        bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(bonus)
        production_values[resource] = {"row": row, "stock": stock, "level": level, "rate": rate_label, "bonus": bonus}

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
    var warehouse_button: Button = _card_action(warehouse_card, "Upgrade", _operation.bind("economy", "warehouse"))
    warehouse_card["cancel"] = _card_cancel(warehouse_card, func() -> void: pass)
    HUD.action(warehouse_button)
    warehouse_card.merge({"button": warehouse_button, "detail": warehouse_detail, "costs": _cost_grid(warehouse)})
    var habitat_section: VBoxContainer = HUD.section(parent, "")
    habitat_section.get_child(0).hide()
    habitation_card = _make_disclosure(habitat_section, "Habitation technology")
    var habitat_body: VBoxContainer = habitation_card["body"]
    var habitat_detail: Label = _label("", 12)
    habitat_body.add_child(habitat_detail)
    habitation_card.merge({"button": _card_action(habitation_card, "Upgrade", _operation.bind("economy", "habitation")), "detail": habitat_detail, "costs": _cost_grid(habitat_body)})
    HUD.action(habitation_card["button"])
    habitation_card["repeat"] = _repeat_button(habitation_card["actions"], "habitation")
    warehouse_card["repeat"] = _repeat_button(warehouse_card["actions"], "warehouse")
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
        var button: Button = _card_action(disclosure, "Build", _operation.bind("economy", resource))
        var progress := ProgressBar.new()
        section.add_child(progress)
        section.move_child(progress, card.get_index())
        progress.hide()
        disclosure["progress"] = progress
        disclosure["cancel"] = _card_cancel(disclosure, _cancel_kind.bind("economy_building", resource), progress)
        disclosure["repeat"] = _repeat_button(disclosure["actions"], "economy_building:" + resource)
        HUD.action(button)
        disclosure.merge({"button": button, "detail": detail, "costs": _cost_grid(card)})
        economy_cards[resource] = disclosure

func _refresh_economy_cards(p: Dictionary, owned: bool) -> void:
    var habitat_level: int = int(p.get("habitation_level", 0))
    _disclosure_title(habitation_card, "Habitation technology · Lv %d" % habitat_level)
    var penalty: float = -100.0 * clampf(float(p["population"]) / ECONOMY.habitation_capacity(p), 0.0, 1.0)
    var next_penalty: float = -100.0 * clampf(float(p["population"]) / (2.0 * ECONOMY.habitation_capacity(p)), 0.0, 1.0)
    habitation_card["detail"].text = "Overpopulation penalty %+.1f%%" % penalty
    if habitat_level < 3:
        habitation_card["detail"].text += " → %+.1f%%" % next_penalty
    _sync_repeat(habitation_card["repeat"], p, "habitation", owned and habitat_level < 3)
    habitation_card["button"].disabled = not owned or not ECONOMY.habitation_available(p)
    habitation_card["button"].text = "Max" if habitat_level >= 3 else "Upgrade"
    habitation_card["costs"].visible = habitat_level < 3
    _show_cost(habitation_card["costs"], ECONOMY.habitation_cost(p))
    var level: int = int(p.get("warehouse_level", 0))
    var warehouse_button: Button = warehouse_card["button"]
    _sync_repeat(warehouse_card["repeat"], p, "warehouse", owned and level < 3)
    warehouse_button.disabled = not owned or not ECONOMY.warehouse_available(p)
    warehouse_button.text = "Max" if level >= 3 else "Upgrade"
    var warehouse_detail: String = "%s / resource" % _tons(ECONOMY.storage_capacity(p), 0)
    if level < 3:
        warehouse_detail += " → %s" % _tons(float(ECONOMY.WAREHOUSE_CAPACITIES[level + 1]), 0)
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
        var installed: int = int(p.get("buildings", {}).get(resource, 0))
        var job: Dictionary = {}
        for item in p["queue"]:
            if item["kind"] == "economy_building" and item["target"] == resource:
                job = item
                break
        card["progress"].visible = not job.is_empty()
        card["cancel"].visible = not job.is_empty()
        card["cancel"].disabled = not owned or job.is_empty()
        if not job.is_empty():
            card["progress"].value = 100.0 * float(job["progress"]) / float(job["work"])
            _style_progress(card["progress"], p, job)
        var button: Button = card["button"]
        _sync_repeat(card["repeat"], p, "economy_building:" + resource, owned and ECONOMY.production_available(p, resource))
        button.text = "Build"
        button.disabled = not owned or not ECONOMY.building_available(p, resource)
        var cost: String = _cost_text(ECONOMY.building_cost(p, resource))
        var requirement: String = "%s population" % _compact_amount(float(definition["population"]))
        var unmet: PackedStringArray = []
        if job.is_empty():
            if float(p["population"]) + ECONOMY.EPS < float(definition["population"]):
                unmet.append("Requires " + requirement)
            if not ECONOMY.production_available(p, resource):
                unmet.append("No local deposit")
            if not ECONOMY.affordable(p, definition["cost"]):
                unmet.append("Insufficient local materials")
        card["detail"].text = "\n".join(unmet)
        card["detail"].visible = not unmet.is_empty()
        card["costs"].visible = true
        _show_cost(card["costs"], ECONOMY.building_cost(p, resource))
        _disclosure_title(card, str(definition["name"]) + " · %d" % installed)
        button.tooltip_text = "%s\n%s" % [requirement, cost]

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
        section.add_child(progress)
        section.move_child(progress, card.get_index())
        var actions: HBoxContainer = disclosure["actions"]
        var action: Button = _card_action(disclosure, "Upgrade", _operation.bind("production", resource))
        var cancel: Button = _card_cancel(disclosure, _cancel_kind.bind("production", resource), progress)
        HUD.action(action)
        var repeat: Button = _repeat_button(actions, "production:" + resource)
        disclosure.merge({"title": disclosure["header"], "name": labels[resource], "detail": detail, "progress": progress, "button": action, "cancel": cancel, "repeat": repeat, "costs": _cost_grid(card)})
        upgrade_cards[resource] = disclosure
    var section: VBoxContainer = HUD.section(parent, "")
    section.get_child(0).hide()
    pds_card = _make_disclosure(section, "Planetary defense")
    var body: VBoxContainer = pds_card["body"]
    var detail := _label("", 12)
    body.add_child(detail)
    var progress := ProgressBar.new()
    progress.custom_minimum_size.y = 15
    section.add_child(progress)
    section.move_child(progress, body.get_index())
    var costs: GridContainer = _cost_grid(body)
    var action: Button = _card_action(pds_card, "Build", func() -> void: _operation("pds", str(ECONOMY.next_pds(_planet()))))
    var cancel: Button = _card_cancel(pds_card, _pds_action, progress)
    HUD.action(action)
    pds_card.merge({"detail": detail, "progress": progress, "costs": costs, "button": action, "cancel": cancel})

func _pds_action() -> void:
    var job: Dictionary = ECONOMY.pds_job(_planet())
    if job.is_empty():
        _operation("pds", str(ECONOMY.next_pds(_planet())))
    else:
        session.call("request_cancel", selected, int(job["id"]))

func _refresh_pds(planet: Dictionary, owned: bool) -> void:
    var count: int = planet.get("pds", {}).size()
    var limit: int = int(planet["planet_count"])
    var slot: int = ECONOMY.next_pds(planet)
    var job: Dictionary = ECONOMY.pds_job(planet)
    _disclosure_title(pds_card, "Planetary defense · %d/%d" % [count, limit])
    var progress: ProgressBar = pds_card["progress"]
    progress.visible = not job.is_empty()
    var action: Button = pds_card["button"]
    action.text = "Build" if slot >= 0 else "Complete"
    action.disabled = not owned or slot < 0 or not job.is_empty()
    pds_card["cancel"].visible = not job.is_empty()
    pds_card["cancel"].disabled = not owned or job.is_empty()
    pds_card["detail"].text = "One battery per planet · %.0f damage / shot · Range %.0f · Fires once/yr" % [ECONOMY.PDS_DAMAGE, ECONOMY.LASER_RANGE]
    pds_card["costs"].visible = slot >= 0 or not job.is_empty()
    if not job.is_empty():
        progress.value = 100.0 * float(job["progress"]) / float(job["work"])
        progress.tooltip_text = _cost_text(job["cost"], job["allocated"])
        _style_progress(progress, planet, job)
        _show_cost(pds_card["costs"], job["cost"])
    elif slot >= 0:
        _show_cost(pds_card["costs"], ECONOMY._cost("pds", slot + 1))

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
        _sync_repeat(card["repeat"], planet, "production:" + resource, owned and available)
        if not job.is_empty():
            progress.value = 100.0 * float(job["progress"]) / float(job["work"])
            progress.tooltip_text = _cost_text(job["cost"], job["allocated"])
            _style_progress(progress, planet, job)
            detail.text = "+1 production level · %.0f work\n%.0f%% complete%s" % [float(job["work"]), progress.value, " · Waiting" if ECONOMY._possible(planet, job) <= ECONOMY.EPS else ""]
            _show_cost(card["costs"], job["cost"])
            button.text = "Upgrade"
            button.disabled = true
            card["cancel"].show()
            card["cancel"].disabled = not owned
        else:
            button.text = "Upgrade"
            button.disabled = not owned or not unlocked
            card["cancel"].hide()
            card["cancel"].disabled = true
            if not available:
                detail.text = "No local deposit"
            else:
                var minimum: int = ECONOMY.production_population(resource, level + 1)
                var upgraded: Dictionary = planet.duplicate(true)
                upgraded["levels"][resource] = level + 1
                detail.text = "Output %.2f → %.2f t/yr · %.0f yr" % [ECONOMY.rate(planet, resource), ECONOMY.rate(upgraded, resource), ECONOMY._work("production", level + 1)]
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
        ship_detail.text = "Metals ~%d%% · %s\nCrystals ~%d%% · %s" % [metals, _tons(float(stock["Metals"])), 100 - metals, _tons(float(stock["Crystals"]))]
    var access_names: PackedStringArray = []
    for anchor in ECONOMY.field_access_systems(state["map"], field):
        access_names.append(_system_name(anchor))
    ship_detail.tooltip_text = "%d chunks remaining · Access: %s" % [field["chunks"].size(), ", ".join(access_names)]
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
    elif kind == "miner" and mode == "delivery":
        status = "Waiting for storage"
    elif kind == "miner" and mode == "idle":
        status = "Waiting for accessible ore / storage"
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
        ship_cargo.get_child(0).text = "Cargo %.1f / %.0f t" % [ECONOMY._cargo_total(ship), cargo_capacity]
        for resource in ECONOMY.RESOURCES:
            ship_cargo_labels[resource].text = _tons(float(ship["cargo"].get(resource, 0.0)))
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
            fleet_cargo_labels[resource].text = _tons(amount)
            fleet_cargo_labels[resource].tooltip_text = "%.1f t" % amount
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

var diagnostic_label: Label
var diagnostic_elapsed: float = 0.0
var diagnostic_last_bytes: int = -1

func _build_time_controls() -> void:
    var panel := PanelContainer.new()
    add_child(panel)
    panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928ed"), Color("#284661"), 4))
    panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    panel.offset_left = -260
    panel.offset_right = -8
    panel.offset_top = HEADER_HEIGHT + 16
    panel.offset_bottom = HEADER_HEIGHT + 56
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    panel.add_child(row)
    for speed in [0, 1, 2, 5, 10]:
        var label: String = "Ⅱ" if speed == 0 else "%d×" % speed
        var button: Button = _button(label, _set_time_speed.bind(int(speed)), row)
        button.toggle_mode = true
        button.focus_mode = Control.FOCUS_NONE
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        time_buttons[speed] = button
    var diagnostics: Button = _button("Perf", func() -> void: diagnostic_label.visible = not diagnostic_label.visible, row)
    diagnostics.tooltip_text = "Toggle local performance diagnostics"
    diagnostic_label = _label("", 11)
    add_child(diagnostic_label)
    diagnostic_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    diagnostic_label.offset_left = -220
    diagnostic_label.offset_right = 220
    diagnostic_label.offset_top = -76
    diagnostic_label.offset_bottom = -52
    diagnostic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    diagnostic_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    diagnostic_label.hide()

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
    policy_selected = ""
    _refresh()
    military_drag = -1
    military_preview.clear()
    active_lens = "" if active_lens == kind else kind
    military_lens.set_pressed_no_signal(active_lens == "military")
    logistics_lens.set_pressed_no_signal(active_lens == "logistics")
    map_canvas.queue_redraw()

func _draw_resource_fill(strip: Control, resource: String) -> void:
    var fraction: float = float(global_resource_fills.get(resource, 0.0))
    var segments: Array = global_resource_segments.get(resource, [])
    strip.draw_rect(Rect2(Vector2.ZERO, strip.size), Color("#081421"))
    if fraction <= 0.0 or segments.is_empty():
        return
    var width: float = strip.size.x * fraction
    strip.draw_rect(Rect2(Vector2.ZERO, Vector2(width, strip.size.y)), Color(HUD.COLORS.get(resource, Color("#b9d9ed")), 0.38))
    var font: Font = ThemeDB.fallback_font
    var x: float = 0.0
    for i in range(segments.size()):
        var segment: Dictionary = segments[i]
        var w: float = width * float(segment["share"])
        if i > 0:
            strip.draw_line(Vector2(x, 0), Vector2(x, strip.size.y), Color("#081421"), 1.0)
        var name_text: String = segment["name"]
        var text_width: float = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
        if text_width + 6.0 > w:
            name_text = name_text.left(2)
            text_width = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
        if text_width + 6.0 > w:
            name_text = name_text.left(1)
            text_width = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
        if segments.size() > 1 and text_width + 6.0 <= w:
            strip.draw_string(font, Vector2(x + (w - text_width) * 0.5, (strip.size.y - font.get_height(10)) * 0.5 + font.get_ascent(10)), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e3edf7"))
        x += w

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
uniform sampler2D occupied_tiles : filter_nearest, repeat_disable;
uniform vec2 tile_grid = vec2(1.0);
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
    ivec2 tile = ivec2(clamp(floor(UV * tile_grid), vec2(0.0), tile_grid - vec2(1.0)));
    if (texelFetch(occupied_tiles, tile, 0).r < 0.5) {
        discard;
    }
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
    var extent: Vector2 = _map_size() / territory_radius + Vector2.ONE * 3.0
    _cache_territory_tiles(sites, extent)
    territory_material.set_shader_parameter("world_extent", extent)
    territory_material.set_shader_parameter("padding", 1.5)
    territory_image.show()
    _position_territory()

# Conservative tile mask: a smooth-min operation can lower the distance
# by at most k/4 per site. Leave additional room for antialiasing.
# Occupied pixels still evaluate the original continuous shader exactly.
func _cache_territory_tiles(sites: Array[Color], extent: Vector2) -> void:
    var dimensions := Vector2i(maxi(1, ceili(extent.x)), maxi(1, ceili(extent.y)))
    var cell: Vector2 = extent / Vector2(dimensions)
    var mask: Image = Image.create_empty(dimensions.x, dimensions.y, false, Image.FORMAT_R8)
    mask.fill(Color.BLACK)
    var counts: Dictionary = {}
    for site in sites:
        if site.a > 0.0:
            var team: int = roundi(site.a)
            counts[team] = int(counts.get(team, 0)) + 1
    for site in sites:
        if site.a <= 0.0:
            continue
        var reach: float = site.b + 0.12 * float(counts[roundi(site.a)]) + 2.0
        var center := Vector2(site.r, site.g) + Vector2.ONE * 1.5
        var low: Vector2 = (center - Vector2.ONE * reach) / cell
        var high: Vector2 = (center + Vector2.ONE * reach) / cell
        for y in range(maxi(0, floori(low.y)), mini(dimensions.y - 1, floori(high.y)) + 1):
            for x in range(maxi(0, floori(low.x)), mini(dimensions.x - 1, floori(high.x)) + 1):
                mask.set_pixel(x, y, Color.WHITE)
    territory_material.set_shader_parameter("occupied_tiles", ImageTexture.create_from_image(mask))
    territory_material.set_shader_parameter("tile_grid", Vector2(dimensions))

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
        var stack := VBoxContainer.new()
        stack.add_theme_constant_override("separation", 2)
        tile.add_child(stack)
        var line := HBoxContainer.new()
        stack.add_child(line)
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
        var strip := Control.new()
        strip.custom_minimum_size.y = 14.0
        strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
        stack.add_child(strip)
        global_resource_strips[resource] = strip
        global_resource_segments[resource] = []
        strip.draw.connect(_draw_resource_fill.bind(strip, resource))

func _global_stat(parent: Container, value: String, tint: Color, population: bool = false) -> Label:
    var tile := PanelContainer.new()
    tile.add_theme_stylebox_override("panel", HUD.surface(Color("#122337"), Color("#284661"), 4, 3))
    parent.add_child(tile)
    var label := _label(value, 12)
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.add_theme_color_override("font_color", tint)
    label.mouse_filter = Control.MOUSE_FILTER_PASS
    if population:
        tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.clip_text = true
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var stack := VBoxContainer.new()
        stack.add_theme_constant_override("separation", 2)
        tile.add_child(stack)
        _population_row(stack).add_child(label)
        var strip := Control.new()
        strip.custom_minimum_size = Vector2(0, 14)
        strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
        stack.add_child(strip)
        global_resource_tiles["population"] = tile
        global_resource_strips["population"] = strip
        strip.draw.connect(_draw_resource_fill.bind(strip, "population"))
    else:
        tile.add_child(label)
    return label

func _tons(value: float, decimals: int = 1, compact: bool = false) -> String:
    var magnitude: float = absf(value)
    var scale: float = 1.0
    var unit: String = "t"
    if magnitude >= 1000000000.0:
        scale = 1000000000.0
        unit = "Gt"
    elif magnitude >= 1000000.0:
        scale = 1000000.0
        unit = "Mt"
    elif magnitude >= 1000.0:
        scale = 1000.0
        unit = "kt"
    var number: String = "%.1f" % (value / scale) if scale > 1.0 or decimals == 1 else "%.0f" % value
    return number + ("" if compact else " ") + unit

func _compact_amount(value: float) -> String:
    if value >= 1000000000.0:
        return "%.1fB" % (value / 1000000000.0)
    if value >= 1000000.0:
        return "%.1fM" % (value / 1000000.0)
    if value >= 1000.0:
        return "%.1fK" % (value / 1000.0)
    return "%.0f" % value

func _build_resource_hover() -> void:
    resource_hover_panel = PanelContainer.new()
    resource_hover_panel.z_index = 50
    resource_hover_panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928"), Color("#42647e"), 9))
    add_child(resource_hover_panel)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    resource_hover_panel.add_child(scroll)
    resource_hover_label = _label("", 12)
    resource_hover_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    resource_hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    scroll.add_child(resource_hover_label)
    resource_hover_panel.hide()

func _flow_name(category: String) -> String:
    if category.begins_with("Construction: "):
        var kind: String = category.trim_prefix("Construction: ")
        match kind:
            "ship": return "Logistics ships"
            "yard": return "Shipyard builds"
            "yard_upgrade": return "Shipyard upgrades"
            "production": return "Production upgrades"
            "pds": return "Planetary defense"
            _: return kind.replace("_", " ").capitalize() + " builds"
    return category

func _resource_breakdown(state: Dictionary, resource: String) -> String:
    if resource == "population":
        var lines: PackedStringArray = ["Population · %.0f people" % float(ECONOMY.empire_totals(state, _me())["population"]), "Current local growth (people/yr)"]
        for i in range(state["planets"].size()):
            var p: Dictionary = state["planets"][i]
            if int(p["owner"]) != _me():
                continue
            var growth: float = float(p.get("demographic_rate", ECONOMY.population_growth(p)))
            var crew: float = float(p.get("crew_rate", 0.0))
            lines.append("%s · %.0f · %+.2f/yr\n  %+.2f demographic · %+.2f crews · %+.1f%% overpopulation penalty" % [_system_name(i), float(p["population"]), growth - crew, growth, -crew, -100.0 * clampf(float(p["population"]) / ECONOMY.habitation_capacity(p), 0.0, 1.0)])
        return "\n".join(lines)
    var totals: Dictionary = ECONOMY.empire_totals(state, _me())
    var lines: PackedStringArray = ["%s  ·  %.2f t stored" % [resource, float(totals["stock"][resource])],
        "%.2f t in transit  /  %.0f t storage" % [float(totals["cargo"][resource]), float(totals["storage_reference"][resource])],
        "Current local flows (t/yr)"]
    for i in range((state.get("planets", []) as Array).size()):
        var p: Dictionary = state["planets"][i]
        if int(p["owner"]) != _me():
            continue
        var parts: PackedStringArray = []
        var categories: Array = ["Production", "Population", "Mining deliveries", "Imports", "Exports"]
        for category in p.get("flows", {}):
            if not categories.has(category):
                categories.append(category)
        var net: float = 0.0
        for category in categories:
            var amount: float = ECONOMY.local_flow(p, category, resource)
            if amount <= ECONOMY.EPS:
                continue
            var sign: float = -1.0 if category == "Population" or category == "Exports" or str(category).begins_with("Construction: ") else 1.0
            net += sign * amount
            parts.append("%+.2f %s" % [sign * amount, _flow_name(category)])
        lines.append("%s  %+.2f" % [_system_name(i), net])
        if not parts.is_empty():
            lines.append("  " + " · ".join(parts))
    if int(state.get("time_speed", 1)) == 0:
        lines.append("Paused · last simulation step")
    return "\n".join(lines)

func _local_breakdown(p: Dictionary, resource: String) -> String:
    if resource == "population":
        var growth: float = float(p.get("demographic_rate", ECONOMY.population_growth(p)))
        var crew: float = float(p.get("crew_rate", 0.0))
        return "%s · %.0f people\n%+.2f/yr net\n%+.2f demographic change\n%+.2f ship crews\nOverpopulation penalty: %+.1f%%\nOrganics: %.2f produced / %.2f consumed per year" % [_system_name(selected), float(p["population"]), growth - crew, growth, -crew, -100.0 * clampf(float(p["population"]) / ECONOMY.habitation_capacity(p), 0.0, 1.0), ECONOMY.rate(p, "Organics"), ECONOMY.consumption(p, "Organics")]
    var lines: PackedStringArray = ["%s · %.2f t stored" % [resource, float(p["stock"][resource])], "Latest local flows (t/yr)"]
    var categories: Array = ["Production", "Population", "Mining deliveries", "Imports", "Exports"]
    for category in p.get("flows", {}):
        if not categories.has(category):
            categories.append(category)
    var net: float = 0.0
    for category in categories:
        var amount: float = ECONOMY.local_flow(p, category, resource)
        var sign: float = -1.0 if category == "Population" or category == "Exports" or str(category).begins_with("Construction: ") else 1.0
        net += sign * amount
        if amount > ECONOMY.EPS:
            lines.append("%+.2f %s" % [sign * amount, _flow_name(category)])
    lines.append("%+.2f net" % net)
    return "\n".join(lines)

func _update_resource_hover() -> void:
    if not is_instance_valid(resource_hover_panel):
        return
    var mouse: Vector2 = get_global_mouse_position()
    var resource: String = ""
    for key in global_resource_tiles:
        if global_resource_tiles[key].get_global_rect().has_point(mouse):
            resource = key
            break
    if resource.is_empty() and planet_overview.is_visible_in_tree() and not _planet().is_empty():
        if population_label.get_parent().get_global_rect().has_point(mouse):
            resource = "local:population"
        else:
            for key in production_values:
                if production_values[key]["row"].get_global_rect().has_point(mouse):
                    resource = "local:" + str(key)
                    break
    if resource.is_empty() and resource_hover_panel.visible and resource_hover_panel.get_global_rect().has_point(mouse):
        resource = hovered_resource
    if resource.is_empty() or _state().is_empty():
        resource_hover_panel.hide()
        hovered_resource = ""
        return
    var state: Dictionary = _state()
    var local: bool = resource.begins_with("local:")
    if local and (_planet().is_empty() or not planet_overview.is_visible_in_tree()):
        resource_hover_panel.hide()
        hovered_resource = ""
        return
    var value: String = _local_breakdown(_planet(), resource.trim_prefix("local:")) if local else _resource_breakdown(state, resource)
    if resource_hover_label.text != value:
        resource_hover_label.text = value
    hovered_resource = resource
    var tile_rect: Rect2
    if local:
        tile_rect = population_label.get_parent().get_global_rect() if resource == "local:population" else production_values[resource.trim_prefix("local:")]["row"].get_global_rect()
    else:
        tile_rect = global_resource_tiles[resource].get_global_rect()
    var viewport: Vector2 = get_viewport_rect().size
    var width: float = minf(420.0, viewport.x - 16.0)
    resource_hover_panel.size = Vector2(width, minf(viewport.y - tile_rect.end.y - 12.0, maxf(105.0, 20.0 * float(value.count("\n") + 2))))
    resource_hover_panel.global_position = Vector2(clampf(tile_rect.position.x, 8.0, viewport.x - width - 8.0), tile_rect.end.y)
    resource_hover_panel.show()

func _refresh_global_bar(state: Dictionary) -> void:
    year_label.text = "YEAR  %d" % ECONOMY.current_year(state)
    year_label.tooltip_text = "One game year per simulation second"
    var totals: Dictionary = ECONOMY.empire_totals(state, _me())
    var rates: Dictionary = state.get("resource_rates", {}).get(_me(), {})
    for resource in ECONOMY.RESOURCES:
        var value: float = float(totals["resources"][resource])
        var rate: float = float(rates.get(resource, 0.0))
        var magnitude: String = _tons(absf(rate), 1, true)
        var rate_text: String = ("-" if rate < -0.05 else "+") + magnitude
        global_resource_labels[resource].text = "%s (%s)" % [_tons(value, 0, true), rate_text]
        var stored: float = float(totals["stock"][resource])
        var reference: float = float(totals["storage_reference"][resource])
        global_resource_fills[resource] = clampf(stored / reference, 0.0, 1.0) if reference > 0.0 else 0.0
        var tile: PanelContainer = global_resource_tiles[resource]
        var segments: Array = []
        if stored > ECONOMY.EPS:
            for i in range(state.get("planets", []).size()):
                var planet: Dictionary = state["planets"][i]
                if int(planet["owner"]) != _me():
                    continue
                var quantity: float = float(planet["stock"][resource])
                if quantity > 0.0:
                    segments.append({"name": _system_name(i), "share": quantity / stored, "index": i})
            segments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["share"] > b["share"] if a["share"] != b["share"] else a["index"] < b["index"])
        global_resource_segments[resource] = segments
        global_resource_strips[resource].queue_redraw()
        tile.tooltip_text = ""
    global_population_label.text = "%s" % _compact_amount(float(totals["population"]))
    var population_total: float = float(totals["population"])
    var population_segments: Array = []
    var population_net: float = 0.0
    for i in range(state.get("planets", []).size()):
        var p: Dictionary = state["planets"][i]
        if int(p["owner"]) != _me():
            continue
        population_net += float(p.get("demographic_rate", ECONOMY.population_growth(p))) - float(p.get("crew_rate", 0.0))
        if population_total > 0.0 and float(p["population"]) > 0.0:
            population_segments.append({"name": _system_name(i), "share": float(p["population"]) / population_total, "index": i})
    population_segments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["share"] > b["share"] if a["share"] != b["share"] else a["index"] < b["index"])
    global_population_label.text = "%s (%+.0f/yr)" % [_compact_amount(population_total), population_net]
    global_population_label.tooltip_text = ""
    global_resource_segments["population"] = population_segments
    global_resource_fills["population"] = 1.0 if population_total > 0.0 else 0.0
    global_resource_strips["population"].queue_redraw()

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
        trade_stock_labels[resource].text = "%s / %s" % [_tons(stock), _tons(capacity, 0)]
        trade_stock_labels[resource].tooltip_text = "%.1f / %.0f t" % [stock, capacity]
        slider.tooltip_text = "Import below the left handle; export above the right handle. 100%% = %.0f units." % capacity
        # Preserve this handle while dragging, even when a snapshot arrives.
        if slider.active_handle < 0:
            var t: Dictionary = p["thresholds"][resource]
            slider.import_enabled = bool(t.get("import", true))
            slider.export_enabled = bool(t.get("export", true))
            trade_checks[resource][0].set_pressed_no_signal(slider.import_enabled)
            trade_checks[resource][1].set_pressed_no_signal(slider.export_enabled)
            trade_checks[resource][0].text = "Import %d%%" % roundi(float(t["min"]))
            trade_checks[resource][1].text = "Export %d%%" % roundi(float(t["max"]))
            slider.queue_redraw()
            if not is_equal_approx(slider.lower, float(t["min"])) or not is_equal_approx(slider.upper, float(t["max"])):
                slider.set_range(float(t["min"]), float(t["max"]))

func _apply_thresholds(minimum: float, maximum: float, resource: String) -> void:
    var slider: TradeRange = trade_sliders[resource]
    session.call("request_thresholds", selected, resource, minimum, maximum, slider.import_enabled, slider.export_enabled)

func _trade_toggle(_pressed: bool, resource: String) -> void:
    var slider: TradeRange = trade_sliders[resource]
    slider.import_enabled = trade_checks[resource][0].button_pressed
    slider.export_enabled = trade_checks[resource][1].button_pressed
    if slider.import_enabled and slider.export_enabled and slider.lower > slider.upper:
        slider.upper = slider.lower
    slider.queue_redraw()
    _apply_thresholds(slider.lower, slider.upper, resource)

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
    _refresh_policy_ui(state)
    if not policy_draft_card.is_empty():
        for child in policy_hidden_ui:
            if is_instance_valid(child):
                child.hide()
    menu_exit.text = "Main menu" if bool(session.get("is_solo")) else ("Return to lobby" if multiplayer.is_server() else "Leave match")
    if phase == "loading" and multiplayer.is_server():
        menu_exit.text = "Cancel start"
    var planets: Array = state.get("planets", [])
    if not initial_selection_done and not planets.is_empty():
        initial_selection_done = true
        for i in range(planets.size()):
            if int(planets[i]["owner"]) == _me():
                selected = i
                # Center the initial camera on the player's home system.
                zoom = clampf(2.4, MIN_ZOOM, MAX_ZOOM)
                pan = (_map_size() * 0.5 - state["map"]["points"][i]) * _fit() * zoom
                _position_territory()
                _load_thresholds()
                break
    var ship: Dictionary = _selected_ship(state)
    if ship.is_empty():
        selected_ship_id = -1
    var p: Dictionary = _planet()
    var field_selected: bool = selected_field >= 0 and ECONOMY.discovered(state, _me(), "fields", selected_field)
    var ship_selected: bool = not ship.is_empty()
    var other_selected: bool = ship_selected or field_selected
    inspector_panel.visible = policy_draft_card.is_empty() and policy_selected.is_empty() and (not p.is_empty() or other_selected)
    overview_panel.visible = policy_draft_card.is_empty() and (not p.is_empty() or other_selected)
    planet_overview.visible = not other_selected
    var own_system: bool = not p.is_empty() and int(p.get("owner", -1)) == _me()
    inspector_tabs.visible = not other_selected and own_system
    var current_system: int = selected if not other_selected and not p.is_empty() else -1
    if current_system != last_system_tab_selection:
        if current_system >= 0:
            inspector_tabs.current_tab = 0
        _collapse_details()
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
        for resource in trade_checks:
            for check in trade_checks[resource]:
                check.disabled = not owned
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
        population_delta_label.text = ""
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
        production_values[resource]["stock"].text = _tons(amount)
        production_values[resource]["stock"].tooltip_text = "%.1f t %s stored" % [amount, resource]
        production_values[resource]["level"].text = str(int(p["levels"][resource]))
        var percent: int = roundi(100.0 * ECONOMY.production_modifier(p, resource))
        var bonus: Label = production_values[resource]["bonus"]
        bonus.text = "—" if percent == 100 else "%d%%" % (percent - 100) if percent < 100 else "+%d%%" % (percent - 100)
        bonus.add_theme_color_override("font_color", HUD.ACCENT if percent > 100 else (Color("#e4a479") if percent < 100 else HUD.MUTED))
        bonus.tooltip_text = "%.1f%% of baseline output" % (100.0 * ECONOMY.production_modifier(p, resource))
        var annual: float = ECONOMY.net_rate(p, resource)
        production_values[resource]["rate"].text = _tons(annual, 1, true)
        production_values[resource]["rate"].tooltip_text = "Production %.2f t/yr · Consumption %.2f t/yr · Net %.2f t/yr" % [ECONOMY.rate(p, resource), ECONOMY.consumption(p, resource), annual]
    var population: float = float(p["population"])
    population_label.text = "%s" % _compact_amount(population)
    var change: float = float(p.get("demographic_rate", ECONOMY.population_growth(p))) - float(p.get("crew_rate", 0.0))
    population_delta_label.text = "(%s%s/yr)" % ["+" if change >= 0.0 else "-", _compact_amount(absf(change))]
    population_delta_label.add_theme_color_override("font_color", Color("#7cdb9b") if change >= 0.0 else Color("#eb8585"))
    population_label.tooltip_text = ""
    _update_trade_stock(p)
    _refresh_upgrade_cards(p, owned)
    _refresh_pds(p, owned)
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

func _cancel_yard_at(index: int) -> void:
    if index < 0:
        _cancel_job(-index)
    elif index < 100:
        _cancel_kind("yard_upgrade", str(index))

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
            var vacant_cancel: Button = _button("×", func() -> void: pass, header)
            vacant_cancel.custom_minimum_size = Vector2(23, 22)
            vacant_cancel.disabled = true
            vacant_cancel.tooltip_text = "No construction to cancel"
            var costs := GridContainer.new()
            costs.columns = 3
            row.add_child(costs)
            var progress := ProgressBar.new()
            progress.step = 0.0
            progress.custom_minimum_size.y = 16
            row.add_child(progress)
            var disclosure: Dictionary = _make_disclosure(row, "Upgrade")
            var upgrade_detail := _label("", 11)
            disclosure["body"].add_child(upgrade_detail)
            var upgrade_costs: GridContainer = _cost_grid(disclosure["body"])
            var actions: HBoxContainer = disclosure["actions"]
            var upgrade: Button = _card_action(disclosure, "Upgrade", _upgrade_yard_at.bind(int(index)))
            var cancel: Button = _card_cancel(disclosure, _cancel_yard_at.bind(int(index)), progress)
            var repeat: Button = _repeat_button(actions, "yard_upgrade:" + str(index))
            upgrade.custom_minimum_size.y = 24
            upgrade.add_theme_font_size_override("font_size", 11)
            yard_activity.add_child(row)
            disclosure.merge({"row": row, "label": title, "progress": progress, "upgrade": upgrade, "cancel": cancel, "vacant_cancel": vacant_cancel, "repeat": repeat, "build": build, "costs": costs, "upgrade_detail": upgrade_detail, "upgrade_costs": upgrade_costs})
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
        yard_activity_rows[index]["vacant_cancel"].hide()
        if vacant:
            yard_activity_rows[index]["cancel"].hide()
        build.disabled = not can_build
        costs.visible = can_build
        yard_activity_rows[index]["actions"].visible = not vacant
        yard_activity_rows[index]["row"].visible = number <= p["yards"].size() + 1 if not p.is_empty() else false
        if vacant:
            _collapse_card(yard_activity_rows[index])
            label.text = "Shipyard %d" % number
            bar.visible = false
            upgrade.visible = false
            repeat.visible = false
            var recipe: Dictionary = ECONOMY._cost("yard", number)
            label.tooltip_text = _cost_text(recipe) + " · Requires %s population to operate" % _compact_amount(float(ECONOMY.SHIPYARD_POPULATION[number - 1]))
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
                    var amount: Label = _label(_tons(float(recipe[resource]), 0), 11)
                    amount.autowrap_mode = TextServer.AUTOWRAP_OFF
                    pair.add_child(amount)
                    pair.tooltip_text = "%.0f t %s" % [float(recipe[resource]), resource]
            continue
        bar.visible = true
        label.tooltip_text = ""
        var existing: bool = int(index) >= 0
        var level: int = int(p["yards"][index]["level"]) if existing else 1
        var pending: bool = existing and ECONOMY._has_job(p, "yard_upgrade", str(index))
        var owned: bool = int(p["owner"]) == _me() and str(session.get("phase")) == "match"
        var operating: bool = existing and ECONOMY.shipyard_operational(p, int(index))
        var cancelling: Button = yard_activity_rows[index]["cancel"]
        upgrade.visible = existing
        repeat.visible = existing
        cancelling.visible = not job.is_empty()
        cancelling.disabled = not owned or job.is_empty()
        if not job.is_empty():
            if cancelling.pressed.is_connected(_cancel_yard_at.bind(int(index))):
                cancelling.pressed.disconnect(_cancel_yard_at.bind(int(index)))
            if cancelling.has_meta("job_callback"):
                cancelling.pressed.disconnect(cancelling.get_meta("job_callback"))
            var callback: Callable = _cancel_job.bind(int(job["id"]))
            cancelling.set_meta("job_callback", callback)
            cancelling.pressed.connect(callback)
        _sync_repeat(repeat, p, "yard_upgrade:" + str(index), repeat.visible and str(session.get("phase")) == "match")
        upgrade.disabled = not owned or not existing or pending or not operating
        upgrade.text = "Upgrade"
        _disclosure_title(yard_activity_rows[index], "Upgrade to Lv %d" % (level + 1) if existing and not pending else ("Upgrade pending" if existing else "Construction details"))
        yard_activity_rows[index]["upgrade_detail"].text = "Build speed %.0f → %.0f work/yr · Max size %d → %d" % [ECONOMY.yard_speed(level), ECONOMY.yard_speed(level + 1), ECONOMY.max_size(level), ECONOMY.max_size(level + 1)] if existing else "Adds a shipyard · %.0f yr" % float(job["work"])
        if existing and not operating:
            yard_activity_rows[index]["upgrade_detail"].text += "\nRequires %s population" % _compact_amount(float(ECONOMY.SHIPYARD_POPULATION[index]))
        _show_cost(yard_activity_rows[index]["upgrade_costs"], ECONOMY._cost("yard_upgrade", level + 1) if existing else job["cost"])
        upgrade.tooltip_text = "Lv %d • %.0f t Metals • %.0f years" % [level, float(ECONOMY._cost("yard_upgrade", level + 1)["Metals"]), ECONOMY._work("yard_upgrade", level + 1)] if existing else _cost_text(job["cost"], job["allocated"])
        if job.is_empty():
            label.text = "Shipyard %d · Lv %d · %s" % [number, level, "Idle" if operating else "Offline"]
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
        if existing and not operating:
            bar.add_theme_stylebox_override("background", HUD.surface(Color("#33251a"), Color("#db9b54"), 0, 3))
            bar.set_meta("blocked", true)
            bar.tooltip_text = "Blocked: requires %s population" % _compact_amount(float(ECONOMY.SHIPYARD_POPULATION[index]))

func _job_name(item: Dictionary) -> String:
    match str(item["kind"]):
        "ship": return "Logistics ship"
        "pds": return "Planetary defense"
        "yard": return "New shipyard"
        "yard_upgrade": return "Shipyard %d → Lv %d" % [int(item["target"]) + 1, int(item["level"])]
        "production": return "%s → Lv %d" % [str(item["target"]), int(item["level"])]
        _: return str(item["kind"]).replace("_", " ").capitalize()

func _cost_text(cost: Dictionary, allocated: Dictionary = {}) -> String:
    var parts: PackedStringArray = []
    for resource in cost:
        if allocated.is_empty():
            parts.append("%.0f t %s" % [float(cost[resource]), resource])
        else:
            parts.append("%.0f / %.0f t %s" % [float(allocated.get(resource, 0.0)), float(cost[resource]), resource])
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
        card["button"].text = "Build"
        var finite: int = int(p.get("maintain", {}).get(kind, 0))
        var unlimited: bool = bool(p.get("continuous", {}).get(kind, false))
        var living: int = ECONOMY.origin_count(_state(), selected, kind) if not p.is_empty() else 0
        card["maintained"].text = "(%d / %s)" % [living, "∞" if unlimited else str(finite)]
        var amount: SpinBox = card["maintain_amount"]
        amount.editable = owned
        if not amount.get_line_edit().has_focus():
            amount.set_value_no_signal(finite)
        card["infinity"].visible = unlimited
        amount.visible = not unlimited
        _disclosure_title(card, card["title"].trim_prefix("BUILD ").capitalize() + (" (%d)" % count if count > 0 else ""))
        card["button"].tooltip_text = _cost_text(ECONOMY._cost(kind, 1)) + " · %.0f population" % float(ECONOMY.CREW_COSTS[kind])
        var requirements: PackedStringArray = []
        if not p.is_empty():
            if ECONOMY.operational_shipyards(p) == 0:
                requirements.append("Requires an operational shipyard")
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
        card["cancel"].visible = not job.is_empty()
        card["cancel"].disabled = not owned or count == 0

func _system_name(index: int) -> String:
    var names: Array = _state().get("map", {}).get("names", [])
    return str(names[index]) if index >= 0 and index < names.size() else "Unknown"

func _load_settings() -> void:
    settings.load("user://warbound_settings.cfg")
    ui_percent = clampi(int(settings.get_value("interface", "scale", 90)), 70, 130)
    music_volume = clampf(float(settings.get_value("audio", "music", 100.0)), 0.0, 100.0)
    sfx_volume = clampf(float(settings.get_value("audio", "sfx", 100.0)), 0.0, 100.0)
    music_muted = bool(settings.get_value("audio", "music_muted", false))
    sfx_muted = bool(settings.get_value("audio", "sfx_muted", false))

func _apply_settings() -> void:
    get_window().content_scale_factor = float(ui_percent) / 100.0
    for bus_name in ["Music", "SFX"]:
        var index: int = AudioServer.get_bus_index(bus_name)
        if index < 0:
            AudioServer.add_bus()
            index = AudioServer.bus_count - 1
            AudioServer.set_bus_name(index, bus_name)
        var volume: float = music_volume if bus_name == "Music" else sfx_volume
        AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, volume / 100.0)))
        AudioServer.set_bus_mute(index, music_muted if bus_name == "Music" else sfx_muted)
    upgrade_audio.bus = "SFX"

func _save_settings() -> void:
    settings.set_value("interface", "scale", ui_percent)
    settings.set_value("audio", "music", music_volume)
    settings.set_value("audio", "sfx", sfx_volume)
    settings.set_value("audio", "music_muted", music_muted)
    settings.set_value("audio", "sfx_muted", sfx_muted)
    settings.save("user://warbound_settings.cfg")
    _apply_settings()

func _build_settings_menu() -> void:
    var options := VBoxContainer.new()
    options.add_theme_constant_override("separation", 12)
    options.custom_minimum_size.x = 340
    match_menu.add_child(options)
    var scale_row := HBoxContainer.new()
    options.add_child(scale_row)
    var title := _label("UI scale", 14)
    title.autowrap_mode = TextServer.AUTOWRAP_OFF
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scale_row.add_child(title)
    var scale_value := OptionButton.new()
    scale_row.add_child(scale_value)
    for percent in range(70, 131, 10):
        scale_value.add_item("%d%%" % percent, percent)
    scale_value.select((ui_percent - 70) / 10)
    scale_value.item_selected.connect(func(index: int) -> void:
        ui_percent = scale_value.get_item_id(index)
        _save_settings())
    for channel in ["Music", "SFX"]:
        var row := HBoxContainer.new()
        options.add_child(row)
        row.add_theme_constant_override("separation", 10)
        var channel_label := _label(channel, 14)
        channel_label.autowrap_mode = TextServer.AUTOWRAP_OFF
        channel_label.custom_minimum_size.x = 64
        channel_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(channel_label)
        var volume := HSlider.new()
        volume.max_value = 100.0
        volume.step = 1.0
        volume.value = music_volume if channel == "Music" else sfx_volume
        volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        volume.custom_minimum_size = Vector2(120, 24)
        row.add_child(volume)
        var mute := CheckBox.new()
        mute.text = "Mute"
        mute.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        mute.custom_minimum_size.y = 30
        mute.button_pressed = music_muted if channel == "Music" else sfx_muted
        row.add_child(mute)
        volume.value_changed.connect(_audio_volume_changed.bind(channel))
        mute.toggled.connect(_audio_mute_changed.bind(channel))

func _audio_volume_changed(value: float, channel: String) -> void:
    if channel == "Music":
        music_volume = value
    else:
        sfx_volume = value
    _save_settings()

func _audio_mute_changed(value: bool, channel: String) -> void:
    if channel == "Music":
        music_muted = value
    else:
        sfx_muted = value
    _save_settings()

func _open_menu() -> void:
    drag_button = 0
    military_drag = -1
    military_preview.clear()
    match_menu.popup_centered(Vector2i(420, 190))

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
    _update_policy_zone_overlay()
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
    var angle: float = float(body["phase"]) + time * float(body["speed"]) * 0.22
    var orbit_radius: float = radius * float(body["orbit"])
    return Vector2(cos(angle) * orbit_radius, sin(angle) * orbit_radius * 0.65)

func _draw_elliptical_orbit(center: Vector2, radius: float, tint: Color) -> void:
    var points := PackedVector2Array()
    for step in range(65):
        var angle: float = TAU * float(step) / 64.0
        points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.65))
    map_canvas.draw_polyline(points, tint, 0.8, true)

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
    if index == selected and zoom >= 2.0 and radius >= 18.0:
        var bodies: Array = _system_visual(index, state)["bodies"]
        for slot in range(bodies.size()):
            var body: Dictionary = bodies[slot]
            var orbit: float = radius * float(body["orbit"])
            if _show_system_rings(index):
                _draw_elliptical_orbit(pos, orbit, Color(tint, 0.20))
            var point: Vector2 = pos + _body_position(body, radius, game_visual_clock)
            var body_radius: float = maxf(1.4, radius * float(body["size"]) * 0.55)
            if get_viewport_rect().grow(body_radius).has_point(point):
                if body_radius >= 5.0:
                    map_canvas.draw_texture_rect(_body_texture(body), Rect2(point - Vector2.ONE * body_radius, Vector2.ONE * body_radius * 2.0), false)
                else:
                    map_canvas.draw_circle(point, body_radius, HUD.COLORS.get(body["resource"], Color("#7d8b9b")).darkened(0.18), true)
                if system.get("pds", {}).has(slot):
                    _draw_pds_frame(point, body_radius)
    var pulse: float = 0.96 + 0.04 * sin(visual_clock * 1.2 + float(index))
    for layer in range(5, 0, -1):
        map_canvas.draw_circle(pos, star_radius * (1.0 + float(layer) * 0.33) * pulse, Color(star_color, 0.05), true)
    map_canvas.draw_circle(pos, star_radius * pulse, star_color, true)
    map_canvas.draw_circle(pos, star_radius * 0.55 * pulse, Color("#fffdf1"), true)
    if (zoom < 2.0 or radius < 18.0) and not system.get("pds", {}).is_empty():
        map_canvas.draw_arc(pos, star_radius + 3.0, -PI * 0.8, PI * 0.8, 18, Color("#bdcbd6"), 1.5, true)
    if _show_system_rings(index):
        map_canvas.draw_arc(pos, radius + 1.5, 0.0, TAU, 48, Color(tint, 0.65), 1.5, true)

# Thin metallic latitude/longitude ribs, clipped to the planet silhouette.
func _draw_pds_frame(center: Vector2, radius: float) -> void:
    var r: float = radius * 1.08
    var steel := Color("#c4d1dc")
    var shadow := Color("#344655")
    map_canvas.draw_arc(center, r, 0.0, TAU, 32, shadow, 2.0, true)
    map_canvas.draw_arc(center, r, 0.0, TAU, 32, steel, 1.0, true)
    if radius < 4.0:
        return
    for angle in [0.0, PI / 3.0, -PI / 3.0]:
        var axis := Vector2.from_angle(angle)
        for fraction in [-0.5, 0.0, 0.5]:
            var midpoint: Vector2 = center + axis.orthogonal() * r * fraction
            var extent: Vector2 = axis * r * sqrt(1.0 - fraction * fraction)
            map_canvas.draw_line(midpoint - extent, midpoint + extent, shadow, 2.0, true)
            map_canvas.draw_line(midpoint - extent, midpoint + extent, steel, 0.8, true)

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
    if not policy_selected.is_empty() and policy_draft_card.is_empty():
        return
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
    if match_menu.visible or (is_instance_valid(policy_modal) and policy_modal.visible):
        return
    if not policy_draft_card.is_empty():
        if event is InputEventMouseButton:
            var brush_button: InputEventMouseButton = event
            if brush_button.button_index == MOUSE_BUTTON_LEFT or brush_button.button_index == MOUSE_BUTTON_RIGHT:
                if brush_button.pressed:
                    if policy_brush_mode != 0:
                        _end_policy_brush_drag()
                    policy_brush_mode = 1 if brush_button.button_index == MOUSE_BUTTON_LEFT else -1
                    policy_stroke_snapshot = policy_brush_strokes.duplicate()
                    policy_stroke_weights = policy_zone_weights.duplicate()
                    policy_brush_last_point = brush_button.position
                    _paint_policy_brush(brush_button.position, policy_brush_mode)
                elif policy_brush_mode == (1 if brush_button.button_index == MOUSE_BUTTON_LEFT else -1):
                    _end_policy_brush_drag()
                map_canvas.accept_event()
                return
            if brush_button.pressed and brush_button.button_index == MOUSE_BUTTON_WHEEL_UP:
                _zoom_at(brush_button.position, 1.15)
            elif brush_button.pressed and brush_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                _zoom_at(brush_button.position, 1.0 / 1.15)
        elif event is InputEventMouseMotion:
            policy_brush_cursor = event.position
            if policy_brush_mode != 0:
                if policy_brush_last_point.x != INF:
                    var delta: Vector2 = event.position - policy_brush_last_point
                    var segments: int = maxi(1, ceili(delta.length() / (policy_brush_radius * 0.85)))
                    for index in range(1, segments + 1):
                        _paint_policy_brush(policy_brush_last_point.lerp(event.position, float(index) / float(segments)), policy_brush_mode)
                else:
                    _paint_policy_brush(event.position, policy_brush_mode)
                policy_brush_last_point = event.position
                _update_policy_zone_overlay()
        map_canvas.queue_redraw()
        map_canvas.accept_event()
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

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.physical_keycode not in [KEY_Q, KEY_E]:
        return
    if not is_instance_valid(match_menu) or match_menu.visible or str(session.get("phase")) != "match":
        return
    var focus: Control = get_viewport().gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit or colony_picker.get_popup().visible:
        return
    _cycle_owned_system(-1 if event.physical_keycode == KEY_Q else 1)
    get_viewport().set_input_as_handled()

func _cycle_owned_system(direction: int) -> void:
    var state: Dictionary = _state()
    if state.is_empty():
        return
    var owned: Array[int] = []
    for i in range(state["planets"].size()):
        if int(state["planets"][i]["owner"]) == _me():
            owned.append(i)
    if owned.is_empty():
        return
    var current: int = owned.find(selected)
    selected = owned[(0 if direction > 0 else owned.size() - 1) if current < 0 else posmod(current + direction, owned.size())]
    selected_ship_id = -1
    selected_field = -1
    var world: Vector2 = state["map"]["points"][selected]
    var desired_radius: float = minf(_projection_size().x, _projection_size().y) * 0.27
    var radius_per_zoom: float = minf(RADIUS * float(state["planets"][selected].get("size_factor", 1.0)), float(_system_visual(selected, state)["spacing"]) * _fit() * 0.39)
    zoom = clampf(desired_radius / maxf(0.001, radius_per_zoom), MIN_ZOOM, MAX_ZOOM)
    var center: Vector2 = Vector2(OVERVIEW_WIDTH + 8.0, 0.0) + _projection_size() * 0.5
    pan += center - _screen_point(world)
    _load_thresholds()
    _refresh()

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
    # A release over the editor or outside the map must still finish the drag.
    if not policy_draft_card.is_empty() and policy_brush_mode != 0:
        var held_button: int = MOUSE_BUTTON_LEFT if policy_brush_mode > 0 else MOUSE_BUTTON_RIGHT
        if not Input.is_mouse_button_pressed(held_button):
            _end_policy_brush_drag()
    _keyboard_pan(delta)
    _update_resource_hover()
    if is_instance_valid(diagnostic_label):
        diagnostic_elapsed += delta
        if diagnostic_elapsed >= 1.0:
            var authority: bool = bool(session.get("is_solo")) or multiplayer.is_server()
            var bytes: int = int(session.get("diagnostic_sent_bytes" if authority else "diagnostic_received_bytes"))
            var throughput: float = float(maxi(0, bytes - diagnostic_last_bytes)) / diagnostic_elapsed / 1024.0 if diagnostic_last_bytes >= 0 else 0.0
            diagnostic_last_bytes = bytes
            if diagnostic_label.visible:
                var timing: String = " · sim %.2f ms · encode %.2f ms" % [float(session.get("diagnostic_sim_ms")), float(session.get("diagnostic_encode_ms"))] if authority else ""
                diagnostic_label.text = "%d FPS%s · %.1f KiB snapshot · %.1f KiB/s payload" % [Engine.get_frames_per_second(), timing, float(session.get("diagnostic_snapshot_bytes")) / 1024.0, throughput]
            diagnostic_elapsed = 0.0
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
        var scale: float = clampf(spacing / 150.0, 0.22, 1.0)
        var origin: Vector2 = pos + Vector2(-69.0 * scale, radius + 5.0 * scale)
        map_canvas.draw_rect(Rect2(origin - Vector2.ONE * 3.0 * scale, Vector2(144, 38) * scale), Color("#0c1928ec"))
        for r in range(ECONOMY.RESOURCES.size()):
            var resource: String = ECONOMY.RESOURCES[r]
            var cell: Vector2 = origin + Vector2(float(r % 3) * 47.0, floorf(float(r) / 3.0) * 18.0) * scale
            var fraction: float = clampf(float(system["stock"][resource]) / ECONOMY.storage_capacity(system), 0.0, 1.0)
            map_canvas.draw_rect(Rect2(cell, Vector2(44, 14) * scale), Color("#263b50"))
            map_canvas.draw_rect(Rect2(cell, Vector2(44.0 * fraction, 14) * scale), HUD.COLORS[resource].darkened(0.4))
            map_canvas.draw_texture_rect(HUD.ICONS[resource], Rect2(cell, Vector2(13, 13) * scale), false)
            if scale >= 0.8:
                map_canvas.draw_string(font, cell + Vector2(15, 11) * scale, _tons(float(system["stock"][resource]), 0, true), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
    # Aggregate loaded shipments at their origin and final destination.
    var traffic: Dictionary = {}
    for ship in state["ships"]:
        if ship["kind"] != "ship" or ECONOMY._cargo_total(ship) <= ECONOMY.EPS:
            continue
        for endpoint in ["source", "dest"]:
            var node: int = int(ship.get(endpoint, -1))
            if node < 0 or node >= points.size():
                continue
            var lane: Array[int] = ECONOMY._path(state, ECONOMY.planet_teams(state), int(state["planets"][node]["team"]) if state["planets"][node].has("team") else int(ECONOMY.planet_teams(state)[node]), int(ship["source"]), int(ship["dest"]), {})
            if lane.size() < 2:
                continue
            var neighbor: int = lane[1] if endpoint == "source" else lane[lane.size() - 2]
            if not traffic.has(node):
                traffic[node] = {}
            var key: Vector2i = Vector2i(neighbor, 0 if endpoint == "source" else 1)
            if not traffic[node].has(key):
                traffic[node][key] = ECONOMY.empty_stock()
            for resource in ECONOMY.RESOURCES:
                traffic[node][key][resource] += float(ship["cargo"][resource])
    for node in traffic:
        if not ECONOMY.discovered(state, _me(), "planets", node):
            continue
        var center: Vector2 = _screen_point(points[node])
        var radius: float = _planet_radius(node, state)
        for key in traffic[node]:
            var endpoint: String = "source" if key.y == 0 else "dest"
            for k in range(ECONOMY.RESOURCES.size()):
                var resource: String = ECONOMY.RESOURCES[k]
                var cargo: float = traffic[node][key][resource]
                if cargo <= ECONOMY.EPS:
                    continue
                var radial: Vector2 = (_screen_point(points[key.x]) - center).normalized()
                var axis: Vector2 = radial if endpoint == "source" else -radial
                var normal: Vector2 = axis.orthogonal()
                var base: Vector2 = center + radial * minf(radius + 24.0 + float(k) * 13.0, center.distance_to(_screen_point(points[key.x])) * 0.48)
                var count: int = clampi(ceili(3.0 * cargo / ECONOMY.CARGO_CAPACITY), 1, 3)
                map_canvas.draw_texture_rect(HUD.ICONS[resource], Rect2(base + radial * 14.0 - Vector2(5, 5), Vector2(10, 10)), false)
                for j in range(count):
                    var tip: Vector2 = base + axis * float(j * 5)
                    map_canvas.draw_polyline(PackedVector2Array([tip - axis * 4.0 + normal * 3.0, tip, tip - axis * 4.0 - normal * 3.0]), HUD.COLORS[resource], 1.5, true)

func _draw_shipyards(state: Dictionary, index: int, tint: Color, elapsed: float) -> void:
    var planet: Dictionary = state["planets"][index]
    var center: Vector2 = _screen_point(state["map"]["points"][index])
    var scale: float = _ship_scale()
    for slot in range(planet["yards"].size()):
        var yard: Dictionary = planet["yards"][slot]
        var angle: float = float(slot) * TAU / 3.0 + elapsed * 0.008
        var axis: Vector2 = Vector2.from_angle(angle)
        var side: Vector2 = axis.orthogonal()
        var point: Vector2 = _screen_point(ECONOMY.shipyard_position(state, index, slot, elapsed))
        var conversion: float = clampf((elapsed - float(yard.get("converted_at", -100.0))) / 3.0, 0.0, 1.0)
        var frame: PackedVector2Array = PackedVector2Array([point - axis * 11.0 * scale - side * 17.0 * scale, point + axis * 11.0 * scale - side * 17.0 * scale, point + axis * 11.0 * scale + side * 17.0 * scale, point - axis * 11.0 * scale + side * 17.0 * scale])
        if conversion < 1.0:
            var heading: Vector2 = yard.get("colony_heading", Vector2.UP)
            var cross: Vector2 = heading.orthogonal()
            var original := PackedVector2Array([point + heading * 12.0 * scale, point + cross * 7.0 * scale, point - heading * 9.0 * scale, point - cross * 7.0 * scale])
            for k in range(4):
                frame[k] = original[k].lerp(frame[k], smoothstep(0.0, 1.0, conversion))
            map_canvas.draw_colored_polygon(frame, Color(tint.lightened(0.35), 1.0 - conversion))
        for k in range(4):
            map_canvas.draw_line(frame[k], frame[(k + 1) % 4], tint, 2.5 * scale, true)
        for k in [-1.0, 1.0]:
            var rail: Vector2 = point + axis * k * 11.0 * scale
            map_canvas.draw_line(rail - side * 17.0 * scale, rail + side * 17.0 * scale, Color(Color("#8da2b6"), conversion), 4.0 * scale, true)
        var health: float = float(yard.get("hp", ECONOMY.SHIP_HP * 10.0 * int(yard["level"]))) / (ECONOMY.SHIP_HP * 10.0 * int(yard["level"]))
        if health < 0.999:
            map_canvas.draw_rect(Rect2(point + Vector2(-12, -22) * scale, Vector2(24, 3) * scale), Color("#283748"))
            map_canvas.draw_rect(Rect2(point + Vector2(-12, -22) * scale, Vector2(24 * health, 3) * scale), tint)
        for job in planet["queue"]:
            if int(job["id"]) != int(yard["job"]) or not ECONOMY.SHIP_KINDS.has(job["kind"]):
                continue
            var u: float = clampf(float(job["progress"]) / float(job["work"]), 0.0, 1.0)
            var shape: PackedVector2Array
            match str(job["kind"]):
                "fighter": shape = PackedVector2Array([Vector2(12, 0), Vector2(-7, 8), Vector2(-3, 0), Vector2(-7, -8)])
                "colony_ship": shape = PackedVector2Array([Vector2(12, 0), Vector2(0, 7), Vector2(-9, 0), Vector2(0, -7)])
                "miner": shape = PackedVector2Array([Vector2(8, 4), Vector2(8, -4), Vector2(-6, -7), Vector2(-6, 7)])
                _: shape = PackedVector2Array([Vector2(14, 4), Vector2(10, 8), Vector2(-13, 8), Vector2(-13, -8), Vector2(10, -8), Vector2(14, -4)])
            var hull := PackedVector2Array()
            for vertex in shape:
                hull.append(point + side * vertex.x * scale + axis * vertex.y * scale)
            var edges: int = mini(hull.size(), floori(u * 2.0 * hull.size()))
            for k in range(edges):
                map_canvas.draw_line(hull[k], hull[(k + 1) % hull.size()], tint.lightened(0.4), 1.5 * scale, true)
            if u > 0.5:
                map_canvas.draw_colored_polygon(hull, Color(tint.lightened(0.4), (u - 0.5) * 2.0))
            break

func _draw_map() -> void:
    if session == null:
        return
    var state: Dictionary = _state()
    if state.is_empty():
        return
    var seed_value: int = int(state["map"]["seed"])
    if asteroid_cache_seed != seed_value:
        asteroid_shape_cache.clear()
        asteroid_cache_seed = seed_value
    var viewport_bounds: Rect2 = get_viewport_rect()
    var render_scale: float = _fit() * zoom
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
            if not viewport_bounds.grow(maxf(4.0, float(chunk["radius"]) * render_scale * 2.0)).has_point(rock_pos):
                continue
            var fraction: float = float(chunk["remaining"]) / float(chunk["initial"])
            var rock_radius: float = maxf(1.3, float(chunk["radius"]) * render_scale * sqrt(fraction))
            var shape_key: Vector2 = chunk["position"]
            if not asteroid_shape_cache.has(shape_key):
                var unit_shape := PackedVector2Array()
                for k in range(chunk["shape"].size()):
                    var angle: float = TAU * float(k) / float(chunk["shape"].size()) + float(chunk["rotation"])
                    unit_shape.append(Vector2.from_angle(angle) * float(chunk["shape"][k]))
                asteroid_shape_cache[shape_key] = unit_shape
            var rock := PackedVector2Array()
            for vertex in asteroid_shape_cache[shape_key]:
                rock.append(rock_pos + vertex * rock_radius)
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
        _draw_shipyards(state, i, tint, float(state["elapsed"]))
        if i == selected and bool(state["planets"][i]["home"]):
            map_canvas.draw_arc(pos, radius + 5.0, 0.0, TAU, 48, Color(tint, 0.5), 1.0, true)
        if i == selected:
            var phase: float = 0.6 + 0.35 * sin(visual_clock * 3.0)
            for angle in range(4):
                var start: float = float(angle) * TAU / 4.0 + 0.1
                map_canvas.draw_arc(pos, radius + 8.0, start, start + 1.15, 14, Color(HUD.ACCENT, phase), 2.0, true)
        var name_star_radius: float = maxf(3.0, radius * 0.13) if zoom >= 2.0 and radius >= 18.0 else radius * 0.48
        map_canvas.draw_string(font, pos + Vector2(-80, -name_star_radius - 7), _system_name(i), HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color("#f4faff") if i == selected else Color(0.83, 0.89, 0.95, 0.65))
    _draw_policy_zones(state)
    _draw_combat_lens(state, font)
    _draw_logistics_lens(state, font)
    var poses: Dictionary = _ship_poses(state)
    for index in range(points.size()):
        if not ECONOMY.discovered(state, _me(), "planets", index):
            continue
        var defenses: Dictionary = state["planets"][index].get("pds", {})
        if defenses.is_empty():
            continue
        var radius: float = _planet_radius(index, state)
        for slot in defenses:
            var battery: Dictionary = defenses[slot]
            var target: int = int(battery["target"])
            if not poses.has(target) or float(battery["laser_until"]) < float(state["elapsed"]):
                continue
            var origin: Vector2 = _screen_point(points[index])
            if zoom >= 2.0 and radius >= 18.0:
                origin += _body_position(_system_visual(index, state)["bodies"][slot], radius, game_visual_clock)
            map_canvas.draw_line(origin, poses[target]["point"], Color("#ff6f6080"), 6.0, true)
            map_canvas.draw_line(origin, poses[target]["point"], Color("#ffddab"), 2.0, true)
    for ship in state["ships"]:
        var shooter: int = int(ship["id"])
        var target: int = int(ship.get("combat_target", -1))
        var yard_target: int = int(ship.get("yard_target", -1))
        if poses.has(shooter) and yard_target < -1 and float(ship.get("yard_laser_until", -1.0)) >= float(state["elapsed"]):
            var index: int = floori(float(-2 - yard_target) / 3.0)
            var slot: int = posmod(-2 - yard_target, 3)
            if index < state["planets"].size() and slot < state["planets"][index]["yards"].size():
                map_canvas.draw_line(poses[shooter]["point"], _screen_point(ECONOMY.shipyard_position(state, index, slot, float(state["elapsed"]))), Color("#ffbf96"), 1.5, true)
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
        if ship.get("mining_mode", "") == "mining" and ship.has("mining_rock"):
            var aim: Vector2 = _screen_point(ship["mining_rock"]) - point
            if not aim.is_zero_approx():
                direction = aim.normalized()
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
        if ship["kind"] == "ship":
            hull = Color("#788ca0")
            shape = PackedVector2Array([point + direction * 14 + side * 4, point + direction * 10 + side * 8, point - direction * 13 + side * 8, point - direction * 13 - side * 8, point + direction * 10 - side * 8, point + direction * 14 - side * 4])
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
            if viewport_bounds.grow(24.0).has_point(engine):
                var particle_count: int = 5 if scale >= 1.0 else 2
                for k in range(particle_count):
                    var age: float = fposmod(visual_clock * 3.5 + float(k) / float(particle_count) + float(ship["id"]) * 0.173, 1.0)
                    var offset: float = sin(float(k) * 2.4 + float(ship["id"])) * age * 2.5
                    var spark: Vector2 = engine - direction * (2.0 + age * 12.0) + side * offset
                    map_canvas.draw_circle(spark, maxf(0.75, (2.0 - age) * scale), Color(0.45, 0.85, 1.0, (1.0 - age) * 0.85), false)
        if ship.get("mining_mode", "") == "mining" and ship.has("mining_rock") and viewport_bounds.grow(32.0).has_point(point) and scale >= 0.65:
            var rock: Vector2 = _screen_point(ship["mining_rock"])
            for sign in [-1.0, 1.0]:
                var emitter: Vector2 = point + direction * 7.0 + side * sign * 3.0
                var impact: Vector2 = rock + side * sign * 2.0
                map_canvas.draw_line(emitter, impact, Color("#9af6b8"), maxf(0.8, scale), true)
                for k in range(3 if scale >= 1.0 else 1):
                    var age: float = fposmod(visual_clock * 4.0 + float(k) * 0.33 + sign * 0.12, 1.0)
                    var spark: Vector2 = impact - direction * age * 6.0 + side * sign * age * float(k + 1) * 2.0
                    map_canvas.draw_circle(spark, maxf(0.7, scale * (1.0 - age)), Color(1.0, 0.85, 0.45, 1.0 - age), false)
        if int(ship["id"]) == selected_ship_id:
            map_canvas.draw_arc(point, maxf(5.0, 15.0 * scale), 0.0, TAU, 32, HUD.ACCENT, 2.0, true)
        map_canvas.draw_colored_polygon(shape, hull)
        if ship["kind"] == "ship":
            for k in range(ECONOMY.RESOURCES.size()):
                var resource: String = ECONOMY.RESOURCES[k]
                var fraction: float = clampf(float(ship["cargo"][resource]) / ECONOMY.CARGO_CAPACITY, 0.0, 1.0)
                var module: Vector2 = point + direction * (5.0 - float(k % 3) * 7.0) + side * (-3.5 if k < 3 else 3.5)
                var corners := PackedVector2Array([module + direction * 3 + side * 3, module - direction * 3 + side * 3, module - direction * 3 - side * 3, module + direction * 3 - side * 3])
                map_canvas.draw_colored_polygon(corners, Color("#182333").lerp(HUD.COLORS[resource], clampf(fraction * 6.0, 0.0, 1.0)))
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

# Policy cards are clipped by the bottom edge; the full cards appear in a modal.
var policy_selected: String = ""
var policy_draft_card: String = ""
var policy_draft_slot: String = ""
var policy_brush_mode: int = 0
var policy_brush_cursor: Vector2 = Vector2.ZERO
var policy_brush_radius: float = 28.0
var policy_brush_size_label: Label
var policy_brush_strokes: Array[Vector3] = []
var policy_zone_overlay: ColorRect
var policy_zone_material: ShaderMaterial
var policy_brush_dirty: bool = true
var policy_zone_groups: Array = []
const POLICY_MAX_STAMPS: int = 256
const POLICY_MAX_ZONES: int = 5
var policy_stroke_snapshot: Array[Vector3] = []
var policy_stroke_weights: Dictionary = {}
var policy_brush_last_point: Vector2 = Vector2(INF, INF)
var policy_painted: Dictionary = {}
var policy_zone_weights: Dictionary = {}
var policy_voids: Dictionary = {}
var policy_editor: PanelContainer
var policy_editor_rows: VBoxContainer
var policy_editor_status: Label
var policy_editor_card: Label
var policy_editor_accept: Button
var policy_hidden_ui: Dictionary = {}
var policy_original_map_top: float = 0.0
var policy_buttons: Dictionary = {}
var policy_changes: Dictionary = {}
var policy_inspector: PanelContainer
var policy_title: Label
var policy_info: Label
var policy_slider: HSlider
var policy_modal: Control
var policy_catalog: HBoxContainer
var policy_choice_slot: String = ""
var policy_drop: PolicyDrop
var policy_modal_panel: PanelContainer

class PolicyCard extends Button:
    var card_id: String = ""
    var slot_id: String = ""
    func _get_drag_data(_position: Vector2) -> Variant:
        var preview := Label.new()
        preview.text = text
        preview.add_theme_font_size_override("font_size", 18)
        set_drag_preview(preview)
        return {"card": card_id, "slot": slot_id}

class PolicyDrop extends Button:
    signal card_dropped(card: String)
    var slot_id: String = ""
    func _can_drop_data(_position: Vector2, data: Variant) -> bool:
        return not disabled and data is Dictionary and data.get("slot", "") == slot_id and data.has("card")
    func _drop_data(_position: Vector2, data: Variant) -> void:
        card_dropped.emit(str(data["card"]))

# One signed-distance union produces a uniform translucent fill and a single
# boundary, instead of stacking opaque circles at each brush position.
func _build_policy_zone_overlay() -> void:
    policy_zone_overlay = ColorRect.new()
    map_canvas.add_child(policy_zone_overlay)
    policy_zone_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    policy_zone_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    policy_zone_overlay.visible = false
    var shader := Shader.new()
    shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform int stamp_count = 0;
uniform vec3 stamps[256];
uniform vec2 canvas_size = vec2(1.0);
uniform vec2 world_center = vec2(0.0);
uniform vec2 screen_center = vec2(0.0);
uniform float world_scale = 1.0;
uniform vec4 tint : source_color = vec4(0.91, 0.58, 0.43, 1.0);
void fragment() {
    // Evaluate the same inverse projection as _world_point. Both the map
    // and painted mask therefore remain anchored to immutable world space.
    vec2 pixel = UV * canvas_size;
    vec2 world = world_center + (pixel - screen_center) / max(world_scale, 0.0001);
    float signed_distance = 100000.0;
    for (int i = 0; i < 256; i++) {
        if (i >= stamp_count) { break; }
        signed_distance = min(signed_distance, length(world - stamps[i].xy) - stamps[i].z);
    }
    float pixel_distance = signed_distance * world_scale;
    float fill = 1.0 - smoothstep(-1.5, 1.5, pixel_distance);
    float edge = 1.0 - smoothstep(0.0, 2.5, abs(pixel_distance));
    COLOR = vec4(tint.rgb, 0.19 * fill + 0.42 * edge);
}
"""
    policy_zone_material = ShaderMaterial.new()
    policy_zone_material.shader = shader
    policy_zone_overlay.material = policy_zone_material

func _update_policy_zone_overlay() -> void:
    if not is_instance_valid(policy_zone_overlay):
        return
    policy_zone_overlay.visible = not policy_draft_card.is_empty() and not policy_brush_strokes.is_empty()
    if not policy_zone_overlay.visible:
        return
    if policy_brush_dirty:
        var stamps := PackedVector3Array()
        for mark in policy_brush_strokes:
            stamps.append(mark)
        while stamps.size() < POLICY_MAX_STAMPS:
            stamps.append(Vector3.ZERO)
        policy_zone_material.set_shader_parameter("stamps", stamps)
        policy_zone_material.set_shader_parameter("stamp_count", policy_brush_strokes.size())
        policy_brush_dirty = false
    policy_zone_material.set_shader_parameter("canvas_size", map_canvas.size)
    policy_zone_material.set_shader_parameter("world_center", _map_size() * 0.5)
    policy_zone_material.set_shader_parameter("screen_center", Vector2(OVERVIEW_WIDTH + 8.0, 0.0) + _projection_size() * 0.5 + pan)
    policy_zone_material.set_shader_parameter("world_scale", _fit() * zoom)
    policy_zone_material.set_shader_parameter("tint", Color("#e99c77") if policy_draft_card == "invasion" else Color("#83b5eb"))

func _build_policy_ui() -> void:
    var strip := HBoxContainer.new()
    add_child(strip)
    strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    strip.offset_left = -350
    strip.offset_right = 350
    strip.offset_top = -72
    strip.offset_bottom = -4
    strip.add_theme_constant_override("separation", 5)
    for slot in ECONOMY.POLICY_SLOTS:
        var column := VBoxContainer.new()
        column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        strip.add_child(column)
        var change: Button = _button("Change", _open_policy_catalog.bind(slot), column)
        change.custom_minimum_size.y = 24
        policy_changes[slot] = change
        var card := PolicyDrop.new()
        card.slot_id = slot
        card.card_dropped.connect(_equip_selected_policy)
        card.custom_minimum_size = Vector2(128, 42)
        card.add_theme_font_size_override("font_size", 12)
        card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        card.alignment = HORIZONTAL_ALIGNMENT_CENTER
        card.toggle_mode = true
        card.pressed.connect(_inspect_policy.bind(slot))
        column.add_child(card)
        policy_buttons[slot] = card
    policy_inspector = PanelContainer.new()
    add_child(policy_inspector)
    policy_inspector.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
    policy_inspector.offset_left = -310
    policy_inspector.offset_right = -8
    policy_inspector.offset_top = HEADER_HEIGHT + 64
    policy_inspector.offset_bottom = -82
    policy_inspector.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928"), Color("#284661"), 8))
    var body := VBoxContainer.new()
    policy_inspector.add_child(body)
    var title_row := HBoxContainer.new()
    body.add_child(title_row)
    policy_title = _label("", 18)
    policy_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(policy_title)
    _button("×", _inspect_policy.bind(""), title_row)
    policy_info = _label("", 14)
    body.add_child(policy_info)
    policy_slider = HSlider.new()
    policy_slider.max_value = 100
    policy_slider.step = 1
    policy_slider.editable = false
    body.add_child(policy_slider)
    policy_inspector.hide()
    # In-scene overlay leaves the actual bottom slots reachable for GUI drag/drop.
    policy_modal = Control.new()
    add_child(policy_modal)
    policy_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    policy_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
    policy_modal_panel = PanelContainer.new()
    policy_modal.add_child(policy_modal_panel)
    policy_modal_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    policy_modal_panel.offset_left = -280
    policy_modal_panel.offset_right = 280
    policy_modal_panel.offset_top = -140
    policy_modal_panel.offset_bottom = 140
    policy_modal_panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928"), Color("#42647e"), 12))
    var contents := VBoxContainer.new()
    policy_modal_panel.add_child(contents)
    var tools_row := HBoxContainer.new()
    contents.add_child(tools_row)
    var hint := _label("Choose or drag a card to its slot", 13)
    hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tools_row.add_child(hint)
    _button("Empty", _equip_selected_policy.bind(""), tools_row)
    _button("×", policy_modal.hide, tools_row)
    policy_catalog = HBoxContainer.new()
    contents.add_child(policy_catalog)
    policy_modal.hide()
    policy_editor = PanelContainer.new()
    add_child(policy_editor)
    policy_editor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    policy_editor.offset_left = 12
    policy_editor.offset_right = 348
    policy_editor.offset_top = 12
    policy_editor.offset_bottom = 520
    policy_editor.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928"), Color("#42647e"), 8))
    var editor_layout := VBoxContainer.new()
    policy_editor.add_child(editor_layout)
    var editor_scroll := ScrollContainer.new()
    editor_layout.add_child(editor_scroll)
    editor_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
    editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var editor_body := VBoxContainer.new()
    editor_body.custom_minimum_size.x = 305
    editor_scroll.add_child(editor_body)
    policy_editor_card = _label("", 18)
    editor_body.add_child(policy_editor_card)
    editor_body.add_child(_label("Left: paint   Right: erase · Maximum 5 zones", 13))
    var brush_row := HBoxContainer.new()
    editor_body.add_child(brush_row)
    policy_brush_size_label = _label("Brush size: 28", 13)
    policy_brush_size_label.custom_minimum_size.x = 112
    brush_row.add_child(policy_brush_size_label)
    var brush_slider := HSlider.new()
    brush_slider.min_value = 10
    brush_slider.max_value = 80
    brush_slider.step = 1
    brush_slider.value = policy_brush_radius
    brush_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    brush_row.add_child(brush_slider)
    brush_slider.value_changed.connect(func(value: float) -> void:
        policy_brush_radius = value
        policy_brush_size_label.text = "Brush size: %d" % roundi(value)
        map_canvas.queue_redraw())
    policy_editor_rows = VBoxContainer.new()
    editor_body.add_child(policy_editor_rows)
    # Keep status and confirmation visible even with five zone sliders.
    policy_editor_status = _label("", 13)
    policy_editor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    editor_layout.add_child(policy_editor_status)
    var action_row := HBoxContainer.new()
    editor_layout.add_child(action_row)
    _button("Cancel", _cancel_policy_draft, action_row)
    policy_editor_accept = _button("Accept", _commit_policy_draft, action_row)
    policy_editor.hide()

func _open_policy_catalog(slot: String) -> void:
    policy_choice_slot = slot

    for child in policy_catalog.get_children():
        policy_catalog.remove_child(child)
        child.queue_free()
    var state: Dictionary = _state()
    for card in ECONOMY.POLICY_CARDS:
        if not ECONOMY.policy_eligible(state, _me(), slot, card):
            continue
        var tile := PolicyCard.new()
        tile.card_id = card
        tile.slot_id = slot
        tile.text = str(ECONOMY.POLICY_CARDS[card]["name"])
        tile.tooltip_text = str(ECONOMY.POLICY_CARDS[card].get("description", ""))
        tile.custom_minimum_size = Vector2(132, 155)
        tile.add_theme_font_size_override("font_size", 12)
        tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        tile.pressed.connect(_equip_selected_policy.bind(card))
        policy_catalog.add_child(tile)
    policy_modal_panel.offset_left = -maxf(160.0, float(policy_catalog.get_child_count()) * 72.0 + 16.0)
    policy_modal_panel.offset_right = -policy_modal_panel.offset_left
    policy_modal.show()

func _equip_selected_policy(card: String) -> void:
    policy_modal.hide()
    if not card.is_empty() and ECONOMY.POLICY_CARDS[card].get("military", false):
        _begin_policy_draft(policy_choice_slot, card)
        return
    session.call("request_policy", policy_choice_slot, card)
    policy_selected = ""
    _inspect_policy(policy_choice_slot)

func _inspect_policy(slot: String) -> void:
    policy_selected = "" if policy_selected == slot else slot
    active_lens = ""
    military_lens.set_pressed_no_signal(false)
    logistics_lens.set_pressed_no_signal(false)
    _refresh()
    map_canvas.queue_redraw()

func _refresh_policy_ui(state: Dictionary) -> void:
    if not is_instance_valid(policy_inspector):
        return
    var equipped: Dictionary = state.get("policies", {}).get(_me(), {})
    for slot in policy_buttons:
        var entry: Dictionary = equipped.get(slot, {})
        var card: Button = policy_buttons[slot]
        var available: bool = ECONOMY.policy_eligible(state, _me(), slot, "")
        card.disabled = not available
        policy_changes[slot].disabled = not available
        var name_text: String = "Locked" if not available else ("Empty" if entry.is_empty() else str(ECONOMY.POLICY_CARDS[entry["card"]]["name"]))
        if not entry.is_empty() and not ECONOMY.policy_active(state, entry):
            name_text += " · %ds" % ceili(float(entry["ready_at"]) - float(state["elapsed"]))
        card.text = slot.capitalize() + "\n" + name_text
        card.tooltip_text = name_text
        card.set_pressed_no_signal(policy_selected == slot)
    policy_inspector.visible = not policy_selected.is_empty() and policy_draft_card.is_empty()
    if not policy_inspector.visible:
        return
    var selected_entry: Dictionary = equipped.get(policy_selected, {})
    policy_title.text = policy_selected.capitalize()
    policy_slider.visible = false
    if selected_entry.is_empty():
        policy_info.text = "Empty slot"
        return
    var definition: Dictionary = ECONOMY.POLICY_CARDS[selected_entry["card"]]
    policy_title.text = definition["name"]
    var military: bool = definition.get("military", false)
    policy_slider.visible = military
    if military:
        if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            policy_slider.set_value_no_signal(float(selected_entry["weight"]))
        policy_info.text = "Committed: %d%%" % ECONOMY.policy_allocation(selected_entry)
        if ECONOMY.policy_active(state, selected_entry):
            var assigned: int = 0
            var traveling: int = 0
            var rallying: int = 0
            var recovering: int = 0
            for operation in state.get("operations", {}).values():
                if int(operation["owner"]) != _me() or not selected_entry.get("targets", []).has(operation["target"]):
                    continue
                assigned += (operation.get("members", []) as Array).size()
                traveling += (operation.get("in_transit", []) as Array).size()
                rallying += (operation.get("rallying", []) as Array).size()
                recovering += (operation.get("recovering", []) as Array).size()
            policy_info.text += "\nFleet at objectives: %d assigned\n%d traveling · %d rallying · %d repairing" % [assigned, traveling, rallying, recovering]
        policy_info.text += "\nReplace the card to redraw its zones."
    else:
        policy_info.text = str(definition.get("description", "Policy effects pending"))
    if not ECONOMY.policy_active(state, selected_entry):
        policy_info.text += "\nPreparing: %ds" % ceili(float(selected_entry["ready_at"]) - float(state["elapsed"]))

# Painting is a local draft; committed policy data is only changed by Confirm.
func _begin_policy_draft(slot: String, card: String) -> void:
    policy_draft_slot = slot
    policy_draft_card = card
    policy_selected = ""
    policy_brush_mode = 0
    policy_painted.clear()
    policy_brush_strokes.clear()
    policy_brush_dirty = true
    policy_stroke_snapshot.clear()
    policy_stroke_weights.clear()
    policy_zone_groups.clear()
    policy_brush_last_point = Vector2(INF, INF)
    policy_zone_weights.clear()
    policy_voids.clear()
    var entry: Dictionary = _state().get("policies", {}).get(_me(), {}).get(slot, {})
    if entry.get("card", "") == card:
        var map_points: Array = _state().get("map", {}).get("points", [])
        for zone in entry.get("zones", []):
            for node in zone["targets"]:
                policy_painted[int(node)] = true
                if int(node) >= 0 and int(node) < map_points.size() and policy_brush_strokes.size() < POLICY_MAX_STAMPS:
                    var position: Vector2 = map_points[int(node)]
                    policy_brush_strokes.append(Vector3(position.x, position.y, policy_brush_radius / (_fit() * zoom)))
    policy_editor_card.text = str(ECONOMY.POLICY_CARDS[card]["name"])
    policy_original_map_top = map_canvas.offset_top
    map_canvas.offset_top = 8
    # Territory and map share the same local projection. Keep their parent
    # rectangles identical when the map expands in focused draft mode.
    territory_layer.offset_top = map_canvas.offset_top
    policy_hidden_ui.clear()
    for child in get_children():
        if child.name == "SpaceBackdrop" or child == territory_layer or child == map_canvas or child == policy_editor or child == policy_modal or child == match_menu:
            continue
        if child is CanvasItem:
            policy_hidden_ui[child] = child.visible
            child.hide()
    policy_editor.show()
    _position_territory()
    _update_policy_zone_overlay()
    _update_policy_editor()
    map_canvas.queue_redraw()

func _cancel_policy_draft() -> void:
    policy_draft_card = ""
    policy_brush_mode = 0
    policy_brush_last_point = Vector2(INF, INF)
    policy_brush_strokes.clear()
    policy_brush_dirty = true
    policy_stroke_snapshot.clear()
    policy_stroke_weights.clear()
    policy_zone_groups.clear()
    _update_policy_zone_overlay()
    policy_editor.hide()
    map_canvas.offset_top = policy_original_map_top
    territory_layer.offset_top = map_canvas.offset_top
    _position_territory()
    for child in policy_hidden_ui:
        if is_instance_valid(child):
            child.visible = bool(policy_hidden_ui[child])
    policy_hidden_ui.clear()
    _refresh()
    map_canvas.queue_redraw()

func _end_policy_brush_drag() -> void:
    policy_brush_mode = 0
    policy_brush_last_point = Vector2(INF, INF)
    _finish_policy_brush_stroke()

# Rebuild allocations only once per drag, not for every interpolated stamp.
# Reject an erase that splits the painted territory into more than five zones.
func _finish_policy_brush_stroke() -> void:
    if policy_brush_strokes == policy_stroke_snapshot:
        return
    var groups: Array = _policy_components()
    if groups.size() > POLICY_MAX_ZONES:
        policy_brush_strokes = policy_stroke_snapshot.duplicate()
        policy_brush_dirty = true
        policy_zone_weights = policy_stroke_weights.duplicate()
    else:
        var old_weights: Dictionary = policy_stroke_weights.duplicate()
        var next_weights: Dictionary = {}
        for group in groups:
            var key: int = int(group["key"])
            if old_weights.has(key):
                next_weights[key] = old_weights[key]
        if next_weights.is_empty() and not old_weights.is_empty() and not groups.is_empty():
            next_weights[int(groups[0]["key"])] = int(old_weights.values()[0])
        policy_zone_weights = next_weights
    policy_zone_groups = _policy_components()
    _update_policy_editor()
    _update_policy_zone_overlay()
    map_canvas.queue_redraw()

func _paint_policy_brush(point: Vector2, mode: int) -> void:
    if _state().is_empty():
        return
    var world: Vector2 = _world_point(point)
    var radius: float = policy_brush_radius / (_fit() * zoom)
    if mode > 0:
        var touches_existing: bool = false
        for stamp in policy_brush_strokes:
            var distance: float = Vector2(stamp.x, stamp.y).distance_to(world)
            if distance < radius * 0.75:
                return
            if distance <= radius + stamp.z:
                touches_existing = true
        if not touches_existing and _policy_components().size() >= POLICY_MAX_ZONES:
            return
        # Never enlarge earlier circles to free slots: that was the source of
        # spontaneous zone growth. Keep the existing geometry unchanged.
        if policy_brush_strokes.size() >= POLICY_MAX_STAMPS:
            return
        policy_brush_strokes.append(Vector3(world.x, world.y, radius))
        policy_brush_dirty = true
    else:
        for index in range(policy_brush_strokes.size() - 1, -1, -1):
            var stamp: Vector3 = policy_brush_strokes[index]
            if Vector2(stamp.x, stamp.y).distance_to(world) < radius + stamp.z * 0.35:
                policy_brush_strokes.remove_at(index)
                policy_brush_dirty = true

# Components are based on the actual painted geometry, not map lane links.
# Each star belongs to the painted component containing its world position.
func _policy_components() -> Array:
    var state: Dictionary = _state()
    var pending: Dictionary = {}
    for index in range(policy_brush_strokes.size()):
        pending[index] = true
    var groups: Array = []
    while not pending.is_empty():
        var seed: int = int(pending.keys()[0])
        pending.erase(seed)
        var component: Array = [seed]
        var queue: Array = [seed]
        while not queue.is_empty():
            var current: int = int(queue.pop_back())
            var a: Vector3 = policy_brush_strokes[current]
            for other in pending.keys():
                var b: Vector3 = policy_brush_strokes[int(other)]
                if Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)) <= a.z + b.z:
                    pending.erase(other)
                    component.append(other)
                    queue.append(other)
        var targets: Array = []
        for node in range((state.get("planets", []) as Array).size()):
            if not ECONOMY.discovered(state, _me(), "planets", node):
                continue
            var location: Vector2 = state["map"]["points"][node]
            for index in component:
                var mark: Vector3 = policy_brush_strokes[int(index)]
                if location.distance_to(Vector2(mark.x, mark.y)) <= mark.z:
                    targets.append(node)
                    break
        targets.sort()
        var anchor: Vector3 = policy_brush_strokes[seed]
        groups.append({"stamps": component, "targets": targets, "key": seed, "anchor": Vector2(anchor.x, anchor.y)})
    groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["key"]) < int(b["key"]))
    return groups


# Clamp draft allocations to the capacity left by non-voided policies.
# Stable zone ordering makes reductions predictable after merging/splitting.
func _limit_policy_zone_allocations() -> void:
    var reserved: int = 0
    var equipped: Dictionary = _state().get("policies", {}).get(_me(), {})
    for slot in equipped:
        if slot == policy_draft_slot or bool(policy_voids.get(slot, false)):
            continue
        if ECONOMY.POLICY_CARDS[equipped[slot]["card"]].get("military", false):
            reserved += ECONOMY.policy_allocation(equipped[slot])
    var remaining: int = maxi(0, 100 - reserved)
    for group in _policy_components():
        var key: int = int(group["key"])
        var amount: int = clampi(int(policy_zone_weights.get(key, 0)), 0, remaining)
        policy_zone_weights[key] = amount
        remaining -= amount

func _update_policy_editor() -> void:
    if policy_draft_card.is_empty():
        return
    for child in policy_editor_rows.get_children():
        policy_editor_rows.remove_child(child)
        child.queue_free()
    var groups: Array = _policy_components()
    policy_zone_groups = groups
    if policy_zone_weights.is_empty() and not groups.is_empty():
        policy_zone_weights[int(groups[0]["key"])] = 100
    _limit_policy_zone_allocations()
    var total: int = 0
    for i in range(groups.size()):
        var group: Dictionary = groups[i]
        var key: int = int(group["key"])
        var weight: int = int(policy_zone_weights.get(key, 0))
        policy_zone_weights[key] = weight
        total += weight
        var label_text: String = "Zone %s · %d systems · %d%%" % [char(65 + i), (group["targets"] as Array).size(), weight]
        var zone_label: Label = _label(label_text, 13)
        policy_editor_rows.add_child(zone_label)
        var slider := HSlider.new()
        slider.min_value = 0
        slider.max_value = 100
        slider.step = 1
        slider.value = weight
        policy_editor_rows.add_child(slider)
        slider.value_changed.connect(func(value: float) -> void:
            var others: int = 0
            for other_group in _policy_components():
                var other_key: int = int(other_group["key"])
                if other_key != key:
                    others += int(policy_zone_weights.get(other_key, 0))
            var reserved: int = 0
            var committed: Dictionary = _state().get("policies", {}).get(_me(), {})
            for other_slot in committed:
                if other_slot == policy_draft_slot or bool(policy_voids.get(other_slot, false)):
                    continue
                if ECONOMY.POLICY_CARDS[committed[other_slot]["card"]].get("military", false):
                    reserved += ECONOMY.policy_allocation(committed[other_slot])
            var bounded: int = clampi(roundi(value), 0, maxi(0, 100 - reserved - others))
            policy_zone_weights[key] = bounded
            slider.set_value_no_signal(bounded)
            zone_label.text = "Zone %s · %d systems · %d%%" % [char(65 + i), (group["targets"] as Array).size(), bounded]
            _update_policy_editor_status())
    policy_editor_rows.add_child(_label("Other committed policies", 14))
    var equipped: Dictionary = _state().get("policies", {}).get(_me(), {})
    for slot in equipped:
        if slot == policy_draft_slot:
            continue
        var entry: Dictionary = equipped[slot]
        if not ECONOMY.POLICY_CARDS[entry["card"]].get("military", false):
            continue
        var row := HBoxContainer.new()
        policy_editor_rows.add_child(row)
        var amount: int = ECONOMY.policy_allocation(entry)
        var check := CheckBox.new()
        check.text = "%s · %d%% — Void" % [slot.capitalize(), amount]
        check.button_pressed = bool(policy_voids.get(slot, false))
        row.add_child(check)
        check.toggled.connect(func(value: bool) -> void:
            policy_voids[slot] = value
            _update_policy_editor())
        var readonly := HSlider.new()
        readonly.max_value = 100
        readonly.value = amount
        readonly.editable = false
        policy_editor_rows.add_child(readonly)
    _update_policy_editor_status()

func _update_policy_editor_status() -> void:
    var used: int = 0
    for group in _policy_components():
        used += int(policy_zone_weights.get(int(group["key"]), 0))
    var equipped: Dictionary = _state().get("policies", {}).get(_me(), {})
    for slot in equipped:
        if slot == policy_draft_slot or bool(policy_voids.get(slot, false)):
            continue
        if ECONOMY.POLICY_CARDS[equipped[slot]["card"]].get("military", false):
            used += ECONOMY.policy_allocation(equipped[slot])
    var has_zone: bool = false
    var state: Dictionary = _state()
    for group in _policy_components():
        for node in group["targets"]:
            if ECONOMY.policy_target_valid(state, _me(), policy_draft_card, int(node)):
                has_zone = true
                break
        if has_zone:
            break
    policy_editor_accept.disabled = not has_zone or used > 100
    policy_editor_status.text = "%d%% committed · %d%% available" % [used, maxi(0, 100 - used)] if used <= 100 else "%d%% — overallocated" % used
    if not has_zone:
        policy_editor_status.text = "Accept unavailable: paint over an eligible %s system." % ("enemy-owned" if policy_draft_card == "invasion" else "friendly")

func _commit_policy_draft() -> void:
    var zones: Array = []
    var state: Dictionary = _state()
    for group in _policy_components():
        var valid: Array = []
        for node in group["targets"]:
            if ECONOMY.policy_target_valid(state, _me(), policy_draft_card, int(node)):
                valid.append(node)
        if valid.is_empty():
            continue
        zones.append({"targets": valid, "weight": int(policy_zone_weights.get(int(group["key"]), 0))})
    if zones.is_empty() or policy_editor_accept.disabled:
        return
    var voided: Array = []
    for slot in policy_voids:
        if bool(policy_voids[slot]):
            voided.append(slot)
    session.call("request_policy_zones", policy_draft_slot, policy_draft_card, zones, voided)
    _cancel_policy_draft()

func _draw_policy_zones(state: Dictionary) -> void:
    var equipped: Dictionary = state.get("policies", {}).get(_me(), {})
    for slot in equipped:
        var entry: Dictionary = equipped[slot]
        if not ECONOMY.POLICY_CARDS[entry["card"]].get("military", false):
            continue
        var tint: Color = Color("#df7777") if entry["card"] == "invasion" else Color("#83b5eb")
        for node in entry.get("targets", []):
            var pos: Vector2 = _screen_point(state["map"]["points"][int(node)])
            map_canvas.draw_circle(pos, policy_brush_radius * 0.7, Color(tint, 0.10))
            map_canvas.draw_arc(pos, policy_brush_radius * 0.7, 0, TAU, 32, Color(tint, 0.45), 1.0, true)
    if policy_draft_card.is_empty():
        return
    var draft_tint: Color = Color("#e99c77") if policy_draft_card == "invasion" else Color("#83b5eb")
    _update_policy_zone_overlay()
    # Cached groups describe the last completed stroke. Their indices are
    # invalid as soon as an erase removes a stamp. Use immutable positions,
    # and suppress stale labels during erasure until the groups are rebuilt.
    if policy_brush_mode >= 0 and not policy_brush_strokes.is_empty():
        var components: Array = policy_zone_groups
        for index in range(components.size()):
            var group: Dictionary = components[index]
            var label_pos: Vector2 = _screen_point(group["anchor"])
            map_canvas.draw_string(ThemeDB.fallback_font, label_pos + Vector2(10, -12), "Zone %s" % char(65 + index), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, draft_tint)
    map_canvas.draw_arc(policy_brush_cursor, policy_brush_radius, 0, TAU, 32, Color(draft_tint, 0.8), 1.0, true)

extends RefCounted
## Selected entity portrait, weapon readout and multi-ship tile presentation.
## Match owns selection and command dispatch; health colors/queries remain shared.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const HULL_ART = preload("res://scripts/hull_art.gd")
const UI_TEXT = preload("res://scripts/ui_text.gd")

var hull_art: HULL_ART
var health_color: Callable
var shield_fraction: Callable
var weapon_details: Label
var selection_portrait: VBoxContainer
var selection_portrait_art: TextureRect
var selection_portrait_health: Label
var selection_portrait_shield: Label
var selection_grid: GridContainer
var selection_tiles: Dictionary = {}
var selection_icons: Dictionary = {}

func configure(art: HULL_ART, color_query: Callable, shield_query: Callable) -> void:
	hull_art = art
	health_color = color_query
	shield_fraction = shield_query

func build_tiles(ship_overview: VBoxContainer) -> void:
	selection_grid = GridContainer.new()
	selection_grid.columns = 6
	selection_grid.add_theme_constant_override("h_separation", 3)
	selection_grid.add_theme_constant_override("v_separation", 3)
	ship_overview.add_child(selection_grid)

func build_weapons(overview: VBoxContainer, label_factory: Callable) -> void:
	weapon_details = label_factory.call("", 12)
	overview.add_child(weapon_details)
	weapon_details.hide()

func layout(console_center: Control, building_group_grid: GridContainer) -> void:
	if is_instance_valid(selection_grid):
		selection_grid.columns = maxi(1, floori(maxf(38.0, console_center.size.x - 20.0) / 41.0))
		building_group_grid.columns = selection_grid.columns
	if is_instance_valid(selection_portrait):
		var portrait_width: float = clampf(floorf(console_center.size.x * 0.22), 70.0, 108.0)
		selection_portrait.custom_minimum_size.x = portrait_width
		selection_portrait_art.custom_minimum_size.y = minf(portrait_width, 90.0)

func build_portrait(parent: Container, label_factory: Callable, focus_selection: Callable) -> void:
	selection_portrait = VBoxContainer.new()
	selection_portrait.custom_minimum_size.x = 90.0
	selection_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	selection_portrait.add_theme_constant_override("separation", 1)
	parent.add_child(selection_portrait)
	selection_portrait_art = TextureRect.new()
	selection_portrait_art.custom_minimum_size.y = 90.0
	selection_portrait_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selection_portrait_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	selection_portrait_art.mouse_filter = Control.MOUSE_FILTER_STOP
	selection_portrait_art.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
			focus_selection.call()
			selection_portrait_art.accept_event())
	selection_portrait.add_child(selection_portrait_art)
	selection_portrait_health = label_factory.call("", 12)
	selection_portrait_health.autowrap_mode = TextServer.AUTOWRAP_OFF
	selection_portrait_health.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_portrait.add_child(selection_portrait_health)
	selection_portrait_shield = label_factory.call("", 11)
	selection_portrait_shield.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_portrait_shield.add_theme_color_override("font_color", Color("#80caff"))
	selection_portrait.add_child(selection_portrait_shield)
	selection_portrait_shield.hide()
	selection_portrait.hide()

func refresh_portrait(ship: Dictionary, system: Dictionary, body_selected: bool, yard_selected: bool, grouped: bool, selection_count: int, selected_yard: int, selected_body: int, building_selection_kind: String) -> void:
	var kind: String = ""
	var hp: float = 0.0
	var maximum: float = 0.0
	if not ship.is_empty() and selection_count <= 1:
		kind = str(ship["kind"])
		maximum = ECONOMY.hull_max_hp(ship)
		hp = float(ship.get("hp", maximum))
	elif not grouped and not system.is_empty():
		if yard_selected:
			var yard: Dictionary = system["yards"][selected_yard]
			kind = "shipyard"
			maximum = ECONOMY.YARD_HP * int(yard["level"])
			hp = float(yard.get("hp", maximum))
		elif body_selected:
			var battery: Dictionary = system.get("pds", {}).get(selected_body, {})
			kind = "planet" if battery.is_empty() else "pds"
			if not battery.is_empty():
				maximum = ECONOMY.PDS_HP
				hp = float(battery.get("hp", maximum))
		elif building_selection_kind == "station" and ECONOMY.has_station(system):
			kind = "station"
			maximum = ECONOMY.station_max_hp(system)
			hp = float(system["station"].get("hp", maximum))
	selection_portrait.visible = not kind.is_empty()
	if kind.is_empty():
		return
	var tint: Color = health_color.call(clampf(hp / maximum, 0.0, 1.0)) if maximum > 0.0 else HUD.MUTED
	selection_portrait_art.texture = hull_art.selection_portrait_icon(kind)
	selection_portrait_art.modulate = tint
	selection_portrait_health.visible = maximum > 0.0
	selection_portrait_health.text = "%.0f / %.0f" % [hp, maximum] if maximum > 0.0 else ""
	selection_portrait_health.add_theme_color_override("font_color", tint)
	var entity: Dictionary = ship if not ship.is_empty() else (system.get("station", {}) if kind == "station" else {})
	var shield_max: float = float(entity.get("shield_max", 0.0))
	selection_portrait_shield.visible = shield_max > 0.0
	selection_portrait_shield.text = "Shield %.0f / %.0f" % [float(entity.get("shield", 0.0)), shield_max]

func refresh_weapons(ship: Dictionary, system: Dictionary, body_selected: bool, yard_selected: bool, grouped: bool, selection_count: int, selected_body: int, building_selection_kind: String, ship_overview: VBoxContainer, ship_detail: Label, body_status: Label, planet_overview: VBoxContainer) -> void:
	var details: String = ""
	var parent: Control = weapon_details.get_parent()
	var at: int = -1
	if not grouped:
		if not ship.is_empty() and selection_count == 1:
			parent = ship_overview
			at = ship_detail.get_index() + 1
			match str(ship["kind"]):
				"cruiser", "destroyer": details = UI_TEXT.capital_weapon_summary(str(ship["kind"]))
				"railgun_ship": details = UI_TEXT.railgun_summary(str(ship["kind"]))
				"scout", "fighter": details = UI_TEXT.blaster_summary(str(ship["kind"]))
				"miner": details = "Mining laser ×2\n%.0f damage each · 1 shot/s (1×) · Range %.0f\n+200%% vs asteroids · %.0f t/yr nominal" % [ECONOMY.MINER_LASER_DAMAGE / 2.0, ECONOMY.LASER_RANGE, ECONOMY.MINER_RATE]
		elif not system.is_empty() and not yard_selected:
			if body_selected and system.get("pds", {}).has(selected_body):
				parent = body_status.get_parent()
				at = body_status.get_index() + 1
				details = "Planetary defense laser\n%.0f damage · 1 shot/s (1×) · Range %.0f" % [ECONOMY.PDS_DAMAGE, ECONOMY.PDS_RANGE]
			elif not body_selected and building_selection_kind == "station" and ECONOMY.has_station(system):
				parent = planet_overview
				at = 1
				details = "Station lasers ×%d\n%.0f damage each · 1 shot/s (1×) · Range %.0f" % [system["station"].get("weapons", []).size(), ECONOMY.LASER_DAMAGE, ECONOMY.LASER_RANGE]
	if weapon_details.get_parent() != parent:
		weapon_details.reparent(parent, false)
		parent.move_child(weapon_details, at)
	weapon_details.text = details
	weapon_details.visible = not details.is_empty()

func _selection_icon(kind: String, tint: Color) -> Texture2D:
	var key: String = kind + ":" + tint.to_html(false)
	if not selection_icons.has(key):
		var points: Array = HULL_ART.HULL_OUTLINES.get(kind, HULL_ART.FREIGHTER_OUTLINE)
		var coords: PackedStringArray = []
		for vertex in points:
			var v: Vector2 = vertex
			var factor: float = float({"ship": 0.60, "cruiser": 0.54, "destroyer": 0.31, "railgun_ship": 0.42}.get(kind, 1.0))
			coords.append("%.2f,%.2f" % [16.0 + v.y * factor, 16.0 - v.x * factor])
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><polygon points="%s" fill="none" stroke="#%s" stroke-width="1.8" stroke-linejoin="round"/></svg>' % [" ".join(coords), tint.to_html(false)])
		selection_icons[key] = ImageTexture.create_from_image(image)
	return selection_icons[key]

func refresh_tiles(state: Dictionary, selected_units: Array[int], selected_ship_id: int, select_tile: Callable) -> void:
	var living: Dictionary = {}
	var wanted: Dictionary = {}
	for id in selected_units:
		wanted[id] = true
	if selected_ship_id >= 0:
		wanted[selected_ship_id] = true
	for craft in state.get("ships", []) if not wanted.is_empty() else []:
		var id: int = int(craft["id"])
		if not wanted.has(id):
			continue
		living[id] = true
		var tile: Button
		if selection_tiles.has(id):
			tile = selection_tiles[id]
		else:
			tile = Button.new()
			style_selection_tile(tile)
			tile.pressed.connect(select_tile.bind(id))
			selection_grid.add_child(tile)
			selection_tiles[id] = tile
		var hp: float = clampf(float(craft.get("hp", ECONOMY.ship_max_hp(str(craft["kind"])))) / ECONOMY.ship_max_hp(str(craft["kind"])), 0.0, 1.0)
		var tint: Color = health_color.call(hp)
		if tile.get_meta("health_color", Color.TRANSPARENT) != tint or tile.get_meta("hull_kind", "") != craft["kind"]:
			tile.set_meta("health_color", tint)
			tile.set_meta("hull_kind", craft["kind"])
			tile.icon = _selection_icon(str(craft["kind"]), tint)
		var shield_bar: ProgressBar = tile.get_meta("shield_bar")
		var shield: float = shield_fraction.call(craft)
		shield_bar.visible = shield >= 0.0 and shield < 1.0
		shield_bar.value = maxf(0.0, shield)
		tile.tooltip_text = "%s · HP %.0f / %.0f\nCrew: %s" % [UI_TEXT.ship_kind_name(str(craft["kind"])), float(craft.get("hp", ECONOMY.ship_max_hp(str(craft["kind"])))), ECONOMY.ship_max_hp(str(craft["kind"])), UI_TEXT.crew_text(float(craft.get("crew", 0.0)))]
	for id in selection_tiles.keys():
		if not living.has(id):
			var tile: Button = selection_tiles[id]
			selection_grid.remove_child(tile)
			tile.queue_free()
			selection_tiles.erase(id)
	selection_grid.visible = living.size() > 1

static func style_selection_tile(tile: Button) -> void:
	tile.custom_minimum_size = Vector2(38, 38)
	tile.focus_mode = Control.FOCUS_NONE
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.expand_icon = true
	tile.add_theme_constant_override("icon_max_width", 32)
	tile.add_theme_stylebox_override("normal", HUD.surface(HUD.CONSOLE_BACKGROUND, Color("#284661"), 2, 2))
	tile.add_theme_stylebox_override("hover", HUD.surface(HUD.CONSOLE_BACKGROUND.lightened(0.06), HUD.ACCENT, 2, 2))
	tile.add_theme_stylebox_override("pressed", HUD.surface(HUD.CONSOLE_BACKGROUND.lightened(0.10), Color.WHITE, 2, 2))
	var shield := ProgressBar.new()
	shield.show_percentage = false
	shield.max_value = 1.0
	shield.step = 0.0
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.add_theme_stylebox_override("background", HUD.surface(Color("#203f5c"), Color("#203f5c"), 0, 0))
	shield.add_theme_stylebox_override("fill", HUD.surface(Color("#6fbaff"), Color("#6fbaff"), 0, 0))
	tile.add_child(shield)
	shield.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shield.offset_top = -4.0
	shield.offset_bottom = -1.0
	shield.hide()
	tile.set_meta("shield_bar", shield)


extends Window
## Local, read-only game encyclopedia. No session or authority dependency.
const E = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const TOPICS = [
	["Getting started", "Overview", "opening start strategy time victory basics"],
	["Economy", "Resources", "metals organics crystals antimatter mining stock production"],
	["Economy", "Population & food", "growth doubling reserve farming starvation settlements habitat"],
	["Economy", "Mining & salvage", "miner asteroid crystals cargo repair debris"],
	["Economy", "Trade & storage", "freighter logistics import export warehouse thresholds blockade"],
	["Expansion", "Colonization & territory", "settlement colony neutral systems conquest planetless"],
	["Expansion", "Stations & infrastructure", "build upgrades housing refinery farms incubator warehouse"],
	["Fleet", "Ships & construction", "fighter miner colony logistics crew build queue costs shipyard"],
	["Fleet", "Combat & defense", "laser pds armor plating matrix repair retreat"],
	["Interface", "Controls & commands", "keyboard hotkeys camera movement patrol rally attack shift ctrl"],
	["Interface", "Multiplayer & time", "host guest authority lobby teams ai pause speed"]
]
const SERIES_COLORS = [Color("#8ed779"), Color("#62cbe8"), Color("#e9bd76")]
var search_box: LineEdit
var navigation: ItemList
var article_scroll: ScrollContainer
var article: VBoxContainer
var active_topic: int = 0

func _ready() -> void:
	title = "Warbound Codex"
	theme = HUD.create()
	# Keep document minimum sizes from growing the modal beyond its viewport.
	wrap_controls = false
	borderless = true
	unresizable = true
	transient = true
	exclusive = true
	close_requested.connect(hide)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", HUD.surface(Color("#0b1622"), Color("#42647e"), 14, 5))
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	frame.add_child(root)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	root.add_child(heading)
	var emblem := _label(heading, "WARBOUND  /  CODEX", 20, HUD.ACCENT)
	emblem.autowrap_mode = TextServer.AUTOWRAP_OFF
	emblem.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	emblem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emblem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var version := _label(heading, "v%s" % ProjectSettings.get_setting("application/config/version"), 12, HUD.MUTED)
	version.autowrap_mode = TextServer.AUTOWRAP_OFF
	version.size_flags_horizontal = Control.SIZE_SHRINK_END
	version.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var close := Button.new()
	close.text = "Close  ×"
	close.custom_minimum_size = Vector2(82, 32)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.pressed.connect(hide)
	heading.add_child(close)
	root.add_child(HSeparator.new())
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	root.add_child(split)
	var nav_panel := _panel(split, Color("#0a1420"), 10)
	nav_panel.custom_minimum_size.x = 188
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	nav_panel.add_child(nav)
	_label(nav, "KNOWLEDGE INDEX", 12, HUD.ACCENT)
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search topics…"
	search_box.clear_button_enabled = true
	nav.add_child(search_box)
	navigation = ItemList.new()
	navigation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation.custom_minimum_size.y = 0
	navigation.auto_height = false
	navigation.gui_input.connect(_navigation_motion)
	navigation.add_theme_stylebox_override("selected", _flat(Color("#204253"), 4))
	navigation.add_theme_stylebox_override("selected_focus", _flat(Color("#265369"), 4))
	navigation.add_theme_stylebox_override("hovered", _flat(Color("#172c3d"), 4))
	navigation.add_theme_constant_override("v_separation", 8)
	nav.add_child(navigation)
	_label(nav, "Match continues while reading.", 11, HUD.MUTED)
	var pane := _panel(split, Color("#0b1622"), 8)
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	article_scroll = ScrollContainer.new()
	article_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	article_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	article_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	article_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	article_scroll.clip_contents = true
	article_scroll.get_v_scroll_bar().mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pane.add_child(article_scroll)
	article = VBoxContainer.new()
	article.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	article.add_theme_constant_override("separation", 14)
	article.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	article.mouse_filter = Control.MOUSE_FILTER_IGNORE
	article_scroll.add_child(article)
	search_box.text_changed.connect(_rebuild_navigation)
	navigation.item_selected.connect(_select_topic)
	_rebuild_navigation("")

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		hide()

func _flat(background: Color, margin: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_content_margin_all(margin)
	return style

func _panel(parent: Container, background: Color, margin: int = 9) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat(background, margin))
	parent.add_child(p)
	return p

func _label(parent: Container, value: String, points: int = 14, tint: Color = HUD.TEXT) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", points)
	l.add_theme_color_override("font_color", tint)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

func _navigation_motion(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index: int = navigation.get_item_at_position(event.position, true)
		navigation.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if index >= 0 and navigation.is_item_selectable(index) else Control.CURSOR_ARROW

func _rebuild_navigation(query: String) -> void:
	navigation.clear()
	var previous: int = -1
	var section: String = ""
	for i in range(TOPICS.size()):
		var entry: Array = TOPICS[i]
		if not query.strip_edges().is_empty() and not (" ".join(PackedStringArray(entry))).to_lower().contains(query.strip_edges().to_lower()):
			continue
		if section != str(entry[0]):
			section = str(entry[0])
			navigation.add_item(section.to_upper())
			var header: int = navigation.item_count - 1
			navigation.set_item_selectable(header, false)
			navigation.set_item_custom_fg_color(header, HUD.MUTED)
		navigation.add_item("  " + str(entry[1]))
		var row: int = navigation.item_count - 1
		navigation.set_item_metadata(row, i)
		if i == active_topic:
			previous = row
	if previous >= 0:
		navigation.select(previous)
		_show_topic(active_topic)
	elif navigation.item_count > 1:
		navigation.select(1)
		_select_topic(1)
	else:
		_clear_article()
		_label(article, "No matching topics", 24, HUD.ACCENT)
		_label(article, "Try food, ship, mining, or controls.", 14, HUD.MUTED)
		_make_passive(article)
		article_scroll.set_deferred("scroll_vertical", 0)

func _select_topic(index: int) -> void:
	_show_topic(int(navigation.get_item_metadata(index)))

func _clear_article() -> void:
	for child in article.get_children():
		article.remove_child(child)
		child.queue_free()

func _show_topic(index: int) -> void:
	active_topic = index
	_clear_article()
	_label(article, str(TOPICS[index][0]).to_upper() + "  /  CODEX", 12, HUD.ACCENT)
	_label(article, str(TOPICS[index][1]), 27)
	article.add_child(HSeparator.new())
	match index:
		0: _overview()
		1: _resources()
		2: _population()
		3: _mining()
		4: _trade()
		5: _expansion()
		6: _infrastructure()
		7: _ships()
		8: _combat()
		9: _controls()
		10: _multiplayer()
	_make_passive(article)
	article_scroll.set_deferred("scroll_vertical", 0)

# All article elements are informational. Wheel input reaches the scroll pane.
func _make_passive(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_make_passive(child)

func _section(value: String) -> void:
	_label(article, value, 18, HUD.ACCENT)

func _body(value: String) -> void:
	_label(article, value, 14)

func _note(value: String) -> void:
	var p := _panel(article, Color("#101f2c"), 9)
	var style := _flat(Color("#101f2c"), 9)
	style.border_color = HUD.MUTED.darkened(0.4)
	style.border_width_left = 2
	p.add_theme_stylebox_override("panel", style)
	_label(p, value, 13, HUD.MUTED)

func _table(headers: Array, rows: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = headers.size()
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 1)
	article.add_child(grid)
	for h in headers:
		var head := _panel(grid, Color("#142635"), 7)
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := _flat(Color("#142635"), 7)
		style.border_color = Color("#345064")
		style.border_width_bottom = 1
		head.add_theme_stylebox_override("panel", style)
		_label(head, str(h), 12, HUD.ACCENT)
	for i in range(rows.size()):
		for value in rows[i]:
			var cell := _panel(grid, Color("#0f1e2b") if i % 2 == 0 else Color("#0b1622"), 7)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_label(cell, str(value), 13)

func _flow(names: Array) -> void:
	var p := _panel(article, Color("#0a131d"), 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	for i in range(names.size()):
		if i > 0:
			var arrow := _label(row, "→", 19, HUD.MUTED)
			arrow.custom_minimum_size.x = 24
			arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			arrow.autowrap_mode = TextServer.AUTOWRAP_OFF
			arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var l := _label(row, str(names[i]), 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _recipe(cost: Dictionary) -> String:
	var values: PackedStringArray = []
	for resource in E.RESOURCES:
		if cost.has(resource):
			values.append("%.0f %s" % [float(cost[resource]), resource])
	return " · ".join(values)

func _resource_card(resource: String, description: String) -> void:
	var p := _panel(article, Color("#0d1a25"), 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var image := TextureRect.new()
	HUD.fixed_icon(image, HUD.resource_icon(resource, 36), 36)
	row.add_child(image)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_label(text, resource, 18, HUD.COLORS[resource])
	_label(text, description)

func _overview() -> void:
	_body("Expand your empire through local economies, autonomous logistics and direct fleet command.")
	_section("The strategic loop")
	_flow(["Extract resources", "Build & recruit", "Expand", "Defend supply"])
	_body("Start with 3 miners, 2 fighters and 1 freighter. Select a unit or station to issue orders.")
	_section("First priorities")
	_table(["Goal", "Action"], [["Establish supplies", "Protect nearby asteroid fields and keep food reserves healthy."], ["Build a fleet", "Select a shipyard and queue miners, fighters or freighters."], ["Expand", "Send a colony ship to an eligible neutral system. Secure your trade lanes."], ["Survive", "Defend your stations and colony ships; defeat hostile teams by conquest."]])
	_note("Start with Population & food and Trade & storage.")

func _resources() -> void:
	_body("The empire uses three ordinary resources. Material prices are paid from local stock, not a shared global wallet.")
	_resource_card("Metals", "Primary construction material. Extracted from planets and asteroid fields; used in ships, buildings and upgrades.")
	_resource_card("Organics", "Food for residents and supplies for basic ships. Farming and imports improve local population growth.")
	_resource_card("Crystals", "Advanced construction material. Mine crystal-rich rocks or invest in local Crystal Incubators. Used in additional shipyards, planetary defense and Laser Matrix.")
	_section("Starting stock per home system")
	var rows: Array = []
	for r in E.RESOURCES:
		rows.append([r, "%.0f t" % float(E.STARTING_STOCK[r])])
	_table(["Resource", "Stock"], rows)
	_section("Raw antimatter")
	_body("Science vessels collect one unit at a Pulsar after 30 years in range. Antimatter remains aboard; uses come later.")

func _population() -> void:
	_body("Residents power production, staff shipyards and crew ships. Food and housing limit terrestrial growth.")
	_section("Food reserves and growth")
	_body("Growth scales with stored Organics up to %.0f t, independent of warehouse size. Food shortages and overcrowding slow growth further." % E.POPULATION_FOOD_RESERVE)
	var rows: Array = []
	for fraction in [1.0, 0.75, 0.5, 0.25, 0.0]:
		rows.append(["%.0f t" % (fraction * E.POPULATION_FOOD_RESERVE), "%.0f%%" % (fraction * 100.0), "%.0f years" % (E.POPULATION_DOUBLING_YEARS / fraction) if fraction > 0.0 else "No growth"])
	_table(["Organics reserve", "Growth ceiling", "Doubling time"], rows)
	_chart(false)
	_section("Illustrative population growth")
	_chart(true)
	_label(article, "Ideal growth from %.0f residents. Capacity limits and recruitment reduce actual growth." % E.HOME_POPULATION, 12, HUD.MUTED)
	_section("Orbital Eco-Housing")
	_body("Each completed shipyard and orbital housing module supports %.0f residents and produces %.1f t/yr Organics. These residents recover at a %.0f-year doubling rate and are exempt from terrestrial food and overcrowding penalties." % [E.ORBITAL_HOUSING_POPULATION, E.ECO_HOUSING_ORGANICS, E.POPULATION_DOUBLING_YEARS])
	_note("Keep Organics near the reserve target before spending food on ships. Colony ships require %.0f settlers; a starving system cannot grow its terrestrial population." % E.COLONY_POPULATION)

func _chart(population: bool) -> void:
	var panel := _panel(article, Color("#091420"), 10)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	panel.add_child(stack)
	_label(stack, "Population vs time" if population else "Growth multiplier vs stored Organics", 15)
	if population:
		var legend := HBoxContainer.new()
		stack.add_child(legend)
		for i in range(3):
			_label(legend, ["100% reserve", "50% reserve", "25% reserve"][i], 12, SERIES_COLORS[i])
	var canvas := Control.new()
	canvas.custom_minimum_size.y = 200
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(canvas)
	canvas.draw.connect(_draw_chart.bind(canvas, population))
	canvas.resized.connect(canvas.queue_redraw)
	_label(stack, "Years elapsed" if population else "Stored Organics (tons)", 12, HUD.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _draw_chart(canvas: Control, population: bool) -> void:
	var font: Font = canvas.get_theme_default_font()
	var origin := Vector2(52, canvas.size.y - 27)
	var extent := Vector2(maxf(1.0, canvas.size.x - 78), maxf(1.0, canvas.size.y - 43))
	var top: float = E.HOME_POPULATION * 4.0 if population else 100.0
	var end: float = E.POPULATION_DOUBLING_YEARS * 2.0 if population else E.POPULATION_FOOD_RESERVE * 1.25
	for i in range(5):
		var frac: float = float(i) / 4.0
		var y: float = origin.y - extent.y * frac
		canvas.draw_line(Vector2(origin.x, y), Vector2(origin.x + extent.x, y), Color("#243a50"))
		var tick: String = "%.0fk" % (top * frac / 1000.0) if population else "%.0f%%" % (top * frac)
		canvas.draw_string(font, Vector2(2, y + 4), tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HUD.MUTED)
	for i in range(5 if population else 6):
		var frac: float = float(i) / (4.0 if population else 5.0)
		var tick: String = "%.0f" % (end * frac)
		var x: float = origin.x + extent.x * frac
		var width: float = font.get_string_size(tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		canvas.draw_string(font, Vector2(x - width * 0.5, origin.y + 18), tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HUD.MUTED)
	canvas.draw_line(origin, origin - Vector2(0, extent.y), HUD.MUTED)
	canvas.draw_line(origin, origin + Vector2(extent.x, 0), HUD.MUTED)
	for series in range(3 if population else 1):
		var points := PackedVector2Array()
		for i in range(81):
			var t: float = end * float(i) / 80.0
			var fraction: float = [1.0, 0.5, 0.25][series]
			var y: float = E.HOME_POPULATION * pow(2.0, t / E.POPULATION_DOUBLING_YEARS * fraction) if population else 100.0 * minf(1.0, t / E.POPULATION_FOOD_RESERVE)
			points.append(origin + Vector2(extent.x * t / end, -extent.y * y / top))
		canvas.draw_polyline(points, SERIES_COLORS[series], 2.5, true)

func _mining() -> void:
	_body("Mining ships extract ore and transfer it to nearby waiting freighters (10 miner holds per freighter), or return to an owned depot. Cargo enters storage gradually within docking range. Select a miner and right-click a field or rock to assign it. Select a field to toggle Mining, Metals and Crystals on its command card.")
	_flow(["Asteroid field", "Miner cargo", "Station stock"])
	_table(["Mining statistic", "Value"], [["Cargo hold", "%.0f t" % E.MINER_CAPACITY], ["Nominal extraction", "%.0f t/yr" % E.MINER_RATE], ["Local resource ceiling", "%.0f t/yr" % E.PLANET_MINING_LIMIT], ["Field resource ceiling", "%.0f t/yr" % E.FIELD_MINING_LIMIT]])
	_section("Salvage & repair")
	_body("Destroyed ships can leave drifting salvage. Mining and freighters may collect it in safe space; miners prioritize reachable safe salvage. Wreck debris lasts %.0f–%.0f simulation years; cancelled construction salvage persists. Freighters salvage at one-quarter the mining ship rate. Miners repair friendly hulls, stations, yards and individual planetary defenses at %.0f HP/yr." % [E.SALVAGE_MIN_LIFETIME, E.SALVAGE_MAX_LIFETIME, E.MINER_REPAIR_RATE])
	_note("Fighters have no cargo hold. Use civilian ships to recover resources after battles.")

func _trade() -> void:
	_body("Every station has separate resource stockpiles and import/export settings. Freighters move surplus between friendly systems. With Auto-Trade enabled, idle ships wait within handoff range on the depot-facing side of miners, or at salvage sites containing at least a full hold; they deliver full or partial loads to owned stations and wait if storage is full. Trade surplus without an importer returns to owned storage. Dropoff: miners %.0f, freighters %.0f, colony ships %.0f t/yr." % [E.dropoff_rate("miner"), E.dropoff_rate("ship"), E.dropoff_rate("colony_ship")])
	_flow(["Source surplus", "Freighter in transit", "Destination deficit"])
	_section("Trade thresholds")
	_body("In the station Trade panel, the minimum slider is the desired import stock and the maximum slider marks the point above which goods may be exported. Both use local storage capacity; the Import and Export checkboxes toggle each independently.")
	var base: float = E.WAREHOUSE_CAPACITIES[0]
	_table(["Defaults at base storage", "Amount"], [["Import below %.0f%%" % E.DEFAULT_IMPORT_PERCENT, "%.0f t" % (base * E.DEFAULT_IMPORT_PERCENT / 100.0)], ["Export above %.0f%%" % E.DEFAULT_EXPORT_PERCENT, "%.0f t" % (base * E.DEFAULT_EXPORT_PERCENT / 100.0)], ["Freighter hold", "%.0f t" % E.CARGO_CAPACITY]])
	_section("Warehouse capacity per resource")
	var rows: Array = []
	for i in range(E.WAREHOUSE_CAPACITIES.size()):
		rows.append(["Base" if i == 0 else "Level %d" % i, "%.0f t" % float(E.WAREHOUSE_CAPACITIES[i]), "—" if i == 0 else _recipe(E.WAREHOUSE_COSTS[i - 1])])
	_table(["Tier", "Capacity", "Cost"], rows)
	_note("Empire totals include cargo in transit, but local construction uses delivered stock. Protect supply routes and avoid exporting essential food reserves.")

func _expansion() -> void:
	_body("Build a colony ship and direct it to a reachable neutral system. On arrival it establishes a station and shipyard. Settlers become the new colony population; existing colonies cannot be freely claimed.")
	_flow(["Recruit settlers", "Travel", "Establish colony"])
	_body("Colony ships farm %.0f t/yr into a %.0f t Organics hold. Auto-Farm delivers full loads when idle; Deliver Organics or right-click a friendly station to unload early. They cannot salvage." % [E.COLONY_FARM_RATE, E.COLONY_CAPACITY])
	_table(["Colony ship", "Requirement"], [["Crew", "%.0f people" % E.COLONY_POPULATION], ["Materials", _recipe(E._cost("colony_ship", 1))], ["Base build time", "%.0f years" % (E._work("colony_ship", 1) / E.yard_speed(1))]])
	_section("Planetless sectors & conquest")
	_body("Cool blue stars mark planetless sectors, useful for routes and mining access. They rely on orbital housing rather than terrestrial agriculture or mining. Defeat hostile defenses and occupy a system to contest territory. A system's claim depends on its station/population and infrastructure, not passing ships.")
	_note("A colony is a long-term economic investment. Food imports and local farming improve its growth, while fleets defend its shipping lanes.")

func _infrastructure() -> void:
	_body("Select a station and open Build. Infrastructure jobs are prepaid and advance in a shared sequential construction queue. Canceling a physical build drops all prepaid materials as persistent salvage. Non-standalone upgrades refund directly. Shipyards have independent hull queues.")
	_section("Resource production")
	var rows: Array = []
	for r in E.RESOURCES:
		var definition: Dictionary = E.ECONOMY_BUILDINGS[r]
		rows.append([definition["name"], _recipe(definition["cost"]), "%.0f%% baseline" % (E.BUILDING_BONUS * 100.0)])
	_table(["Building", "Materials", "Output bonus"], rows)
	_section("Shipyard modules")
	rows = []
	for i in range(1, E.MAX_SHIPYARDS + 1):
		rows.append(["Module %d" % i, _recipe(E._cost("yard", i))])
	_table(["Slot", "Materials"], rows)
	_body("Warehouse upgrades expand storage; habitation increases terrestrial housing capacity. Orbital Eco-Housing adds self-sufficient residents in planetless systems. Additional shipyards also supply eco-housing.")

func _ships() -> void:
	_body("Select a shipyard to construct ships. Costs are paid from the local station. Freighters have ten 10 t bays. Miners travel slower; fighters are 20% faster than freighters. Ship selection displays crew. Crew embarks gradually; an underpopulated station may be unable to start or resume an order. Canceled hulls drop all prepaid materials at the yard; crew returns. Eligible orders may repeat.")
	var rows: Array = []
	var names := {"fighter": "Fighter", "miner": "Mining ship", "ship": "Freighter", "colony_ship": "Colony ship", "science_ship": "Science vessel"}
	for kind in ["fighter", "miner", "ship", "colony_ship", "science_ship"]:
		rows.append([names[kind], _recipe(E._cost(kind, 1)), "%.0f" % float(E.CREW_COSTS[kind]), "%.0f yr" % (E._work(kind, 1) / E.yard_speed(1))])
	_table(["Ship", "Materials", "Crew", "Time (Lv 1)"], rows)
	_section("Shipyard upgrades")
	_body("Higher shipyard levels increase construction speed and staffing requirements. Select Space Station returns to the parent station. Clear Rally / Rally occupy the bottom-right slots. Rally points direct completed ships to their destination; idle fighters can engage enemies and civilian ships resume their jobs.")
	rows = []
	for i in range(1, E.MAX_SHIPYARD_LEVEL + 1):
		rows.append([str(i), "%.0f×" % (E.yard_speed(i) / E.yard_speed(1)), "%.0f" % float(E.SHIPYARD_POPULATION[i - 1])])
	_table(["Level", "Build speed", "Staff required"], rows)

func _combat() -> void:
	_body("Fighters seek hostile ships within their sector unless holding or executing a move-only order. Hold permits firing in range. Autocast cooldown after orders or arrival: Wander/Trade %.0f s, Mine/Salvage %.0f s at 1×; Repair and Farm have no cooldown. Follow keeps a safe distance from a friendly hull until replaced. New orders act immediately. Ships maintain spacing even on shared commands. Hold stops movement; damaged ships can withdraw and repair." % [E.AUTOCAST_COOLDOWN_YEARS, E.MINING_SALVAGE_COOLDOWN_YEARS])
	_table(["Weapon", "Damage / shot or volley", "Range"], [["Fighter laser", "%.0f" % E.LASER_DAMAGE, "%.0f" % E.LASER_RANGE], ["Mining lasers", "%.0f" % E.MINER_LASER_DAMAGE, "%.0f" % E.LASER_RANGE], ["Planetary defense", "%.0f" % E.PDS_DAMAGE, "%.0f" % E.PDS_RANGE]])
	_section("Station defenses")
	_table(["Upgrade", "Effect", "Materials"], [["Reinforced Plating", "%.0f → %.0f max HP" % [E.STATION_HP, E.REINFORCED_STATION_HP], _recipe(E._cost("reinforced_plating", 1))], ["Laser Matrix", "%d defensive lasers" % E.STATION_LASER_COUNT, _recipe(E._cost("laser_matrix", 1))], ["PDS", "Planetary defense battery", _recipe(E._cost("pds", 1))]])
	_note("Use coordinated attack groups, protect miners and freighters, and retreat before losing ships and their crew investment.")

func _controls() -> void:
	_note("Default hotkeys. Menu → Hotkeys changes bindings; camera speed sliders adjust keyboard, mouse edge and wheel zoom.")
	_table(["Input", "Action"], [["Left click / drag", "Select a ship, structure or fleet"], ["Shift + select", "Add to selection"], ["Right click / drag", "Contextual order / formation"], ["Right click friendly ship", "Follow until replaced"], ["A / M / P, then click", "Attack / move / patrol"], ["S / H", "Stop / hold"], ["L / D / R, then click", "Load / drop cargo / repair"], ["Y, then click / X", "Set / clear shipyard rally"], ["Shift + order", "Queue an order"], ["Arrows / screen edge / middle drag", "Pan camera"], ["Mouse wheel", "Zoom; ships enlarge up to 12×, structures up to 4×"], ["F", "Follow or focus selection"], ["F2", "Select all owned fighters"], ["Double F2", "Center military selection"], ["Ctrl + 0–9", "Assign control group"], ["Shift + 0–9", "Add selection to group"], ["0–9 / double tap", "Recall / center group"], ["B / T (station)", "Build / trade"], ["Esc", "Cancel targeting, return or menu"]])
	_body("Wander, Auto-Mine, Auto-Salvage, Auto-Repair, Auto-Trade and Auto-Farm toggle with either mouse button. Modes occupy the bottom row (extra modes above for mixed fleets). Lit borders show enabled modes; clock masks show cooldown. Enabling Wander clears its cooldown only; active orders and Hold take priority.")
	_body("Click a star to target its sector boundary; drag from a star to target the whole sector. Alt forces precise positioning. Use the minimap to navigate or issue contextual orders. Command-card buttons expose additional actions and tooltips; right-click eligible production cards to repeat.")

func _multiplayer() -> void:
	_body("Warbound supports up to eight players, flexible teams and AI opponents in solo and multiplayer. The host owns the simulation and validates commands. Guests view synchronized state and issue requests.")
	_section("Simulation clock")
	_table(["Speed", "Simulation time"], [["Pause", "No simulated time passes"], ["1×", "1 year per second"], ["2×", "2 years per second"], ["5×", "5 years per second"]])
	_body("Connected players can request shared time controls. The Codex and Menu are local interface windows; reading them does not pause a multiplayer match. Use the time controls if the match needs to stop.")
	_note("Balance values are provisional during development. Read the current in-game tooltips for the exact costs and conditions of a selected entity.")

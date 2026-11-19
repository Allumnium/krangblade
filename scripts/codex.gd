extends AcceptDialog
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
	exclusive = true
	dialog_close_on_escape = true
	ok_button_text = "Close"
	HUD.action(get_ok_button())
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var heading := HBoxContainer.new()
	root.add_child(heading)
	var emblem := _label(heading, "WARBOUND  /  FIELD MANUAL", 21, HUD.ACCENT)
	emblem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(heading, "REFERENCE  ·  %s" % ProjectSettings.get_setting("application/config/version"), 12, HUD.MUTED)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	root.add_child(split)
	var nav_panel := _panel(split, Color("#0a1420"), 10)
	nav_panel.custom_minimum_size.x = 205
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
	navigation.custom_minimum_size.y = 230
	navigation.add_theme_constant_override("v_separation", 8)
	nav.add_child(navigation)
	_label(nav, "The match continues while you read.", 12, HUD.MUTED)
	var pane := _panel(split, Color("#0b1725"), 14)
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	article_scroll = ScrollContainer.new()
	article_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane.add_child(article_scroll)
	article = VBoxContainer.new()
	article.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	article.add_theme_constant_override("separation", 11)
	article_scroll.add_child(article)
	search_box.text_changed.connect(_rebuild_navigation)
	navigation.item_selected.connect(_select_topic)
	_rebuild_navigation("")

func _panel(parent: Container, background: Color, margin: int = 9) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", HUD.surface(background, Color("#29455d"), margin, 5))
	parent.add_child(p)
	return p

func _label(parent: Container, value: String, points: int = 14, tint: Color = HUD.TEXT) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", points)
	l.add_theme_color_override("font_color", tint)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

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
		navigation.add_item(str(entry[1]))
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
	article_scroll.set_deferred("scroll_vertical", 0)

func _section(value: String) -> void:
	_label(article, value, 18, HUD.ACCENT)

func _body(value: String) -> void:
	_label(article, value, 14)

func _note(value: String) -> void:
	var p := _panel(article, Color("#122535"))
	_label(p, value, 13, Color("#b9d9ed"))

func _table(headers: Array, rows: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = headers.size()
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	article.add_child(grid)
	for h in headers:
		var head := _panel(grid, Color("#1a3548"), 6)
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(head, str(h), 12, HUD.ACCENT)
	for i in range(rows.size()):
		for value in rows[i]:
			var cell := _panel(grid, Color("#101f30") if i % 2 == 0 else Color("#0d1a29"), 6)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_label(cell, str(value), 13)

func _flow(names: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	article.add_child(row)
	for i in range(names.size()):
		if i > 0:
			_label(row, "→", 18, HUD.ACCENT).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var p := _panel(row, Color("#152d40"))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := _label(p, str(names[i]), 13)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _recipe(cost: Dictionary) -> String:
	var values: PackedStringArray = []
	for resource in E.RESOURCES:
		if cost.has(resource):
			values.append("%.0f %s" % [float(cost[resource]), resource])
	return " · ".join(values)

func _resource_card(resource: String, description: String) -> void:
	var p := _panel(article, Color("#112235"))
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
	_body("Warbound is a territory-control RTS. Build an empire through planetary development, autonomous logistics and direct fleet command. Systems hold their own inventories; control of the routes between them matters.")
	_section("The strategic loop")
	_flow(["Extract resources", "Build & recruit", "Expand", "Defend supply"])
	_body("Your home system begins with a station, shipyard, population and a small fleet. Miners gather ore, logistics ships distribute surplus, and fighters protect territory. Select an object to inspect it or issue commands in the lower console.")
	_section("First priorities")
	_table(["Goal", "Action"], [["Establish supplies", "Protect nearby asteroid fields and keep food reserves healthy."], ["Build a fleet", "Select a shipyard and queue miners, fighters or logistics ships."], ["Expand", "Send a colony ship to an eligible neutral system. Secure your trade lanes."], ["Survive", "Defend your stations and colony ships; defeat hostile teams by conquest."]])
	_note("Read Population & food, then Trade & storage, to understand the two main economic constraints.")

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
	_body("A separate rare material extracted from special deposits. It can be collected and delivered; advanced construction recipes are reserved for future gameplay.")

func _population() -> void:
	_body("Residents power production, staff shipyards and provide crew. Terrestrial population grows fastest when food reserves and habitation are sufficient. Orbital habitats are self-sustaining.")
	_section("Food reserves and growth")
	_body("Positive terrestrial growth is multiplied by the local Organics stock divided by %.0f t, capped at 100%%. A larger warehouse never reduces this multiplier. Food shortages and habitation pressure can slow growth further." % E.POPULATION_FOOD_RESERVE)
	var rows: Array = []
	for fraction in [1.0, 0.75, 0.5, 0.25, 0.0]:
		rows.append(["%.0f t" % (fraction * E.POPULATION_FOOD_RESERVE), "%.0f%%" % (fraction * 100.0), "%.0f years" % (E.POPULATION_DOUBLING_YEARS / fraction) if fraction > 0.0 else "No growth"])
	_table(["Organics reserve", "Growth ceiling", "Doubling time"], rows)
	_chart(false)
	_section("Illustrative population growth")
	_chart(true)
	_label(article, "Ideal exponential ceilings from %.0f residents at fixed reserve levels. Actual growth slows near habitation and food-supported capacity; recruitment reduces population." % E.HOME_POPULATION, 12, HUD.MUTED)
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
	canvas.custom_minimum_size.y = 208
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(canvas)
	canvas.draw.connect(_draw_chart.bind(canvas, population))
	canvas.resized.connect(canvas.queue_redraw)
	_label(stack, "Years elapsed" if population else "Stored Organics (tons)", 12, HUD.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _draw_chart(canvas: Control, population: bool) -> void:
	var font: Font = canvas.get_theme_default_font()
	var origin := Vector2(52, canvas.size.y - 27)
	var extent := Vector2(maxf(1.0, canvas.size.x - 68), maxf(1.0, canvas.size.y - 43))
	var top: float = E.HOME_POPULATION * 4.0 if population else 100.0
	var end: float = E.POPULATION_DOUBLING_YEARS * 2.0 if population else E.POPULATION_FOOD_RESERVE * 1.25
	for i in range(5):
		var frac: float = float(i) / 4.0
		var y: float = origin.y - extent.y * frac
		var x: float = origin.x + extent.x * frac
		canvas.draw_line(Vector2(origin.x, y), Vector2(origin.x + extent.x, y), Color("#243a50"))
		var tick: String = "%.0fk" % (top * frac / 1000.0) if population else "%.0f%%" % (top * frac)
		canvas.draw_string(font, Vector2(2, y + 4), tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HUD.MUTED)
		canvas.draw_string(font, Vector2(x - 10, origin.y + 18), "%.0f" % (end * frac), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HUD.MUTED)
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
	_body("Mining ships automatically seek reachable fields, extract ore and return to an owned depot. Cargo is not spendable until unloaded. Select a miner and right-click a field or individual rock to assign it manually.")
	_flow(["Asteroid field", "Miner cargo", "Station stock"])
	_table(["Mining statistic", "Value"], [["Cargo hold", "%.0f t" % E.MINER_CAPACITY], ["Nominal extraction", "%.0f t/yr" % E.MINER_RATE], ["Local resource ceiling", "%.0f t/yr" % E.PLANET_MINING_LIMIT], ["Field resource ceiling", "%.0f t/yr" % E.FIELD_MINING_LIMIT]])
	_section("Salvage & repair")
	_body("Destroyed ships can leave drifting salvage. Cargo-capable ships may collect it in safe space; miners prioritize reachable safe salvage. Debris lasts %.0f–%.0f simulation years. Miners can also repair friendly hulls and structures at %.0f HP/yr." % [E.SALVAGE_MIN_LIFETIME, E.SALVAGE_MAX_LIFETIME, E.MINER_REPAIR_RATE])
	_note("Fighters have no cargo hold. Use civilian ships to recover resources after battles.")

func _trade() -> void:
	_body("Every station has separate resource stockpiles and import/export settings. Logistics ships travel physically between friendly or allied systems, moving surplus to systems with unmet demand.")
	_flow(["Source surplus", "Freighter in transit", "Destination deficit"])
	_section("Trade thresholds")
	_body("In the station Trade panel, the minimum slider is the desired import stock and the maximum slider marks the point above which goods may be exported. Both are percentages of actual local storage; imports and exports may be toggled separately.")
	var base: float = E.WAREHOUSE_CAPACITIES[0]
	_table(["Example at base storage", "Amount"], [["10% import target", "%.0f t" % (base * 0.1)], ["20% export target", "%.0f t" % (base * 0.2)], ["Freighter hold", "%.0f t" % E.CARGO_CAPACITY]])
	_section("Warehouse capacity per resource")
	var rows: Array = []
	for i in range(E.WAREHOUSE_CAPACITIES.size()):
		rows.append(["Base" if i == 0 else "Level %d" % i, "%.0f t" % float(E.WAREHOUSE_CAPACITIES[i]), "—" if i == 0 else _recipe(E.WAREHOUSE_COSTS[i - 1])])
	_table(["Tier", "Capacity", "Cost"], rows)
	_note("Empire totals include cargo in transit, but local construction uses delivered stock. Protect supply routes and avoid exporting essential food reserves.")

func _expansion() -> void:
	_body("Build a colony ship and direct it to a reachable neutral system. On arrival it establishes a station and shipyard. Settlers become the new colony population; existing colonies cannot be freely claimed.")
	_flow(["Recruit settlers", "Travel", "Establish colony"])
	_table(["Colony ship", "Requirement"], [["Crew", "%.0f people" % E.COLONY_POPULATION], ["Materials", _recipe(E._cost("colony_ship", 1))], ["Base build time", "%.0f years" % (E._work("colony_ship", 1) / E.yard_speed(1))]])
	_section("Planetless sectors & conquest")
	_body("Planetless sectors are useful for routes and mining access. They rely on orbital housing rather than terrestrial agriculture or mining. Defeat hostile defenses and occupy a system to contest territory. A system's claim depends on its station/population and infrastructure, not passing ships.")
	_note("A colony is a long-term economic investment. Food imports and local farming improve its growth, while fleets defend its shipping lanes.")

func _infrastructure() -> void:
	_body("Select a station and open Build. Infrastructure jobs are prepaid and advance in a shared sequential construction queue. Canceling refunds allocated materials. Shipyards have independent hull queues.")
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
	_body("Select a shipyard to construct ships. Costs are paid from the local station. Crew embarks gradually; an underpopulated station may be unable to start or resume an order. Queued work can be canceled and eligible orders repeated.")
	var rows: Array = []
	var names := {"fighter": "Fighter", "miner": "Mining ship", "ship": "Logistics ship", "colony_ship": "Colony ship"}
	for kind in ["fighter", "miner", "ship", "colony_ship"]:
		rows.append([names[kind], _recipe(E._cost(kind, 1)), "%.0f" % float(E.CREW_COSTS[kind]), "%.0f yr" % (E._work(kind, 1) / E.yard_speed(1))])
	_table(["Ship", "Materials", "Crew", "Time (Lv 1)"], rows)
	_section("Shipyard upgrades")
	_body("Higher shipyard levels increase construction speed and staffing requirements. Rally points direct completed ships to their destination; idle fighters can engage enemies and civilian ships resume their jobs.")
	rows = []
	for i in range(1, E.MAX_SHIPYARD_LEVEL + 1):
		rows.append([str(i), "%.0f×" % (E.yard_speed(i) / E.yard_speed(1)), "%.0f" % float(E.SHIPYARD_POPULATION[i - 1])])
	_table(["Level", "Build speed", "Staff required"], rows)

func _combat() -> void:
	_body("Fighters engage hostile targets automatically when idle or attack-moving. Direct attack orders prioritize the designated target. Hold position keeps ships in place; damaged ships can withdraw and repair.")
	_table(["Weapon", "Damage / shot or volley", "Range"], [["Fighter laser", "%.0f" % E.LASER_DAMAGE, "%.0f" % E.LASER_RANGE], ["Mining lasers", "%.0f" % E.MINER_LASER_DAMAGE, "%.0f" % E.LASER_RANGE], ["Planetary defense", "%.0f" % E.PDS_DAMAGE, "%.0f" % E.PDS_RANGE]])
	_section("Station defenses")
	_table(["Upgrade", "Effect", "Materials"], [["Reinforced Plating", "%.0f → %.0f max HP" % [E.STATION_HP, E.REINFORCED_STATION_HP], _recipe(E._cost("reinforced_plating", 1))], ["Laser Matrix", "%d defensive lasers" % E.STATION_LASER_COUNT, _recipe(E._cost("laser_matrix", 1))], ["PDS", "Planetary defense battery", _recipe(E._cost("pds", 1))]])
	_note("Use coordinated attack groups, protect miners and freighters, and retreat before losing ships and their crew investment.")

func _controls() -> void:
	_table(["Input", "Action"], [["Left click / drag", "Select a ship, structure or fleet"], ["Shift + select", "Add to selection"], ["Right click / drag", "Contextual move, attack, mine or rally / formation"], ["Shift + order", "Queue an order"], ["Middle drag / WASD", "Pan camera"], ["Mouse wheel", "Zoom"], ["F", "Follow or focus selection"], ["F2", "Select all owned fighters"], ["Double F2", "Center military selection"], ["Q / E", "Cycle owned systems"], ["H", "Hold position"], ["U", "Unload cargo"], ["Ctrl + 0–9", "Assign control group"], ["0–9 / double tap", "Recall / center group"], ["Esc", "Open or close menu / Codex"]])
	_body("Use the minimap to navigate or issue contextual orders. Command-card buttons expose additional actions and tooltips; right-click eligible production cards to repeat.")

func _multiplayer() -> void:
	_body("Warbound supports up to eight players, flexible teams and AI opponents in solo and multiplayer. The host owns the simulation and validates commands. Guests view synchronized state and issue requests.")
	_section("Simulation clock")
	_table(["Speed", "Simulation time"], [["Pause", "No simulated time passes"], ["1×", "1 year per second"], ["2×", "2 years per second"], ["5×", "5 years per second"]])
	_body("Connected players can request shared time controls. The Codex and Menu are local interface windows; reading them does not pause a multiplayer match. Use the time controls if the match needs to stop.")
	_note("Balance values are provisional during development. Read the current in-game tooltips for the exact costs and conditions of a selected entity.")

extends Window
## Local, read-only game encyclopedia. No session or authority dependency.
const E = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const UI_TEXT = preload("res://scripts/ui_text.gd")
const TOPICS = [
	["Getting started", "Overview", "opening start strategy time victory basics"],
	["Economy", "Resources", "metals organics crystals antimatter mining stock production galactic credits currency taxes treasury gc"],
	["Economy", "Population & food", "growth doubling reserve farming starvation settlements habitat"],
	["Economy", "Mining & salvage", "miner asteroid crystals cargo repair debris"],
	["Economy", "Trade & storage", "freighter logistics import export warehouse thresholds blockade"],
	["Expansion", "Colonization & territory", "settlement colony neutral systems conquest planetless"],
	["Expansion", "Stations & infrastructure", "build upgrades housing refinery farms incubator warehouse"],
	["Fleet", "Ships & construction", "fighter miner colony logistics crew build queue costs shipyard constructor depot"],
	["Fleet", "Combat & defense", "laser pds armor plating matrix repair retreat"],
	["Interface", "Controls & commands", "keyboard hotkeys camera movement patrol rally attack shift ctrl"],
	["Interface", "Multiplayer & time", "host guest authority lobby teams ai"]
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
	close.text = "Close"
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

func _recipe(cost: Dictionary, kind: String = "") -> String:
	var values: PackedStringArray = []
	for resource in E.RESOURCES:
		if cost.has(resource):
			values.append("%.0f %s" % [float(cost[resource]), resource])
	if not cost.is_empty():
		values.append("%.0f GC" % E.construction_credit_cost(cost, kind))
	return " · ".join(values)

func _resource_card(resource: String, description: String, display_name: String = "") -> void:
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
	_label(text, resource if display_name.is_empty() else display_name, 18, HUD.COLORS[resource])
	_label(text, description)

func _overview() -> void:
	_body("Expand through local economies and direct fleet command. The default logistics lens marks local resource strengths (+/++) and weaknesses (-/--). Population appears beside storage, to the left of the objectives at normal window widths. White chevrons show net gain (right) or loss (left), relative to capacity or treasury balance (GC has no cap). More chevrons mean faster change. Full stores with no net gain show no arrows. Hover for exact rates. Each completed objective earns 1 conquest point. At match start, the explored radius around home territory is three times its initial visible claim radius. This is remembered terrain, not permanent live vision. Own and consenting allied sensors reveal nearby space; previously explored areas darken when vision is lost. Discovered stars remain selectable with last-seen details. Asteroid rings and static clusters are visible and selectable only in current sight; neither appears on the minimap or lobby preview. Colonize (C) can target remembered neutral systems, subject to host validation. Scouts have 2,700 sight range. Toggle Explore (X; off by default) to reveal unexplored space first, then revisit areas outside current vision. Scouts choose free-space destinations and spread out without an arrival cooldown. Wander (W) starts enabled and stays near the current idle location; enabling either turns the other off. Rounded player-colored territories mark discovered completed infrastructure; fleets do not affect territory. Fleet movement, colonization, mining and logistics travel directly to their destinations. All ships can pass freely through orbiting and static asteroids. Harvesters follow moving ore. Crystal-bearing rocks have pink mineral coloration. Territory does not restrict manual flight; logistics overlays show owned shipments only. Box selection includes all visible ships, military and civilian. Spend a completed goal's CP before receiving another; new goals must have unmet targets. One Economic and Military goal each; Tech unlocks after three economic goals or first antimatter collection. Opening Economic goal: upgrade a shipyard to Medium. Opening Military goal: build 7 fighters. Both can be refreshed immediately; subsequent goals are randomly drawn from eligible unmet targets. Other goals include building colony ships, colonizing systems, producing colony food, holding Metals (stock and cargo), growing total population and destroying enemy ships. The square refresh button draws another eligible goal in its category every 60 s; Upgrade pulses when available and spends that category's CP. Your objective and unique unlock notices fade above the minimap; personal objectives play a reward chime, with a longer first-place fanfare. The scoreboard beneath objectives lists each player's lifetime earned Economic, Military and Tech CP; +/− collapses or expands it. Enter opens scrollable chat and notification history above the minimap. Enter sends, Esc closes. Recent messages fade upward from the minimap. Music and SFX volume/mute are in Settings. Match music shuffles and repeats; nearby combat is louder, distant battles quieter. Each empire starts with three Harvesters, two Fighters, a Freighter and a Science Vessel. Spend category CP on three upgrade choices. Rankable research stacks additive base bonuses or diminishing cost reductions; one-time specializations grant moderate bonuses. Advanced technologies remain one-time and retain prerequisites. Lifetime objectives continue through rising tiers. Each purchase redraws if CP remain. Purple UNIQUE cards (Cloaking, Shields 3, Warp Gates, Crystalline Synthesis) are reserved permanently by the first player to select them. Competing offers refresh without spending CP. Military Shields 1–3 absorb damage before hulls; recharge 5% per second after 5 s without damage. World health and shield bars appear independently only when damaged; active shields glow along hull outlines. Off-camera friendly damage and approaching enemy combat fleets generate clickable warnings; click to center the camera. Armor reduces military hull damage by 15%. Additional construction costs appear in the command information panel. Cloaking replaces Scout shields/armor: translucent while cloaked, hidden beyond ordinary enemy detection (250 range), revealed 5 s after firing. Science vessels and Space Stations detect cloaked units across their normal sight radius. Science Vessel Scan (Q) launches a free cloaked, uncommandable probe; it travels to the selected point and provides ship-like vision for 30 years after arrival. Scan cooldown: 30 years. Tech Warp Gates consume one antimatter vessel at an owned system. Select a gate and press J to cycle links; right-click a linked owned gate with ships to travel. 10 s per-ship cooldown. F4 maintains empire fleet targets (any integer from 0–500 per ship type) at owned shipyards; existing ships and queued hulls count. Group station construction orders apply to every eligible selected station.")
	_section("The strategic loop")
	_flow(["Extract resources", "Build & recruit", "Expand", "Defend supply"])
	_body("Start with a station, Small shipyard, 3 Harvesters, 2 Fighters, 1 Freighter and 1 Science Vessel. Build resource production and additional shipyards yourself.")
	_section("First priorities")
	_table(["Goal", "Action"], [["Establish supplies", "Protect nearby asteroid fields and keep food reserves healthy."], ["Build a fleet", "Select a shipyard and queue Harvesters, fighters or freighters."], ["Expand", "Send a Colony to an eligible neutral system. Secure your trade lanes."], ["Survive", "Defend stations and ships. Defeat empires by removing their stations and colony recovery options. Surviving ships remain autonomous; defeated players observe the full map without objectives. Remaining GC is split equally among surviving allies, if any."]])
	_note("Start with Population & food and Trade & storage.")

func _resources() -> void:
	_body("The empire uses three ordinary resources measured in units; no tonnage. Material prices are paid from local stock, not a shared global wallet.")
	_resource_card("Metals", "Primary construction material. Mine asteroid fields or build planetary Refineries. Used in ships, buildings and upgrades.")
	_resource_card("Organics", "Food for population and colonization. Build Farms or import food; orbital Eco-Housing and Colony Ships can also produce it.")
	_resource_card("Crystals", "Advanced construction material. Mine crystal-rich rocks or build Incubators. Stations have no free resource production.")
	_section("Starting stock per home system")
	var rows: Array = []
	for r in E.RESOURCES:
		rows.append([r, "%.0f" % float(E.STARTING_STOCK[r])])
	_table(["Resource", "Stock"], rows)
	_resource_card("GC", "Empire-wide currency. Start with %.0f GC. Base income: %.0f GC/year per empire, plus annual taxes of %.1f%% of resident population. Ship crews are excluded. The HUD shows total income minus fleet upkeep." % [E.STARTING_GC, E.BASE_GALACTIC_INCOME, E.RESIDENT_TAX_RATE * 100.0], "Galactic Credits (GC)")
	_body("Construction reserves GC and local materials immediately. Base fee: %.0f%% of material value (rounded to 5); small/medium/large ships pay 2×/3×/4×. Cancel for a full GC refund; destroyed projects lose their fee. Colony transformation is prepaid; Warp Gates cost %.0f GC plus antimatter." % [E.CONSTRUCTION_CREDIT_FRACTION * 100.0, E.WARP_GATE_CREDIT_COST])
	_body("Completed ships require continuous GC upkeep. Taxes pay first, civilian ships before military ships. Unpaid wages trigger warnings; payment restores good standing. Stations and gates are upkeep-free.")
	_body("After %.0f unpaid years, each ship has a %.1f%% chance per %.0f years of going rogue. It leaves your control with its cargo and crew, clears all orders and flees empire territory before becoming a gray pirate. Pirates form independent roaming groups, seek vulnerable ships and retreat from stronger forces. They have no bases, economy or empire diplomacy." % [E.ROGUE_GRACE_YEARS, E.ROGUE_CHANCE * 100.0, E.ROGUE_CHECK_YEARS])
	_section("Raw antimatter")
	_body("Science vessels follow sector lanes to a Pulsar, then collect one unit after 30 years in range. Collect Antimatter (C), then choose a Pulsar; right-click the ability to enable autocast (off by default). Antimatter is indivisible. Science vessels collect one item and keep it aboard; other eligible cargo holds and stations can store at most one. Resource Depots cannot store it.")

func _population() -> void:
	_body("Population is measured in Pop (1 Pop represents 100 people). Pop powers production, staffs shipyards and crews ships. They consume only Organics. Food and housing limit terrestrial growth.")
	_section("Food reserves and growth")
	_body("Growth scales with stored Organics up to %.0f, independent of warehouse size. Food shortages and overcrowding slow growth further." % E.POPULATION_FOOD_RESERVE)
	var rows: Array = []
	for fraction in [1.0, 0.75, 0.5, 0.25, 0.0]:
		rows.append(["%.0f" % (fraction * E.POPULATION_FOOD_RESERVE), "%.0f%%" % (fraction * 100.0), "%.0f years" % (E.POPULATION_DOUBLING_YEARS / fraction) if fraction > 0.0 else "No growth"])
	_table(["Organics reserve", "Growth ceiling", "Doubling time"], rows)
	_chart(false)
	_body("Ship crews count toward empire population, not local labor or food demand. The resident portion of the population bar fills toward sustainable capacity: the lower of farm support and habitation, plus orbital housing. Base habitation is 5,000 Pop, scaled by system size; upgrades double it. Crowding reduces growth by occupancy cubed.")
	_section("Illustrative population growth")
	_chart(true)
	_label(article, "Ideal growth from %.0f Pop. Capacity limits and recruitment reduce actual growth." % E.HOME_POPULATION, 12, HUD.MUTED)
	_section("Orbital Eco-Housing")
	_body("Each completed shipyard and orbital housing module supports %.0f Pop. Only dedicated orbital housing produces %.2f/yr Organics. These residents recover at a %.0f-year doubling rate and are exempt from terrestrial food and overcrowding penalties." % [E.ORBITAL_HOUSING_POPULATION, E.ECO_HOUSING_ORGANICS, E.POPULATION_DOUBLING_YEARS])
	_note("Keep Organics near the reserve target before spending food on ships. Colonies require %.0f settlers and %.0f Pop at the originating station." % [E.COLONY_POPULATION, E.COLONY_MIN_ORIGIN_POPULATION])

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
	_label(stack, "Years elapsed" if population else "Stored Organics", 12, HUD.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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
		var tick: String = "%.0f" % (top * frac) if population else "%.0f%%" % (top * frac)
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
	_body("Harvesters extract ore and transfer it to nearby freighters, even while traveling (10 Harvester holds per freighter), or return to an owned depot. Loaded Harvesters seek a nearby available mining Freighter when a rendezvous is faster than returning to storage. A passing freighter can also interrupt deliveries; empty Harvesters immediately reassess work. Cargo enters storage gradually within doubled docking and handoff range; ships seek separated berths near the edge of transfer range. Select a Harvester and right-click a specific asteroid to mine it, or empty space within a field to move to that exact point. Shift queues these orders. Explicit Move also reaches any point in the field. Select a visible rock to inspect its ore. Asteroid belts are not selectable.")
	_flow(["Asteroid field", "Miner cargo", "Station stock"])
	_table(["Mining statistic", "Value"], [["Cargo hold", "%.0f" % E.MINER_CAPACITY], ["Nominal extraction", "%.1f/yr" % E.MINER_RATE], ["Field resource ceiling", "%.0f/yr" % E.FIELD_MINING_LIMIT]])
	_section("Salvage & repair")
	_body("Destroyed ships can leave drifting salvage. Harvesters and freighters may collect it in safe space; Idle Harvesters and Freighters search safe debris up to %d sector links and %.0f straight-line units away. Harvesters prioritize scraps over ore. Wreck debris lasts %.0f–%.0f simulation years. Freighters salvage at one-quarter the Harvester rate. Harvesters and Science vessels repair friendly/allied hulls, stations, shipyards and planetary defenses at %.0f and %.0f HP/yr. Idle ships stop wandering while repaired." % [E.AUTO_SALVAGE_HOPS, E.AUTO_SALVAGE_RANGE, E.SALVAGE_MIN_LIFETIME, E.SALVAGE_MAX_LIFETIME, E.MINER_REPAIR_RATE, E.SCIENCE_REPAIR_RATE])
	_note("Fighters have no cargo hold. Use civilian ships to recover resources after battles.")

func _trade() -> void:
	_body("Tiny resource-colored cargo pods show planetary production flowing to the station. Planetary upgrades activate after a larger delivery pod arrives (3 s). Planet surface colors indicate resources (green Organics, gray Metals, purple Crystals). Select a planet for output in/yr. Right-click a known neutral star with a selected Colony to settle it automatically; Shift queues settlement after existing orders. Unclaimed sectors offer Colonize (C), dispatching the nearest unassigned eligible Colony, regardless of current movement, retreat or local work; only an active colonization assignment reserves a ship. The card shows Colony En Route while assigned. Hostile ships in the sector blockade planetary output; orbital housing production continues. Every station has separate resource stockpiles and import/export settings. Dedicated colored storage circles show fill; particles trace actual cargo transfers. Freighters move surplus between friendly systems. With Auto-Trade enabled, idle Freighters assign mining support by worker output and delivery distance, choose loading berths by worker readiness and trip time, then use remaining ships for interstation trade or salvage sites containing at least a full hold. Mining Freighters compare waiting or another nearby pickup against the depot round trip and haul when full or further collection is too slow. Salvage waiters depart after 8 yr without cargo. Deliveries go to owned stations and wait if storage is full. Trade surplus without an importer returns to owned storage. Dropoff: Harvesters %.0f, freighters %.0f, Colonies %.0f/yr." % [E.dropoff_rate("miner"), E.dropoff_rate("ship"), E.dropoff_rate("colony_ship")])
	_flow(["Source surplus", "Freighter in transit", "Destination deficit"])
	_section("Trade thresholds")
	_body("In the station Trade panel, the minimum slider is the desired import stock and the maximum slider marks the point above which goods may be exported. Both use local storage capacity; the Import and Export checkboxes toggle each independently.")
	var base: float = E.WAREHOUSE_CAPACITIES[0]
	_table(["Defaults at base storage", "Metals", "Other resources"], [["Import below %.0f%%" % E.DEFAULT_IMPORT_PERCENT, "%.0f" % (E.BASE_METAL_CAPACITY * E.DEFAULT_IMPORT_PERCENT / 100.0), "%.0f" % (base * E.DEFAULT_IMPORT_PERCENT / 100.0)], ["Export above %.0f%%" % E.DEFAULT_EXPORT_PERCENT, "%.0f" % (E.BASE_METAL_CAPACITY * E.DEFAULT_EXPORT_PERCENT / 100.0), "%.0f" % (base * E.DEFAULT_EXPORT_PERCENT / 100.0)], ["Freighter hold", "%.0f" % E.CARGO_CAPACITY, "Shared"]])
	_section("Warehouse capacity per resource")
	var rows: Array = []
	for i in range(E.WAREHOUSE_CAPACITIES.size()):
		rows.append(["Base" if i == 0 else "Level %d" % i, ("%.0f Metals / %.0f others" % [E.BASE_METAL_CAPACITY, base]) if i == 0 else "%.0f" % float(E.WAREHOUSE_CAPACITIES[i]), "—" if i == 0 else _recipe(E.WAREHOUSE_COSTS[i - 1])])
	_table(["Tier", "Capacity", "Cost"], rows)
	_note("Resource bars split station stock by system and show fleet cargo in blue. Local construction uses delivered stock only. Protect supply routes and avoid exporting essential food reserves.")

func _expansion() -> void:
	_body("Send a Colony to a reachable neutral system to automatically establish a station and shipyard on arrival. Transform (J) also works for a Colony already in neutral territory. All embarked settlers become the colony population, including at planetless systems; existing colonies cannot be freely claimed.")
	_flow(["Recruit settlers", "Travel", "Establish colony"])
	_body("Colonies farm %.1f/yr into a %.0f Organics hold. Auto-Farm delivers full loads when idle; Deliver Organics or right-click a friendly station to unload early. They cannot salvage." % [E.COLONY_FARM_RATE, E.COLONY_CAPACITY])
	_table(["Colony", "Requirement"], [["Crew", "%.0f Pop" % E.COLONY_POPULATION], ["Origin population", "%.0f Pop" % E.COLONY_MIN_ORIGIN_POPULATION], ["Construction", _recipe(E._cost("colony_ship", 1))], ["Base build time", "%.0f years" % (E._work("colony_ship", 1) / E.yard_speed(1))]])
	_section("Planetless sectors & conquest")
	_body("Cool blue stars mark planetless systems, useful for mining access. They rely on orbital housing rather than terrestrial production. Rounded claims grow with completed stations, shipyards and other system buildings. Neighboring claims of the same empire merge; rival claims meet at a boundary. Claims in explored fog reflect last observed infrastructure; ships do not create territory. Your infrastructure grants vision across its territory and beyond the edge. Claims never restrict movement. Individual asteroids do not obstruct ships. Pulsars retain their special exclusion zones.")
	_note("New colonies include one Small shipyard but no free resource production. Bring food and building materials.")

func _infrastructure() -> void:
	_body("Select a station and open Build. Infrastructure jobs advance in a prepaid sequential queue beside station resources. Canceling ships, infrastructure or upgrades immediately refunds all prepaid materials and GC. Stations and individual shipyards each hold up to four construction jobs, including the active job. Repeat construction waits for an open slot. Shipyards have independent hull queues. Shift-queued unit orders are limited to four including the active order.")
	_section("Resource production")
	var rows: Array = []
	for r in E.RESOURCES:
		var definition: Dictionary = E.ECONOMY_BUILDINGS[r]
		rows.append([definition["name"], _recipe(definition["cost"]), "%.0f%% baseline" % (E.BUILDING_BONUS * 100.0)])
	_table(["Building", "Cost", "Output bonus"], rows)
	_body("Production buildings require %d local residents × target level squared. Planetary mineral production has no fixed rate cap; deposits, population and storage still matter. Farms scale with food capacity and labor." % E.building_population("Metals", 1))
	_section("Shipyard modules")
	_body("Station bottom row: Shipyards (Z), Build (B), Trade (T). Shipyards selects all completed yards at selected stations. The Build submenu also has Shipyards (Z) at bottom left and Return at bottom right. Build → Shipyard (X) adds a yard at the next free port.")
	rows = []
	for i in range(1, E.MAX_SHIPYARDS + 1):
		rows.append(["Module %d" % i, _recipe(E._cost("yard", i))])
	_table(["Slot", "Materials"], rows)
	_body("Warehouse upgrades expand storage; habitation increases terrestrial housing capacity. Orbital Eco-Housing adds self-sufficient residents in planetless systems. Additional shipyards also supply eco-housing.")

func _ships() -> void:
	_body("Small yards build Harvesters, Fighters, Scouts and Construction Ships; Medium adds Freighters, Colonies and Cruisers; Large adds Science vessels, Destroyers and Railgun Ships. Any owned system with a suitable yard can build Freighters. AI fleets build Cruisers, Destroyers and Railgun Ships as their economy matures. Scouts have one blaster, twice fighter speed and half fighter HP. Start with one Freighter. Materials come from the local station; credits come from the empire treasury. Freighters have ten 10-unit bays. Harvesters travel slower; fighters are 20% faster than freighters. Ship details show crew, armed hull kills, cargo handling for cargo ships and Colony food production. Military hulls have no holds. Full crew, materials and GC are reserved before an order is accepted. Reserved crew remains productive and taxable at 0% construction, then embarks in full when work starts. An actual population loss or destroyed yard can delay work; cancelling releases reserved residents or returns embarked crew. Canceled hulls drop all prepaid materials at the yard; crew returns. Eligible orders may repeat.")
	var rows: Array = []
	for kind in E.SHIP_KINDS:
		rows.append([UI_TEXT.ship_kind_name(kind), E.size_name(E.ship_size(kind)), _recipe(E._cost(kind, 1), kind), "%.0f" % float(E.CREW_COSTS[kind]), "%.0f yr" % (E._work(kind, 1) / E.yard_speed(E.ship_size(kind)))])
	_table(["Ship", "Class", "Cost", "Crew", "Time (min. yard)"], rows)
	_section("Construction Ships and depots")
	_body("Select a Construction Ship, Build Resource Depot (F), then click a valid map position. Materials are reserved across owned stations as needed; constructors haul them physically. Lost supplies are replaced from available station stock. Cancel unfinished work (Y) then select the site; undelivered source stock is refunded and delivered materials become salvage. Completed depots have no crew or territory influence. Freighters and constructors use Load (L) and Drop Cargo (D) to collect and deposit at completed owned depots. Trade-enabled Freighters can supply constructors and move station surplus into depots or serve station import demand. Select an owned completed depot to enable receiving or dispatching each resource, set a receiving ceiling and reserve a dispatch floor. These policies apply only to automatic freight; explicit cargo commands are unchanged. Each resource has an independent fixed capacity: 200 Metals, 400 Organics, 50 Crystals. Antimatter cannot be stored.")
	_section("Wall construction")
	_body("Build Wall (Z) places one wall node on click or a connected chain when dragged. Maximum segment length: 450 world units. Connect to existing owned nodes. Nodes and segments require separate physical deliveries and can be destroyed separately; destroying a node removes attached segments. Walls have no crew or territorial influence. Ships automatically try to navigate around completed walls without Open Borders permission. Closed walls intercept non-allied weapons. Hostile walls take intercepted damage; neutral walls do not.")
	_section("Defense Cannons")
	_body("Construction Ships use Build Cannon (I) to place a static defense cannon and Upgrade Cannon (O) to select a completed cannon below level III. Physical resource delivery completes upgrades; the previous level remains operational during upgrades. Cannons fire automatically at hostile visible targets only, with no crew or territory influence.")
	var cannon_rows: Array = []
	for level in range(1, 4):
		cannon_rows.append([str(level), _recipe(E.static_recipe("defense_cannon", level), ""), "%.0f" % E.CANNON_HP[level - 1], "%.0f" % E.CANNON_DAMAGE[level - 1], "%.0f" % E.CANNON_RANGE[level - 1]])
	_table(["Level", "Materials", "HP", "Damage", "Range"], cannon_rows)
	_section("Annual upkeep")
	rows = []
	for kind in E.SHIP_KINDS:
		rows.append([UI_TEXT.ship_kind_name(kind), "%.1f GC/yr" % E.ship_upkeep(kind)])
	_table(["Ship", "Upkeep"], rows)
	_section("Shipyard upgrades")
	_body("Dark build cards cannot start construction; right-click automation still works where available. Upgrade cards show current levels at top left; tooltips show the target level. Upgrade (U for Medium, I for Large) in the corresponding row; locked ships remain hidden, then replace the upgrade with unlocked ships from column one. Higher shipyard levels increase construction speed and staffing requirements. Only station jobs show progress in the hub; yard production and upgrades appear in their own berths. Shipyard details show local station resources and population. Select Space Station returns to the parent station. Build (B) opens its construction submenu directly. Clear / Rally occupy the bottom-right slots. Rally flags mark destinations for completed ships to their destination; idle fighters can engage enemies and civilian ships resume their jobs.")
	rows = []
	for i in range(1, E.MAX_SHIPYARD_LEVEL + 1):
		rows.append([str(i), "%.0f×" % (E.yard_speed(i) / E.yard_speed(1)), "%.0f" % float(E.SHIPYARD_POPULATION[i - 1])])
	_table(["Level", "Build speed", "Staff required"], rows)

func _combat() -> void:
	_body("Move orders take priority over autonomous pursuit; ships fire in range while moving. Attack Move and Guard allow combat engagement. Guard (U) defends a chosen sector and returns to the marked position after combat. Hold permits firing in range. Damaged ships and structures display health bars. Autocast cooldown after orders or arrival: Wander/Trade %.0f s, Mine/Salvage %.0f s; Explore, Repair and Farm have no cooldown. Right-click a friendly ship to Guard it with fighters or Follow with other ships. Moving weapons fire in range; active commands have a cyan border. Command paths use dashed lines. Single ships show route legs; groups sharing an active command and target show one center line and a small destination circle. Select ships to see all Shift-queued orders as numbered chains, including fleet and formation orders. Selected drag formations retain destination hull ghosts until their orders finish. F1 selects all owned stations; F2 selects your army; F3 selects all owned shipyards. Empty selections disable these shortcuts. The resource bar hides when every balance and population is zero. Box selection can include foreign ships; only owned ships receive orders. Double-click selects your visible same-type ships. Tab / Shift+Tab cycles mixed-fleet or mixed-building command types. Shift-click owned buildings to group them separately from ships. Move and contextual right-click affect all owned selected ships; specialized commands affect the active type. Move and Patrol accept any exact point within the map, including unexplored space. Ships fly directly to manual destinations. Freighters have %.0f HP; ships and structures regenerate 0.1 HP every 3 years. New orders act immediately unless queued with Shift. Ships steer around nearby hulls; engine exhaust and weapon impacts light nearby surfaces. Shared destinations permit soft overlap. Stations start with %.0f HP, two defensive lasers and one missile launcher. Hold preserves position and facing; Auto-Retreat (K), off by default, withdraws armed ships at 46% HP into station repair range (%.0f HP/s)." % [E.AUTOCAST_COOLDOWN_YEARS, E.MINING_SALVAGE_COOLDOWN_YEARS, E.FREIGHTER_HP, E.STATION_HP, E.REPAIR_PER_YEAR])
	_table(["Weapon", "Damage / shot or volley", "Range"], [["Blaster", "%.1f" % E.BLASTER_DAMAGE, "%.0f" % E.LASER_RANGE], ["Capital laser", "%.0f" % E.LASER_DAMAGE, "%.0f" % E.LASER_RANGE], ["Mining lasers", "%.1f" % E.MINER_LASER_DAMAGE, "%.0f" % E.LASER_RANGE], ["Planetary defense", "%.0f" % E.PDS_DAMAGE, "%.0f" % E.PDS_RANGE]])
	_body("Blasters fire four shots in 1 s, then pause 0.5 s. Military Scout: 1; Fighter: 2 (no lasers). Scouts use military orders and pursuit. Cruisers: %.0f HP, three blasters, two lasers and one missile launcher. Destroyers: %.0f HP, four blasters, four lasers, two missile launchers and one railgun. Missiles deal %.0f damage each at range %.0f, every %.0f s. Splash: 30 world units, enemies only. Railgun Ships carry one railgun only and hold long-range standoff. Railgun: %.0f single-target damage, range %.0f, cooldown %.0f s." % [E.ship_max_hp("cruiser"), E.ship_max_hp("destroyer"), E.MISSILE_DAMAGE, E.MISSILE_RANGE, E.MISSILE_COOLDOWN, E.RAILGUN_DAMAGE, E.RAILGUN_RANGE, E.RAILGUN_COOLDOWN])
	_body("Cloaking Field is a late military reward. It becomes eligible after %d prior military upgrades; it is not an opening reward." % E.CLOAK_PRIOR_MILITARY_REWARDS)
	_section("Station defenses")
	_table(["Upgrade", "Effect", "Cost"], [["Plating", "%.0f → %.0f max HP" % [E.STATION_HP, E.REINFORCED_STATION_HP], _recipe(E._cost("reinforced_plating", 1))], ["Lasers", "+%d defensive lasers (4 total)" % E.STATION_LASER_COUNT, _recipe(E._cost("laser_matrix", 1))], ["PDS", "Invulnerable; lost with station", _recipe(E._cost("pds", 1))], ["Dyson Sphere (Tech)", "-50% local ship material and corresponding credit costs", _recipe(E._cost("dyson_sphere", 1))]])
	_note("Use coordinated attack groups, protect Harvesters and freighters, and retreat before losing ships and their crew investment.")

func _controls() -> void:
	_note("Default hotkeys. Menu → Hotkeys changes bindings; camera speed sliders adjust keyboard, mouse edge and wheel zoom.")
	_table(["Input", "Action"], [["Left click / drag", "Select objects first; otherwise select the bounded sector"], ["Shift + select", "Add to selection"], ["Right click / drag", "Contextual order / formation (12 px minimum stroke)"], ["Right click friendly ship", "Guard (fighters) / Follow (others)"], ["A / M / P, then click", "Attack / move / patrol"], ["S / H", "Stop movement, then resume automation / hold position"], ["L / D / R, then click", "Load / drop cargo / repair"], ["Y, then click / X", "Set / clear shipyard rally"], ["Shift + order", "Queue an order; consecutive Patrol orders form a repeating circuit"], ["Arrows / screen edge / middle drag", "Pan camera"], ["Mouse wheel", "Zoom; minimum fits the map with a small margin"], ["F", "Focus / follow fleet center weighted by ship count"], ["F1 / F2 / F3 / F4", "Stations / army / shipyards / Empire"], ["Double F2", "Center military selection"], ["Ctrl + 0–9", "Assign control group (icon and member count)"], ["Shift + 0–9", "Add selection to group"], ["0–9 / double tap", "Recall / center group (1 station, 2 yard initially)"], ["B / T (station)", "Build / trade"], ["Esc", "Cancel targeting, return or menu"]])
	_body("Explore, Wander, Auto-Mine, Auto-Salvage, Auto-Repair, Auto-Trade and Auto-Farm toggle with either mouse button. Explore and Wander sit next to each other; Wander is bottom-right. Modes occupy the bottom row (extra modes above for mixed fleets). Collect Antimatter uses left-click targeting and right-click autocast. Lit borders show enabled modes; clock masks show cooldown. Enabling Wander clears its cooldown only; active orders and Hold take priority.")
	_body("Stars are background landmarks. Click anywhere in a sector to select it (friendly sectors select their station). Move and formation orders use exact points. Use Colonize (C) or Transform to colonize. The Colony flies to the nearest side of the station orbit and morphs there for 30 seconds at normal speed; the completed station continues the same orbit. Once morphing begins, it cannot receive commands or cancel; its details show progress. Use the minimap to navigate or issue contextual orders. Hover commands for instant costs, requirements and effects in a panel above the card. Red text identifies unmet requirements; commands tinted red cannot be built in that system because it lacks planets or a suitable deposit. Production upgrades show the added local yield first, then a 100 Pop reference; farms use planetary residents. Right-click Build cards to repeat eligible production, Warehouse, Habitation, PDS and Shipyard construction across selected stations. Repeat can be enabled before requirements are met; construction waits until affordable and eligible. Orbital housing repeats until disabled. Shipyards selects all completed yards at selected stations. Trade edits apply the resource's displayed thresholds and switches to all selected owned stations.")

func _multiplayer() -> void:
	_body("Up to eight independent empires start neutral. Empire (F4) manages mutual alliances, vision, trade permission (settlement pending), peace and war. Repair is always shared while allied. Open Borders grants directional movement permission through walls; allied by default, neutral closed by default, wartime closed. Explicit neutral attacks require confirmation; movement never declares war. Mutual peace imposes a 100-year truce. The host validates commands; guests view synchronized state. AI weighs known fleets, defenses, distance, other wars and potential allies before proposing alliances, peace or war.")
	_body("The Codex and Menu are local interface windows; opening them does not pause a match.")
	_note("Balance values are provisional during development. Hover commands for current costs and requirements.")

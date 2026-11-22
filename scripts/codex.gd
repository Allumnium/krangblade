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
	["Fleet", "Ships & construction", "fighter miner colony logistics crew build queue costs shipyard"],
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
	_body("Expand through local economies and direct fleet command. The default logistics lens marks local resource strengths (+/++) and weaknesses (-/--). Population appears beside storage, to the left of the objectives at normal window widths. White chevrons show net gain (right) or loss (left), relative to capacity or treasury balance (GC has no cap). More chevrons mean faster change. Full stores with no net gain show no arrows. Hover for exact rates. Each completed objective earns 1 conquest point. At match start, the explored radius around home territory is three times its initial visible claim radius. This is remembered terrain, not permanent live vision. Own and consenting allied sensors reveal nearby space; previously explored areas darken when vision is lost. Discovered stars and fields remain selectable and show last-seen structures, population and resources; hidden fleets and live activity are not shown. Send Colony can target remembered neutral systems, subject to host validation. Scouts have 2,700 sight range. Toggle Explore (X; off by default) to scout distant systems away from friendly fleets and stations continuously, without cooldown. Wander (W) starts enabled and stays near the current idle location; enabling either turns the other off. Rounded player-colored territories mark discovered completed infrastructure; fleets do not affect territory. Fleet movement, colonization, mining and logistics travel directly to their destinations, avoiding asteroid fields except for Harvesters. Territory does not restrict manual flight; logistics overlays show owned shipments only. Box selection prioritizes combat ships; civilian-only boxes still work. Spend a completed goal's CP before receiving another; new goals must have unmet targets. One Economic and Military goal each; Tech unlocks after three economic goals or first antimatter collection. Build two colony ships, then colonize two systems. Other starter goals: produce 1kt colony food, hold 3kt Metals (stock and cargo), reach 80k total population, build 5 military ships or destroy 3 enemy ships. The square refresh button draws another eligible goal in its category every 60 s; Upgrade pulses when available and spends that category's CP. Your objective and unique unlock notices fade above the minimap; personal objectives play a reward chime, with a longer first-place fanfare. The scoreboard beneath objectives lists each player's lifetime earned Economic, Military and Tech CP; +/− collapses or expands it. Enter opens scrollable chat and notification history above the minimap. Enter sends, Esc closes. Recent messages fade upward from the minimap. Music and SFX volume/mute are in Settings; the menu has an original ambient score; nearby combat is louder, distant battles quieter. Spend category CP on three upgrade choices. Rankable research stacks small bonuses forever; major technologies remain one-time. Lifetime objectives continue through rising tiers. Each purchase redraws if CP remain. Purple UNIQUE cards (Cloaking, Shields 3, Warp Gates, Crystalline Synthesis) are reserved permanently by the first player to select them. Competing offers refresh without spending CP. Military Shields 1–3 absorb damage before hulls; recharge 5% per second after 5 s without damage. World health and shield bars appear independently only when damaged; active shields glow along hull outlines. Off-camera friendly damage and approaching enemy combat fleets generate clickable warnings; click to center the camera. Armor reduces military hull damage by 15%. Additional construction costs appear in the command information panel. Cloaking replaces Scout shields/armor: translucent while cloaked, hidden beyond enemy detection (250 range), revealed 5 s after firing. Tech Warp Gates consume one antimatter vessel at an owned system. Select a gate and press J to cycle links; right-click a linked owned gate with ships to travel. 10 s per-ship cooldown. F4 maintains empire fleet targets (any integer from 0–500 per ship type) at owned shipyards; existing ships and queued hulls count. Group station construction orders apply to every eligible selected station.")
	_section("The strategic loop")
	_flow(["Extract resources", "Build & recruit", "Expand", "Defend supply"])
	_body("Start with 3 Harvesters, 2 fighters and 1 freighter. Select a unit or station to issue orders.")
	_section("First priorities")
	_table(["Goal", "Action"], [["Establish supplies", "Protect nearby asteroid fields and keep food reserves healthy."], ["Build a fleet", "Select a shipyard and queue Harvesters, fighters or freighters."], ["Expand", "Send a Colony to an eligible neutral system. Secure your trade lanes."], ["Survive", "Defend stations and ships. Defeat other empires by destroying their remaining stations and hulls."]])
	_note("Start with Population & food and Trade & storage.")

func _resources() -> void:
	_body("The empire uses three ordinary resources. Material prices are paid from local stock, not a shared global wallet.")
	_resource_card("Metals", "Primary construction material. Extracted from planets and asteroid fields; used in ships, buildings and upgrades.")
	_resource_card("Organics", "Food for residents and supplies for basic ships. Farming and imports improve local population growth.")
	_resource_card("Crystals", "Advanced construction material. Each station produces %.2f t/yr, even without planets. Incubators improve local crystal production. Mine crystal-rich rocks for advanced hulls, defenses, extra yards and military upgrades." % E.STATION_CRYSTALS_PER_YEAR)
	_section("Starting stock per home system")
	var rows: Array = []
	for r in E.RESOURCES:
		rows.append([r, "%.0f t" % float(E.STARTING_STOCK[r])])
	_table(["Resource", "Stock"], rows)
	_resource_card("GC", "Empire-wide currency. Start with %.0f GC; annual taxes equal %.1f%% of resident population. Ship crews are excluded. The gold icon marks credit costs and the HUD balance; the rate below is net taxes minus fleet upkeep." % [E.STARTING_GC, E.RESIDENT_TAX_RATE * 100.0], "Galactic Credits (GC)")
	_body("Construction reserves GC and local materials immediately. Base fee: %.0f%% of material value (rounded up); small/medium/large ships pay 2×/3×/4×. Cancel for a full GC refund; destroyed projects lose their fee. Colony transformation is prepaid; Warp Gates cost %.0f GC plus antimatter." % [E.CONSTRUCTION_CREDIT_FRACTION * 100.0, E.WARP_GATE_CREDIT_COST])
	_body("Completed ships require continuous GC upkeep. Taxes pay first, civilian ships before military ships. Unpaid wages trigger warnings; payment restores good standing. Stations and gates are upkeep-free.")
	_body("After %.0f unpaid years, each ship has a %.1f%% chance per %.0f years of going rogue. It becomes neutral and leaves your control with its cargo and crew. No war is declared." % [E.ROGUE_GRACE_YEARS, E.ROGUE_CHANCE * 100.0, E.ROGUE_CHECK_YEARS])
	_section("Raw antimatter")
	_body("Science vessels follow sector lanes to a Pulsar, then collect one unit after 30 years in range. Collect Antimatter (C), then choose a Pulsar; right-click the ability to enable autocast (off by default). Antimatter remains aboard.")

func _population() -> void:
	_body("Residents power production, staff shipyards and crew ships. Food and housing limit terrestrial growth.")
	_section("Food reserves and growth")
	_body("Growth scales with stored Organics up to %.0f t, independent of warehouse size. Food shortages and overcrowding slow growth further." % E.POPULATION_FOOD_RESERVE)
	var rows: Array = []
	for fraction in [1.0, 0.75, 0.5, 0.25, 0.0]:
		rows.append(["%.0f t" % (fraction * E.POPULATION_FOOD_RESERVE), "%.0f%%" % (fraction * 100.0), "%.0f years" % (E.POPULATION_DOUBLING_YEARS / fraction) if fraction > 0.0 else "No growth"])
	_table(["Organics reserve", "Growth ceiling", "Doubling time"], rows)
	_chart(false)
	_body("Ship crews count toward empire population, not local labor or food demand. The resident portion of the population bar fills toward sustainable capacity: the lower of farm support and habitation, plus orbital housing. Base habitation is 500,000, scaled by system size; upgrades double it. Crowding reduces growth by occupancy cubed.")
	_section("Illustrative population growth")
	_chart(true)
	_label(article, "Ideal growth from %.0f residents. Capacity limits and recruitment reduce actual growth." % E.HOME_POPULATION, 12, HUD.MUTED)
	_section("Orbital Eco-Housing")
	_body("Each completed shipyard and orbital housing module supports %.0f residents and produces %.1f t/yr Organics. These residents recover at a %.0f-year doubling rate and are exempt from terrestrial food and overcrowding penalties." % [E.ORBITAL_HOUSING_POPULATION, E.ECO_HOUSING_ORGANICS, E.POPULATION_DOUBLING_YEARS])
	_note("Keep Organics near the reserve target before spending food on ships. Colonies require %.0f settlers and %.0f residents at the originating station." % [E.COLONY_POPULATION, E.COLONY_MIN_ORIGIN_POPULATION])

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
	_body("Harvesters extract ore and transfer it to nearby freighters, even while traveling (10 Harvester holds per freighter), or return to an owned depot. A passing freighter interrupts deliveries; empty Harvesters immediately reassess work. Cargo enters storage gradually within doubled docking and handoff range; ships seek separated berths near the edge of transfer range. Select a Harvester and right-click a field or rock to assign it. Select a field to toggle Mining, Metals and Crystals on its command card.")
	_flow(["Asteroid field", "Miner cargo", "Station stock"])
	_table(["Mining statistic", "Value"], [["Cargo hold", "%.0f t" % E.MINER_CAPACITY], ["Nominal extraction", "%.0f t/yr" % E.MINER_RATE], ["Field resource ceiling", "%.0f t/yr" % E.FIELD_MINING_LIMIT]])
	_section("Salvage & repair")
	_body("Destroyed ships can leave drifting salvage. Harvesters and freighters may collect it in safe space; Idle Harvesters and Freighters search safe debris up to %d sector links and %.0f straight-line units away. Harvesters prioritize scraps over ore. Wreck debris lasts %.0f–%.0f simulation years; cancelled construction salvage persists. Freighters salvage at one-quarter the Harvester rate. Harvesters repair friendly hulls, stations, yards and individual planetary defenses at %.0f HP/s. Idle ships stop wandering while repaired." % [E.AUTO_SALVAGE_HOPS, E.AUTO_SALVAGE_RANGE, E.SALVAGE_MIN_LIFETIME, E.SALVAGE_MAX_LIFETIME, E.MINER_REPAIR_RATE])
	_note("Fighters have no cargo hold. Use civilian ships to recover resources after battles.")

func _trade() -> void:
	_body("Tiny resource-colored cargo pods show planetary production flowing to the station. Planetary upgrades activate after a larger delivery pod arrives (3 s). Planet surface colors indicate resources (green Organics, gray Metals, purple Crystals). Select a planet for output in t/yr. Right-click a known neutral star with a selected Colony to settle it automatically; Shift queues settlement after existing orders. Unclaimed sectors offer Send Colony, dispatching the nearest unassigned eligible Colony, regardless of current movement, retreat or local work; only an active colonization assignment reserves a ship. The card shows Colony En Route while assigned. Hostile ships in the sector blockade planetary output; orbital housing production continues. Every station has separate resource stockpiles and import/export settings. Dedicated colored storage circles show fill; particles trace actual cargo transfers. Freighters move surplus between friendly systems. With Auto-Trade enabled, idle ships wait within handoff range on the depot-facing side of Harvesters, or at salvage sites containing at least a full hold; they wait until full, the site is depleted, or no cargo arrives for 8 s, then deliver to owned stations and wait if storage is full. Trade surplus without an importer returns to owned storage. Dropoff: Harvesters %.0f, freighters %.0f, Colonies %.0f t/yr." % [E.dropoff_rate("miner"), E.dropoff_rate("ship"), E.dropoff_rate("colony_ship")])
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
	_note("Resource bars split station stock by system and show fleet cargo in blue. Local construction uses delivered stock only. Protect supply routes and avoid exporting essential food reserves.")

func _expansion() -> void:
	_body("Send a Colony to a reachable neutral system to automatically establish a station and shipyard on arrival. Transform (J) also works for a Colony already in neutral territory. All embarked settlers become the colony population, including at planetless systems; existing colonies cannot be freely claimed.")
	_flow(["Recruit settlers", "Travel", "Establish colony"])
	_body("Colonies farm %.0f t/yr into a %.0f t Organics hold. Auto-Farm delivers full loads when idle; Deliver Organics or right-click a friendly station to unload early. They cannot salvage." % [E.COLONY_FARM_RATE, E.COLONY_CAPACITY])
	_table(["Colony", "Requirement"], [["Crew", "%.0f people" % E.COLONY_POPULATION], ["Origin population", "%.0f residents" % E.COLONY_MIN_ORIGIN_POPULATION], ["Construction", _recipe(E._cost("colony_ship", 1))], ["Base build time", "%.0f years" % (E._work("colony_ship", 1) / E.yard_speed(1))]])
	_section("Planetless sectors & conquest")
	_body("Cool blue stars mark planetless systems, useful for mining access. They rely on orbital housing rather than terrestrial production. Rounded claims grow with completed stations, shipyards and other system buildings. Neighboring claims of the same empire merge; rival claims meet at a boundary. Claims in explored fog reflect last observed infrastructure; ships do not create territory. Your infrastructure grants vision across its territory and beyond the edge. Claims never restrict movement. Asteroid fields block non-Harvester ships; Harvesters can enter to mine.")
	_note("A colony is a long-term economic investment. Food imports and local farming improve its growth, while fleets defend its shipping lanes.")

func _infrastructure() -> void:
	_body("Select a station and open Build. Infrastructure jobs advance in a prepaid sequential queue beside station resources. Canceling infrastructure or upgrades refunds all prepaid materials directly. Only canceled ship construction drops materials as persistent salvage. Shipyards have independent hull queues.")
	_section("Resource production")
	var rows: Array = []
	for r in E.RESOURCES:
		var definition: Dictionary = E.ECONOMY_BUILDINGS[r]
		rows.append([definition["name"], _recipe(definition["cost"]), "%.0f%% baseline" % (E.BUILDING_BONUS * 100.0)])
	_table(["Building", "Cost", "Output bonus"], rows)
	_body("Production buildings require %d local residents × target level squared. Planetary mineral production has no fixed rate cap; deposits, population and storage still matter. Farms scale with food capacity and labor." % E.building_population("Metals", 1))
	_section("Shipyard modules")
	_body("Station bottom row: Shipyards (Z), Build (B), Trade (T). Shipyards selects all completed local yards. Build → Shipyard (X) adds a yard at the next free port.")
	rows = []
	for i in range(1, E.MAX_SHIPYARDS + 1):
		rows.append(["Module %d" % i, _recipe(E._cost("yard", i))])
	_table(["Slot", "Materials"], rows)
	_body("Warehouse upgrades expand storage; habitation increases terrestrial housing capacity. Orbital Eco-Housing adds self-sufficient residents in planetless systems. Additional shipyards also supply eco-housing.")

func _ships() -> void:
	_body("Small yards build Harvesters, Fighters and Scouts; Medium adds Freighters, Colonies and Cruisers; Large adds Science vessels and Destroyers. Any owned system with a suitable yard can build Freighters. AI fleets build and deploy Cruisers and Destroyers as their economy matures. Scouts have one blaster, twice fighter speed and half fighter HP. Start with one Freighter. Materials come from the local station; credits come from the empire treasury. Freighters have ten 10 t bays. Harvesters travel slower; fighters are 20% faster than freighters. Ship details show crew, armed hull kills, cargo handling for cargo ships and Colony food production. Fighters, Cruisers, Destroyers and Scouts have no holds. Full crew, materials and GC are reserved before an order is accepted. Reserved crew remains productive and taxable at 0% construction, then embarks in full when work starts. An actual population loss or destroyed yard can delay work; cancelling releases reserved residents or returns embarked crew. Canceled hulls drop all prepaid materials at the yard; crew returns. Eligible orders may repeat.")
	var rows: Array = []
	for kind in E.SHIP_KINDS:
		rows.append([UI_TEXT.ship_kind_name(kind), E.size_name(E.ship_size(kind)), _recipe(E._cost(kind, 1), kind), "%.0f" % float(E.CREW_COSTS[kind]), "%.0f yr" % (E._work(kind, 1) / E.yard_speed(E.ship_size(kind)))])
	_table(["Ship", "Class", "Cost", "Crew", "Time (min. yard)"], rows)
	_section("Annual upkeep")
	rows = []
	for kind in E.SHIP_KINDS:
		rows.append([UI_TEXT.ship_kind_name(kind), "%.0f GC/yr" % E.ship_upkeep(kind)])
	_table(["Ship", "Upkeep"], rows)
	_section("Shipyard upgrades")
	_body("Dark build cards cannot start construction; right-click automation still works where available. Upgrade cards show current levels at top left; tooltips show the target level. Upgrade (U for Medium, I for Large) in the corresponding row; locked ships remain hidden, then replace the upgrade with unlocked ships from column one. Higher shipyard levels increase construction speed and staffing requirements. Only station jobs show progress in the hub; yard production and upgrades appear in their own berths. Select Space Station returns to the parent station. Clear / Rally occupy the bottom-right slots. Rally flags mark destinations for completed ships to their destination; idle fighters can engage enemies and civilian ships resume their jobs.")
	rows = []
	for i in range(1, E.MAX_SHIPYARD_LEVEL + 1):
		rows.append([str(i), "%.0f×" % (E.yard_speed(i) / E.yard_speed(1)), "%.0f" % float(E.SHIPYARD_POPULATION[i - 1])])
	_table(["Level", "Build speed", "Staff required"], rows)

func _combat() -> void:
	_body("Fighters seek hostile ships within their sector unless holding; they resume movement orders afterward. Guard (U) defends a chosen sector and returns to the marked position after combat. Hold permits firing in range. Damaged ships and structures display health bars. Autocast cooldown after orders or arrival: Wander/Trade %.0f s, Mine/Salvage %.0f s; Explore, Repair and Farm have no cooldown. Right-click a friendly ship to Guard it with fighters or Follow with other ships. Moving weapons fire in range; active commands have a cyan border. Command paths use dashed lines. Single ships show route legs; groups sharing an active command and target show one center line. Select ships to see all Shift-queued orders as numbered chains, including fleet and formation orders. Selected drag formations retain destination hull ghosts until their orders finish. F1 selects all owned stations; F2 selects your army; F3 selects all owned shipyards. Box selection includes only your ships. Double-click selects your visible same-type ships. Tab / Shift+Tab cycles mixed-fleet or mixed-building command types. Shift-click owned buildings to group them separately from ships. Move and contextual right-click affect all owned selected ships; specialized commands affect the active type. Move and Patrol accept any exact point within the map, including unexplored space. Ships fly directly to manual destinations. Freighters have %.0f HP; ships and structures regenerate 1 HP every 3 years. New orders act immediately unless queued with Shift. Ships steer around nearby hulls; thrust flares during acceleration, not steady cruising. Shared destinations permit soft overlap. Stations start with %.0f HP, two defensive lasers and one missile launcher. Hold preserves position and facing; Auto-Retreat (K), off by default, withdraws armed ships at 46% HP into station repair range (%.0f HP/s)." % [E.AUTOCAST_COOLDOWN_YEARS, E.MINING_SALVAGE_COOLDOWN_YEARS, E.FREIGHTER_HP, E.STATION_HP, E.REPAIR_PER_YEAR])
	_table(["Weapon", "Damage / shot or volley", "Range"], [["Blaster", "%.0f" % E.BLASTER_DAMAGE, "%.0f" % E.LASER_RANGE], ["Capital laser", "%.0f" % E.LASER_DAMAGE, "%.0f" % E.LASER_RANGE], ["Mining lasers", "%.0f" % E.MINER_LASER_DAMAGE, "%.0f" % E.LASER_RANGE], ["Planetary defense", "%.0f" % E.PDS_DAMAGE, "%.0f" % E.PDS_RANGE]])
	_body("Blasters fire four shots in 1 s, then pause 0.5 s. Military Scout: 1; Fighter: 2 (no lasers). Scouts use military orders and pursuit. Cruisers: %.0f HP, three blasters, two lasers and one missile launcher. Destroyers: %.0f HP, four blasters, four lasers and two launchers. Missiles deal %.0f damage each at range %.0f, every %.0f s. Splash: 30 world units, enemies only." % [E.ship_max_hp("cruiser"), E.ship_max_hp("destroyer"), E.MISSILE_DAMAGE, E.MISSILE_RANGE, E.MISSILE_COOLDOWN])
	_section("Station defenses")
	_table(["Upgrade", "Effect", "Cost"], [["Plating", "%.0f → %.0f max HP" % [E.STATION_HP, E.REINFORCED_STATION_HP], _recipe(E._cost("reinforced_plating", 1))], ["Lasers", "+%d defensive lasers (4 total)" % E.STATION_LASER_COUNT, _recipe(E._cost("laser_matrix", 1))], ["PDS", "Invulnerable; lost with station", _recipe(E._cost("pds", 1))], ["Dyson Sphere (Tech)", "-50% local ship material and corresponding credit costs", _recipe(E._cost("dyson_sphere", 1))]])
	_note("Use coordinated attack groups, protect Harvesters and freighters, and retreat before losing ships and their crew investment.")

func _controls() -> void:
	_note("Default hotkeys. Menu → Hotkeys changes bindings; camera speed sliders adjust keyboard, mouse edge and wheel zoom.")
	_table(["Input", "Action"], [["Left click / drag", "Select objects first; otherwise select the bounded sector"], ["Shift + select", "Add to selection"], ["Right click / drag", "Contextual order / formation"], ["Right click friendly ship", "Guard (fighters) / Follow (others)"], ["A / M / P, then click", "Attack / move / patrol"], ["S / H", "Stop movement, then resume automation / hold position"], ["L / D / R, then click", "Load / drop cargo / repair"], ["Y, then click / X", "Set / clear shipyard rally"], ["Shift + order", "Queue an order; consecutive Patrol orders form a repeating circuit"], ["Arrows / screen edge / middle drag", "Pan camera"], ["Mouse wheel", "Zoom; ships enlarge up to 12×, structures up to 4×"], ["F", "Focus / follow fleet center weighted by ship count"], ["F1 / F2 / F3 / F4", "Stations / army / shipyards / Empire"], ["Double F2", "Center military selection"], ["Ctrl + 0–9", "Assign control group (icon and member count)"], ["Shift + 0–9", "Add selection to group"], ["0–9 / double tap", "Recall / center group (1 station, 2 yard initially)"], ["B / T (station)", "Build / trade"], ["Esc", "Cancel targeting, return or menu"]])
	_body("Explore, Wander, Auto-Mine, Auto-Salvage, Auto-Repair, Auto-Trade and Auto-Farm toggle with either mouse button. Explore and Wander sit next to each other; Wander is bottom-right. Modes occupy the bottom row (extra modes above for mixed fleets). Collect Antimatter uses left-click targeting and right-click autocast. Lit borders show enabled modes; clock masks show cooldown. Enabling Wander clears its cooldown only; active orders and Hold take priority.")
	_body("Stars are background landmarks. Click anywhere in a sector to select it (friendly sectors select their station). Move and formation orders use exact points. Use Send Colony or Transform to colonize. Use the minimap to navigate or issue contextual orders. Hover commands for instant costs, requirements and effects in a panel above the card. Production upgrades show the added local yield first, then a 10k-resident reference; farms use planetary residents. Right-click eligible production cards to repeat.")

func _multiplayer() -> void:
	_body("Up to eight independent empires start neutral. Empire (F4) manages mutual alliances, vision, trade permission (settlement pending), peace and war. Repair is always shared while allied. Explicit neutral attacks require confirmation; movement never declares war. Mutual peace imposes a 100-year truce. The host validates commands; guests view synchronized state. AI weighs known fleets, defenses, distance, other wars and potential allies before proposing alliances, peace or war.")
	_body("The Codex and Menu are local interface windows; opening them does not pause a match.")
	_note("Balance values are provisional during development. Hover commands for current costs and requirements.")

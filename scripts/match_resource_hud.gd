extends RefCounted
## Local resource header, storage strips and shared local/global hover presentation.
## Reads simulation queries; never writes authoritative state.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const UI_TEXT = preload("res://scripts/ui_text.gd")

var make_label: Callable
var make_population_row: Callable
var state_query: Callable
var local_player: Callable
var system_name: Callable
var global_resource_fills: Dictionary = {}
var global_resource_segments: Dictionary = {}
var global_resource_strips: Dictionary = {}
var global_resource_labels: Dictionary = {}
var global_resource_trends: Dictionary = {}
var global_resource_tiles: Dictionary = {}
var resource_hover_panel: PanelContainer
var resource_hover_label: Label
var hovered_resource: String = ""
var global_population_label: Label
var global_credit_label: Label
var year_label: Label

func build(row: Container, label_factory: Callable, population_factory: Callable, snapshot_query: Callable, player_query: Callable, name_query: Callable) -> void:
	make_label = label_factory
	make_population_row = population_factory
	state_query = snapshot_query
	local_player = player_query
	system_name = name_query
	year_label = _global_stat(row, "%d A.D." % ECONOMY.START_YEAR, HUD.ACCENT)
	_build_credit_stat(row)
	_build_global_bar(row)
	global_population_label = _global_stat(row, "0", Color("#b9d9ed"), true)

func is_built() -> bool:
	return is_instance_valid(year_label)

func hide_hover() -> void:
	resource_hover_panel.hide()

func _draw_resource_fill(strip: Control, resource: String) -> void:
	var fraction: float = float(global_resource_fills.get(resource, 0.0))
	var segments: Array = global_resource_segments.get(resource, [])
	strip.draw_rect(Rect2(Vector2.ZERO, strip.size), Color("#081421"))
	var width: float = strip.size.x * fraction
	strip.draw_rect(Rect2(Vector2.ZERO, Vector2(width, strip.size.y)), Color(HUD.COLORS.get(resource, Color("#b9d9ed")), 0.38))
	var x: float = 0.0
	for i in range(segments.size()):
		var segment: Dictionary = segments[i]
		var w: float = width * float(segment["share"])
		if segment.has("color"):
			strip.draw_rect(Rect2(Vector2(x, 0), Vector2(w, strip.size.y)), segment["color"])
		if i > 0:
			strip.draw_line(Vector2(x, 0), Vector2(x, strip.size.y), Color("#081421"), 1.0)
		x += w
	_draw_trend(strip, resource)

func _draw_trend(strip: Control, resource: String) -> void:
	var trend: int = int(global_resource_trends.get(resource, 0))
	if trend != 0:
		var direction: float = 1.0 if trend > 0 else -1.0
		var count: int = absi(trend)
		var span: float = count * 6.0
		var left: float = (strip.size.x - span) * 0.5
		var y: float = strip.size.y * 0.5
		for i in range(count):
			var center: float = left + 3.0 + i * 6.0
			var tail: float = center - direction * 2.0
			var tip: float = center + direction * 2.0
			strip.draw_line(Vector2(tail, y - 4.0), Vector2(tip, y), Color.WHITE, 1.5, true)
			strip.draw_line(Vector2(tip, y), Vector2(tail, y + 4.0), Color.WHITE, 1.5, true)


func _build_global_bar(stats: Container) -> void:
	for resource in ECONOMY.RESOURCES:
		var tile := PanelContainer.new()
		tile.custom_minimum_size.x = 104.0
		tile.add_theme_stylebox_override("panel", HUD.surface(Color("#12233780"), Color("#28466100"), 4, 3))
		stats.add_child(tile)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 2)
		tile.add_child(stack)
		var line := HBoxContainer.new()
		stack.add_child(line)
		var icon := TextureRect.new()
		HUD.fixed_icon(icon, HUD.resource_icon(resource, 18), 18)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(icon)
		var value: Label = make_label.call("0", 15)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.clip_text = true
		value.add_theme_font_size_override("font_size", 15)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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

func _build_credit_stat(parent: Container) -> void:
	var tile := PanelContainer.new()
	tile.custom_minimum_size.x = 80.0
	tile.add_theme_stylebox_override("panel", HUD.surface(Color("#12233780"), Color("#28466100"), 2, 3))
	parent.add_child(tile)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	tile.add_child(stack)
	var balance_row := HBoxContainer.new()
	balance_row.add_theme_constant_override("separation", 2)
	balance_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(balance_row)
	var credit_icon := TextureRect.new()
	HUD.fixed_icon(credit_icon, HUD.resource_icon("GC", 18), 18)
	credit_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance_row.add_child(credit_icon)
	global_credit_label = make_label.call("0", 15)
	global_credit_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	global_credit_label.add_theme_color_override("font_color", HUD.CREDIT_COLOR)
	balance_row.add_child(global_credit_label)
	var strip := Control.new()
	strip.custom_minimum_size.y = 14.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(strip)
	global_resource_strips["credits"] = strip
	strip.draw.connect(_draw_trend.bind(strip, "credits"))
	global_resource_tiles["credits"] = tile

func _global_stat(parent: Container, value: String, tint: Color, population: bool = false) -> Label:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", HUD.surface(Color("#12233780"), Color("#28466100"), 4, 3))
	parent.add_child(tile)
	var label: Label = make_label.call(value, 12)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	if population:
		tile.custom_minimum_size.x = 104.0
		label.add_theme_font_size_override("font_size", 15)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 2)
		tile.add_child(stack)
		make_population_row.call(stack).add_child(label)
		var strip := Control.new()
		strip.custom_minimum_size = Vector2(0, 14)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(strip)
		global_resource_tiles["population"] = tile
		global_resource_strips["population"] = strip
		strip.draw.connect(_draw_resource_fill.bind(strip, "population"))
	else:
		tile.add_theme_stylebox_override("panel", HUD.surface(Color.TRANSPARENT, Color.TRANSPARENT, 4, 3))
		tile.add_child(label)
	return label

static func resource_delta(p: Dictionary, resource: String) -> float:
	return ECONOMY.rate(p, resource) - ECONOMY.consumption(p, resource)

func _empire_resource_delta(state: Dictionary, resource: String) -> float:
	var total: float = 0.0
	for p in state.get("planets", []):
		if int(p["owner"]) == local_player.call():
			total += ECONOMY.net_rate(p, resource)
	return total

# Signed number of chevrons relative to capacity or a treasury reference.
static func _trend_count(annual: float, capacity: float) -> int:
	if absf(annual) < 0.005 or capacity <= 0.0:
		return 0
	var ratio: float = absf(annual) / capacity
	var count: int = 3 if ratio >= 0.02 else (2 if ratio >= 0.005 else 1)
	return count if annual > 0.0 else -count

static func set_resource_delta(label: Label, annual: float, parentheses: bool = false) -> void:
	var displayed: float = 0.0 if absf(annual) < 0.005 else annual
	var amount: String = ("+" if displayed > 0.0 else "") + UI_TEXT.resource_amount(displayed, 2, true)
	label.text = ("(%s/yr)" % amount if displayed != 0.0 else "") if parentheses else amount
	label.visible = not parentheses or displayed != 0.0
	label.add_theme_color_override("font_color", Color("#7cdb9b") if displayed > 0.0 else (Color("#eb8585") if displayed < 0.0 else Color.WHITE))

func build_hover(owner: Control) -> void:
	resource_hover_panel = PanelContainer.new()
	resource_hover_panel.z_index = 50
	resource_hover_panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928"), Color("#42647e"), 9))
	owner.add_child(resource_hover_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	resource_hover_panel.add_child(scroll)
	resource_hover_label = make_label.call("", 12)
	resource_hover_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(resource_hover_label)
	resource_hover_panel.hide()

func _resource_breakdown(state: Dictionary, resource: String) -> String:
	if resource == "credits":
		var balance: float = ECONOMY.credit_balance(state, local_player.call())
		var totals: Dictionary = ECONOMY.empire_totals(state, local_player.call())
		var income: float = ECONOMY.resident_tax_income(state, int(local_player.call()))
		var upkeep: float = float(totals["upkeep"])
		var unpaid: int = int(totals["unpaid_ships"])
		var details: String = "Galactic Credits · %.2f GC\nResident taxes (%.1f%%/yr): +%.2f GC/yr\nFleet upkeep: −%.2f GC/yr\nNet recurring income: %+.2f GC/yr" % [balance, ECONOMY.RESIDENT_TAX_RATE * 100.0, income, upkeep, income - upkeep]
		if unpaid > 0:
			details += "\nWARNING: %d ships have unpaid wages." % unpaid
		return details
	if resource == "population":
		var population_totals: Dictionary = ECONOMY.empire_totals(state, local_player.call())
		var lines: PackedStringArray = ["Population · %s people" % UI_TEXT.compact_amount(float(population_totals["population"])), "Residents: %s · Ships: %s · Embarking: %s" % [UI_TEXT.compact_amount(float(population_totals["resident_population"])), UI_TEXT.compact_amount(float(population_totals["ship_population"])), UI_TEXT.compact_amount(float(population_totals["embarking_population"]))], "System · Population · Growth/yr"]
		var ceiling: float = 0.0
		var demographic: float = 0.0
		for system in state["planets"]:
			if int(system["owner"]) == local_player.call():
				ceiling += ECONOMY.sustainable_population_capacity(system)
				demographic += float(system.get("demographic_rate", ECONOMY.population_growth(system)))
		lines.insert(1, "Resident sustainable capacity: %s people" % UI_TEXT.compact_amount(ceiling))
		lines.insert(2, "Population growth: %+.2f/yr" % demographic)
		for i in range(state["planets"].size()):
			var p: Dictionary = state["planets"][i]
			if int(p["owner"]) != local_player.call():
				continue
			var growth: float = float(p.get("demographic_rate", ECONOMY.population_growth(p)))
			var crew: float = float(p.get("crew_rate", 0.0))
			lines.append("%s · %.0f · %+.2f/yr\n  %+.2f growth · %+.2f crew · %+.1f%% crowding · %+.1f%% food" % [system_name.call(i), float(p["population"]), growth - crew, growth, -crew, -100.0 * ECONOMY.overpopulation_penalty(p), -100.0 * (1.0 - ECONOMY.food_growth_multiplier(p))])
		return "\n".join(lines)
	var totals: Dictionary = ECONOMY.empire_totals(state, local_player.call())
	var lines: PackedStringArray = ["%s · %.2f total" % [resource, float(totals["resources"][resource])],
		"Stations: %.2f / %.0f · Ships: %.2f" % [float(totals["stock"][resource]), float(totals["storage_reference"][resource]), float(totals["cargo"][resource])],
		"Net (storage-limited): %+.2f/yr" % _empire_resource_delta(state, resource)]
	var food: bool = resource == "Organics"
	lines.append("System · Net | Production | Food demand (/yr)" if food else "System · Net | Production (/yr)")
	for i in range((state.get("planets", []) as Array).size()):
		var p: Dictionary = state["planets"][i]
		if int(p["owner"]) != local_player.call():
			continue
		var row: String = "%s  %+.2f | %.2f" % [system_name.call(i), ECONOMY.net_rate(p, resource), ECONOMY.rate(p, resource)]
		if food:
			row += " | %.2f" % ECONOMY.consumption(p, resource)
		lines.append(row)
	return "\n".join(lines)

func _local_breakdown(p: Dictionary, resource: String, selected: int) -> String:
	if resource == "population":
		var growth: float = float(p.get("demographic_rate", ECONOMY.population_growth(p)))
		var crew: float = float(p.get("crew_rate", 0.0))
		return "%s · %.0f Pop\n%+.2f/yr net\n%+.2f demographic change\n%+.2f ship crews\nOverpopulation penalty: %+.1f%%\nFood reserve growth penalty: %+.1f%% (%.2f / %.0f for full growth)\nOrganics: %.2f produced / %.2f consumed per year\nEco-Housing: %.0f / %.0f Pop · +%.2f/yr Organics" % [system_name.call(selected), float(p["population"]), growth - crew, growth, -crew, -100.0 * ECONOMY.overpopulation_penalty(p), -100.0 * (1.0 - ECONOMY.food_growth_multiplier(p)), float(p["stock"]["Organics"]), ECONOMY.POPULATION_FOOD_RESERVE, ECONOMY.rate(p, "Organics"), ECONOMY.consumption(p, "Organics"), ECONOMY.eco_population(p), ECONOMY.eco_capacity(p), ECONOMY.eco_organics(p)]
	var potential: float = ECONOMY.rate(p, resource)
	if resource != "Organics":
		return "%s · %.2f stored\nProduction: %.2f/yr\nNet: %+.2f/yr\nOutput: %.1f%%" % [resource, float(p["stock"][resource]), potential, ECONOMY.net_rate(p, resource), 100.0 * ECONOMY.production_modifier(p, resource)]
	var demand: float = ECONOMY.consumption(p, resource)
	return "%s · %.2f stored\nProduction: %.2f/yr\nDemand: %.2f/yr\nNet: %+.2f/yr\nOutput: %.1f%%" % [resource, float(p["stock"][resource]), potential, demand, potential - demand, 100.0 * ECONOMY.production_modifier(p, resource)]

func update_hover(owner: Control, codex: Window, station_details: VBoxContainer, overview_panel: PanelContainer, population_label: Label, production_values: Dictionary, selected: int, planet_query: Callable) -> void:
	if not is_instance_valid(resource_hover_panel):
		return
	if is_instance_valid(codex) and codex.visible:
		resource_hover_panel.hide()
		return
	var mouse: Vector2 = owner.get_global_mouse_position()
	var resource: String = ""
	for key in global_resource_tiles:
		if global_resource_tiles[key].get_global_rect().has_point(mouse):
			resource = key
			break
	var local_visible: bool = station_details.is_visible_in_tree() and overview_panel.get_global_rect().has_point(mouse) and not planet_query.call().is_empty()
	if resource.is_empty() and local_visible:
		if population_label.is_visible_in_tree() and population_label.get_parent().get_global_rect().has_point(mouse):
			resource = "local:population"
		else:
			for key in production_values:
				if production_values[key]["row"].is_visible_in_tree() and production_values[key]["row"].get_global_rect().has_point(mouse):
					resource = "local:" + str(key)
					break
	if resource.is_empty() and resource_hover_panel.visible and resource_hover_panel.get_global_rect().has_point(mouse):
		resource = hovered_resource
	if resource.is_empty() or state_query.call().is_empty():
		resource_hover_panel.hide()
		hovered_resource = ""
		return
	var state: Dictionary = state_query.call()
	var local: bool = resource.begins_with("local:")
	if local and (planet_query.call().is_empty() or not station_details.is_visible_in_tree()):
		resource_hover_panel.hide()
		hovered_resource = ""
		return
	var value: String = _local_breakdown(planet_query.call(), resource.trim_prefix("local:"), selected) if local else _resource_breakdown(state, resource)
	if resource_hover_label.text != value:
		resource_hover_label.text = value
	hovered_resource = resource
	var tile_rect: Rect2
	if local:
		tile_rect = population_label.get_parent().get_global_rect() if resource == "local:population" else production_values[resource.trim_prefix("local:")]["row"].get_global_rect()
	else:
		tile_rect = global_resource_tiles[resource].get_global_rect()
	var viewport: Vector2 = owner.get_viewport_rect().size
	var width: float = minf(420.0, viewport.x - 16.0)
	var available: float = tile_rect.position.y - 8.0 if local else viewport.y - tile_rect.end.y - 8.0
	var height: float = minf(maxf(40.0, available), maxf(105.0, 20.0 * float(value.count("\n") + 2)))
	resource_hover_panel.size = Vector2(width, height).round()
	var popup_y: float = tile_rect.position.y - height if local else tile_rect.end.y
	resource_hover_panel.global_position = Vector2(clampf(tile_rect.position.x, 8.0, viewport.x - width - 8.0), clampf(popup_y, 8.0, maxf(8.0, viewport.y - height - 8.0))).round()
	resource_hover_panel.show()

func refresh(state: Dictionary) -> void:
	year_label.text = "%d A.D." % ECONOMY.current_year(state)
	var totals: Dictionary = ECONOMY.empire_totals(state, local_player.call())
	var credit_income: float = ECONOMY.resident_tax_income(state, int(local_player.call())) - float(totals["upkeep"])
	var unpaid: int = int(totals["unpaid_ships"])
	var credit_balance: float = ECONOMY.credit_balance(state, local_player.call())
	global_credit_label.text = "%s%s" % [UI_TEXT.compact_amount(credit_balance), " !" if unpaid > 0 else ""]
	global_credit_label.add_theme_color_override("font_color", Color("#ff7777") if unpaid > 0 else HUD.CREDIT_COLOR)
	# Credits have no storage ceiling; normalize against the treasury, with
	# the starting balance as a floor to avoid exaggerated near-zero trends.
	global_resource_trends["credits"] = _trend_count(credit_income, maxf(credit_balance, ECONOMY.STARTING_GC))
	global_resource_strips["credits"].queue_redraw()
	for resource in ECONOMY.RESOURCES:
		var value: float = float(totals["resources"][resource])
		var annual: float = _empire_resource_delta(state, resource)
		global_resource_labels[resource].text = UI_TEXT.resource_amount(value, 0, true)
		var stored: float = float(totals["stock"][resource])
		var cargo: float = float(totals["cargo"][resource])
		var reference: float = float(totals["storage_reference"][resource])
		global_resource_trends[resource] = _trend_count(annual, reference)
		# Onboard stock occupies its own segment, not station storage.
		global_resource_fills[resource] = clampf(value / maxf(ECONOMY.EPS, reference + cargo), 0.0, 1.0)
		var tile: PanelContainer = global_resource_tiles[resource]
		var segments: Array = []
		if stored > 0.0 and value > 0.0:
			for i in range(state.get("planets", []).size()):
				var planet: Dictionary = state["planets"][i]
				if int(planet["owner"]) != local_player.call():
					continue
				var quantity: float = float(planet["stock"][resource])
				if quantity > 0.0:
					segments.append({"name": system_name.call(i), "share": quantity / value, "index": i})
			segments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["share"] > b["share"] if a["share"] != b["share"] else a["index"] < b["index"])
		if cargo > 0.0 and value > 0.0:
			segments.append({"name": "Fleet", "share": cargo / value, "index": -1, "color": Color("#5b90ba")})
		global_resource_segments[resource] = segments
		global_resource_strips[resource].queue_redraw()
		tile.tooltip_text = ""
	var population_total: float = float(totals["population"])
	var population_segments: Array = []
	var population_net: float = 0.0
	var population_ceiling: float = 0.0
	for i in range(state.get("planets", []).size()):
		var p: Dictionary = state["planets"][i]
		if int(p["owner"]) != local_player.call():
			continue
		population_ceiling += ECONOMY.sustainable_population_capacity(p)
		population_net += float(p.get("demographic_rate", ECONOMY.population_growth(p)))
		if population_total > 0.0 and float(p["population"]) > 0.0:
			population_segments.append({"name": system_name.call(i), "share": float(p["population"]) / population_total, "index": i})
	var fleet_population: float = float(totals["ship_population"]) + float(totals["embarking_population"])
	if fleet_population > 0.0 and population_total > 0.0:
		population_segments.append({"name": "Fleet", "share": fleet_population / population_total, "index": -1, "color": Color("#5b90ba")})
	population_ceiling += fleet_population
	population_segments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["share"] > b["share"] if a["share"] != b["share"] else a["index"] < b["index"])
	global_population_label.text = UI_TEXT.compact_amount(population_total)
	global_resource_trends["population"] = _trend_count(population_net, population_ceiling)
	global_population_label.tooltip_text = ""
	global_resource_segments["population"] = population_segments
	global_resource_fills["population"] = clampf(population_total / maxf(ECONOMY.EPS, population_ceiling), 0.0, 1.0)
	global_resource_strips["population"].queue_redraw()


extends Button
## Construction costs and shared information-panel content.
const HUD = preload("res://scripts/ui_theme.gd")
const ECONOMY = preload("res://scripts/economy_rules.gd")

var recipe: Dictionary = {}
var missing: Array[String] = []
var crew_icon: Texture2D
var effect_resource: String = ""
var fast_tooltip: bool = false

func set_recipe(cost: Dictionary, crew: float, population_icon: Texture2D, available: Dictionary) -> void:
	recipe = cost.duplicate()
	if not cost.is_empty():
		recipe["GC"] = ECONOMY.construction_credit_cost(cost)
	missing.clear()
	if crew > 0.0:
		recipe["Population"] = crew
		crew_icon = population_icon
	if not available.is_empty():
		for resource in recipe:
			if float(available.get(resource, 0.0)) + ECONOMY.EPS < float(recipe[resource]):
				missing.append(resource)

func _get_tooltip(_at_position: Vector2) -> String:
	return "" if fast_tooltip else tooltip_text

func _make_custom_tooltip(for_text: String) -> Object:
	if recipe.is_empty():
		return null
	return build_info(for_text, recipe, missing, crew_icon, effect_resource)

static func build_info(for_text: String, costs_by_resource: Dictionary, shortages: Array[String], population_icon: Texture2D, yield_resource: String, width: float = 0.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme = HUD.compact()
	panel.add_theme_stylebox_override("panel", HUD.surface(Color("#101b29"), Color("#6385a4"), 8, 3))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	if width > 0.0:
		body.custom_minimum_size.x = width - 22.0
	panel.add_child(body)
	var lines: PackedStringArray = for_text.split("\n", true, 1)
	var title := Label.new()
	title.text = lines[0]
	if width > 0.0:
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", HUD.ACCENT)
	title.add_theme_font_size_override("font_size", 14)
	body.add_child(title)
	if not costs_by_resource.is_empty():
		var costs := GridContainer.new()
		costs.columns = mini(3, costs_by_resource.size())
		costs.add_theme_constant_override("h_separation", 12)
		costs.add_theme_constant_override("v_separation", 4)
		body.add_child(costs)
		for resource in costs_by_resource:
			var pair := HBoxContainer.new()
			pair.add_theme_constant_override("separation", 4)
			costs.add_child(pair)
			if resource != "GC":
				var symbol := TextureRect.new()
				HUD.fixed_icon(symbol, population_icon if resource == "Population" else HUD.resource_icon(resource, 24), 24)
				pair.add_child(symbol)
			var amount := Label.new()
			amount.text = "%.0f%s" % [float(costs_by_resource[resource]), " GC" if resource == "GC" else ("" if resource == "Population" else "t")]
			if resource == "GC":
				amount.add_theme_color_override("font_color", Color("#e7c76b"))
			if shortages.has(resource):
				amount.add_theme_color_override("font_color", Color("#ff7777"))
			pair.add_child(amount)
	if lines.size() > 1:
		for line in lines[1].split("\n", false):
			var details := Label.new()
			if width > 0.0:
				details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if line.begins_with("Yield: ") and not yield_resource.is_empty():
				var benefit := HBoxContainer.new()
				benefit.add_theme_constant_override("separation", 4)
				body.add_child(benefit)
				var symbol := TextureRect.new()
				HUD.fixed_icon(symbol, HUD.resource_icon(yield_resource, 24), 24)
				benefit.add_child(symbol)
				details.text = line.trim_prefix("Yield: ")
				details.add_theme_color_override("font_color", Color("#9fe3b5"))
				benefit.add_child(details)
			else:
				details.text = line
				body.add_child(details)
	return panel

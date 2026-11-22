extends Button
## Construction recipe tooltip; native and fast modes share this widget.
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
	var panel := PanelContainer.new()
	panel.theme = HUD.compact()
	panel.add_theme_stylebox_override("panel", HUD.surface(Color("#101b29"), Color("#6385a4"), 8, 3))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	panel.add_child(body)
	var lines: PackedStringArray = for_text.split("\n", true, 1)
	var title := Label.new()
	title.text = lines[0]
	title.add_theme_color_override("font_color", HUD.ACCENT)
	title.add_theme_font_size_override("font_size", 14)
	body.add_child(title)
	var costs := GridContainer.new()
	costs.columns = mini(3, recipe.size())
	costs.add_theme_constant_override("h_separation", 12)
	costs.add_theme_constant_override("v_separation", 4)
	body.add_child(costs)
	for resource in recipe:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 4)
		costs.add_child(pair)
		if resource != "GC":
			var symbol := TextureRect.new()
			HUD.fixed_icon(symbol, crew_icon if resource == "Population" else HUD.resource_icon(resource, 24), 24)
			pair.add_child(symbol)
		var amount := Label.new()
		amount.text = "%.0f%s" % [float(recipe[resource]), " GC" if resource == "GC" else ("" if resource == "Population" else "t")]
		if resource == "GC":
			amount.add_theme_color_override("font_color", Color("#e7c76b"))
		if missing.has(resource):
			amount.add_theme_color_override("font_color", Color("#ff7777"))
		pair.add_child(amount)
	if lines.size() > 1:
		for line in lines[1].split("\n", false):
			var details := Label.new()
			if line.begins_with("Yield: ") and not effect_resource.is_empty():
				var benefit := HBoxContainer.new()
				benefit.add_theme_constant_override("separation", 4)
				body.add_child(benefit)
				var symbol := TextureRect.new()
				HUD.fixed_icon(symbol, HUD.resource_icon(effect_resource, 24), 24)
				benefit.add_child(symbol)
				details.text = line.trim_prefix("Yield: ")
				details.add_theme_color_override("font_color", Color("#9fe3b5"))
				benefit.add_child(details)
			else:
				details.text = line
				body.add_child(details)
	return panel

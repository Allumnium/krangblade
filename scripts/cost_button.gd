extends Button
## Construction costs and shared information-panel content.
const HUD = preload("res://scripts/ui_theme.gd")
const ECONOMY = preload("res://scripts/economy_rules.gd")

var recipe: Dictionary = {}
var missing: Array[String] = []
var crew_icon: Texture2D
var effect_resource: String = ""

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

# Command cards use this renderer exclusively; no native custom tooltip.
static func fill_info(label: RichTextLabel, description: String, costs_by_resource: Dictionary, shortages: Array[String], population_icon: Texture2D, yield_resource: String) -> void:
	label.clear()
	var lines: PackedStringArray = description.split("\n", false)
	if lines.is_empty():
		return
	# Put the shortcut beside the heading instead of wasting a row.
	var heading: String = lines[0]
	for index in range(lines.size() - 1, 0, -1):
		var line: String = lines[index]
		if line.begins_with("[") and line.ends_with("]"):
			heading += "  " + line
			lines.remove_at(index)
			break
	label.push_color(HUD.ACCENT)
	label.add_text(heading)
	label.pop()
	if not costs_by_resource.is_empty():
		label.newline()
		var count: int = 0
		for resource in costs_by_resource:
			if count > 0:
				label.add_text("   ")
			if resource != "GC":
				var symbol: Texture2D = population_icon if resource == "Population" else HUD.resource_icon(resource, 24)
				if symbol != null:
					label.add_image(symbol, 14, 14)
					label.add_text(" ")
			var amount_color: Color = Color("#ff7777") if shortages.has(resource) else (Color("#e7c76b") if resource == "GC" else HUD.TEXT)
			label.push_color(amount_color)
			label.add_text("%.0f%s" % [float(costs_by_resource[resource]), " GC" if resource == "GC" else ("" if resource == "Population" else "t")])
			label.pop()
			count += 1
	for index in range(1, lines.size()):
		var detail: String = lines[index]
		label.newline()
		if detail.begins_with("Yield: ") and not yield_resource.is_empty():
			label.add_image(HUD.resource_icon(yield_resource, 24), 14, 14)
			label.add_text(" ")
			label.push_color(Color("#9fe3b5"))
			label.add_text(detail.trim_prefix("Yield: "))
			label.pop()
		elif detail.begins_with("Reference: "):
			label.push_color(HUD.MUTED)
			label.add_text(detail.trim_prefix("Reference: "))
			label.pop()
		else:
			label.add_text(detail)

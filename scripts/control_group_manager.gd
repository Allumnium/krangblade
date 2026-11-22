extends RefCounted
## Local match control group storage, pruning, assignment and button presentation.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const GROUP_ICON_WIDTH: int = 16
const EMPTY_GROUP_WIDTH: float = 20.0

var control_groups: Dictionary = {}
var control_group_buttons: Dictionary = {}

func _control_ref_valid(state: Dictionary, ref: Vector2i, kind: String, expected_count: int, player: int, building_valid: Callable) -> bool:
	var planets: Array = state.get("planets", [])
	if ref.x < 0 or ref.x >= planets.size() or int(planets[ref.x]["owner"]) != player:
		return false
	if kind == "system":
		return ECONOMY.has_station(planets[ref.x])
	if kind == "planet":
		return ref.y >= 0 and ref.y < int(planets[ref.x].get("planet_count", 0))
	return building_valid.call(state, ref, kind, expected_count)

func prune(state: Dictionary, group: Dictionary, player: int, building_valid: Callable) -> Dictionary:
	var kind: String = group.get("kind", "")
	if kind == "units":
		var ids: Array[int] = []
		for craft in state.get("ships", []):
			if int(craft["owner"]) == player and group["ids"].has(int(craft["id"])):
				ids.append(int(craft["id"]))
		return {} if ids.is_empty() else {"kind": kind, "ids": ids}
	if kind.is_empty():
		return {}
	var refs: Dictionary = {}
	for ref in group["refs"]:
		if _control_ref_valid(state, ref, kind, int(group["refs"][ref]), player, building_valid):
			refs[ref] = group["refs"][ref]
	return {} if refs.is_empty() else {"kind": kind, "refs": refs}

func assign(state: Dictionary, number: int, group: Dictionary, additive: bool, player: int, building_valid: Callable) -> void:
	if not group.is_empty():
		if additive:
			var previous: Dictionary = prune(state, control_groups.get(number, {}), player, building_valid)
			if not previous.is_empty() and previous["kind"] != group["kind"]:
				return
			if not previous.is_empty():
				if group["kind"] == "units":
					var ids: Array = previous["ids"].duplicate()
					for id in group["ids"]:
						if not ids.has(id):
							ids.append(id)
					group["ids"] = ids
				elif group["kind"] in ["shipyard", "station", "pds"]:
					var refs: Dictionary = previous["refs"].duplicate()
					refs.merge(group["refs"], true)
					group["refs"] = refs
				else:
					return
		control_groups[number] = group

func refresh(state: Dictionary, player: int, building_valid: Callable, hull_art: RefCounted, command_card_ui: RefCounted) -> void:
	var ship_kinds: Dictionary = {}
	for craft in state.get("ships", []):
		if int(craft["owner"]) == player:
			ship_kinds[int(craft["id"])] = str(craft["kind"])
	for number in control_group_buttons:
		var button: Button = control_group_buttons[number]
		var group: Dictionary = prune(state, control_groups.get(number, {}), player, building_valid)
		if group.is_empty():
			control_groups.erase(number)
			button.text = str(number)
			button.icon = null
			button.alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.custom_minimum_size.x = EMPTY_GROUP_WIDTH
			button.disabled = true
			command_card_ui.set_hint(button, "Ctrl+%d to assign a selection" % number)
			continue
		control_groups[number] = group
		var kind: String = group["kind"]
		var count: int = group["ids"].size() if kind == "units" else group["refs"].size()
		var icon_kind: String = "station" if kind == "system" else kind
		if kind == "units":
			var counts: Dictionary = {}
			var highest: int = 0
			for id in group["ids"]:
				var ship_kind: String = str(ship_kinds[id])
				var members: int = int(counts.get(ship_kind, 0)) + 1
				counts[ship_kind] = members
				if members > highest or (members == highest and ship_kind < icon_kind):
					highest = members
					icon_kind = ship_kind
		button.text = str(count)
		button.icon = hull_art.selection_portrait_icon(icon_kind)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var font: Font = button.get_theme_font("font")
		var text_width: float = ceilf(font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x)
		var padding: float = button.get_theme_stylebox("normal").get_minimum_size().x
		button.custom_minimum_size.x = GROUP_ICON_WIDTH + text_width + padding + button.get_theme_constant("h_separation") + 2.0
		button.disabled = false
		command_card_ui.set_hint(button, "Group %d · %d %s\n%d: Select · Twice: Center\nCtrl+%d: Replace · Shift+%d: Add" % [number, count, "ships" if kind == "units" else "structures", number, number, number])

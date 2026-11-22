extends RefCounted
## Per-client live and explored fog cells with a shared map/minimap mask.
## This is presentation state, not authority or network visibility enforcement.
const ECONOMY = preload("res://scripts/economy_rules.gd")

var _live: Dictionary = {}
var _explored: Dictionary = {}
var texture: ImageTexture
var _origin := Vector2.ZERO
var extent := Vector2.ZERO
var _revision: Array = []

func update(state: Dictionary, player: int, motion_revision: Variant, map_size: Vector2) -> bool:
	if state.is_empty():
		return false
	var team: int = ECONOMY._combat_group(state, player)
	var revision: Array = [state.get("elapsed"), motion_revision, team, state["ships"].size(), state.get("diplomacy_revision", 0)]
	if revision == _revision:
		return false
	_revision = revision
	_live = ECONOMY.team_vision(state, team)
	_explored.merge(_live, true)
	var cell: float = ECONOMY.VISION_CELL
	var start := Vector2i.ZERO
	var finish: Vector2i = ECONOMY.vision_cell(map_size)
	var dimensions: Vector2i = finish - start + Vector2i.ONE
	var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.015, 0.025, 0.04, 0.96))
	for key in _explored:
		var pixel: Vector2i = key - start
		if Rect2i(Vector2i.ZERO, dimensions).has_point(pixel):
			image.set_pixelv(pixel, Color(0.015, 0.025, 0.04, 0.62))
	for key in _live:
		var pixel: Vector2i = key - start
		if Rect2i(Vector2i.ZERO, dimensions).has_point(pixel):
			image.set_pixelv(pixel, Color(0.0, 0.0, 0.0, 0.0))
	if texture == null or texture.get_size() != Vector2(dimensions):
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	_origin = Vector2(start) * cell
	extent = Vector2(dimensions) * cell
	return true

func is_visible(point: Vector2, map_size: Vector2) -> bool:
	return point.is_finite() and Rect2(Vector2.ZERO, map_size).has_point(point) and _live.has(ECONOMY.vision_cell(point))

func draw(overlay: Control, bounds: Rect2, map_rect: Rect2, map_size: Vector2) -> void:
	if texture == null:
		return
	var inside: Rect2 = bounds.intersection(map_rect)
	var dark := Color(0.015, 0.025, 0.04, 0.96)
	if not inside.has_area():
		overlay.draw_rect(bounds, dark)
		return
	# Cover every exterior pixel, independent of camera zoom or pan.
	overlay.draw_rect(Rect2(bounds.position, Vector2(bounds.size.x, inside.position.y)), dark)
	overlay.draw_rect(Rect2(Vector2(0, inside.end.y), Vector2(bounds.size.x, bounds.end.y - inside.end.y)), dark)
	overlay.draw_rect(Rect2(Vector2(0, inside.position.y), Vector2(inside.position.x, inside.size.y)), dark)
	overlay.draw_rect(Rect2(Vector2(inside.end.x, inside.position.y), Vector2(bounds.end.x - inside.end.x, inside.size.y)), dark)
	var source := Rect2(Vector2.ZERO, map_size / ECONOMY.VISION_CELL)
	overlay.draw_texture_rect_region(texture, map_rect, source)

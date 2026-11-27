extends RefCounted
## Client camera state and world/screen projection. No node or selection dependencies.
## View geometry is supplied by the match controller, preserving HUD framing.
const KEYBOARD_PAN_SPEED: float = 420.0
const MIN_ZOOM: float = 1.0 / 1.10
const MAP_EDGE_MARGIN: float = 0.05
const FIGHTER_HULL_LENGTH: float = 22.0
const CLOSEUP_SCREEN_FRACTION: float = 0.6
const SHIP_WORLD_SCALE: float = 1.5

var zoom: float = 1.0
var world: Vector2 = Vector2.INF
var following: bool = false

func reset() -> void:
	following = false
	zoom = 1.0
	world = Vector2.INF

func fit(projection_size: Vector2, map_size: Vector2) -> float:
	var area: Vector2 = projection_size - Vector2(24, 52)
	return maxf(0.0001, minf(area.x / map_size.x, area.y / map_size.y))

func world_center(map_size: Vector2) -> Vector2:
	return world if world.is_finite() else map_size * 0.5

# Allow a modest margin beyond the map without panning into empty space.
# At close range an edge object can still be centered. When a whole axis
# fits, center that axis rather than letting the map drift off-screen.
func set_world_center(point: Vector2, projection_size: Vector2, map_size: Vector2) -> void:
	if not point.is_finite():
		return
	var extent: Vector2 = map_size.max(Vector2.ONE)
	var half_view: Vector2 = projection_size.max(Vector2.ONE) * 0.5 / (fit(projection_size, extent) * maxf(MIN_ZOOM, zoom))
	var inset: Vector2 = (half_view - extent * MAP_EDGE_MARGIN).clamp(Vector2.ZERO, extent * 0.5)
	if half_view.x >= extent.x * 0.5:
		inset.x = extent.x * 0.5
	if half_view.y >= extent.y * 0.5:
		inset.y = extent.y * 0.5
	world = point.clamp(inset, extent - inset)

func constrain(projection_size: Vector2, map_size: Vector2) -> void:
	if world.is_finite():
		set_world_center(world, projection_size, map_size)

func screen_point(point: Vector2, projection_size: Vector2, map_size: Vector2) -> Vector2:
	return projection_size * 0.5 + (point - world_center(map_size)) * fit(projection_size, map_size) * zoom

func world_point(point: Vector2, projection_size: Vector2, map_size: Vector2) -> Vector2:
	return world_center(map_size) + (point - projection_size * 0.5) / (fit(projection_size, map_size) * zoom)

static func ship_art_scale(projection_fit: float, camera_zoom: float) -> float:
	return SHIP_WORLD_SCALE * projection_fit * camera_zoom

func max_zoom(viewport_width: float, projection_size: Vector2, map_size: Vector2) -> float:
	# Keep the fighter close-up framing with the same linear art projection.
	var target_scale: float = viewport_width * CLOSEUP_SCREEN_FRACTION / FIGHTER_HULL_LENGTH
	return maxf(MIN_ZOOM * 1.01, target_scale / ship_art_scale(fit(projection_size, map_size), 1.0))

func zoom_at(point: Vector2, direction: float, viewport_width: float, projection_size: Vector2, map_size: Vector2) -> void:
	var anchor: Vector2 = projection_size * 0.5 if following else point
	var anchored_world: Vector2 = world_point(anchor, projection_size, map_size)
	var maximum: float = max_zoom(viewport_width, projection_size, map_size)
	# Reversible log-space steps become finer near the close-up limit.
	var log_span: float = log(maximum / MIN_ZOOM)
	var log_zoom: float = log(zoom / MIN_ZOOM)
	var rate: float = (0.25 - 0.06) / log_span
	var limit: float = 0.25 / rate
	var next_log: float = limit - (limit - log_zoom) * exp(-rate * direction)
	zoom = clampf(MIN_ZOOM * exp(next_log), MIN_ZOOM, maximum)
	set_world_center(anchored_world - (anchor - projection_size * 0.5) / (fit(projection_size, map_size) * zoom), projection_size, map_size)

func pan(direction: Vector2, delta: float, projection_size: Vector2, map_size: Vector2) -> void:
	following = false
	set_world_center(world_center(map_size) + direction * KEYBOARD_PAN_SPEED * delta / (fit(projection_size, map_size) * zoom), projection_size, map_size)

func bounds_zoom(bounds: Rect2, viewport_width: float, projection_size: Vector2, map_size: Vector2) -> float:
	var available: Vector2 = projection_size * 0.78
	var extent: Vector2 = bounds.size.max(Vector2.ONE)
	return clampf(minf(available.x / extent.x, available.y / extent.y) / fit(projection_size, map_size), MIN_ZOOM, max_zoom(viewport_width, projection_size, map_size))

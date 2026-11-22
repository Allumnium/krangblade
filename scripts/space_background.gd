extends ColorRect
## GPU-animated shared star field, behind all interactive controls.
const STAR_SHADER = preload("res://assets/ui/starfield.gdshader")

var _previous_center: Vector2 = Vector2.INF
var _previous_scale: float = 0.0
var _pan_pixels: Vector2 = Vector2.ZERO
var _last_shift: Vector2 = Vector2.INF
var _last_zoom: float = INF

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = STAR_SHADER
	material = mat

# Camera only: integrate screen-space travel, not absolute world position.
# This prevents high zoom levels from multiplying old pan offsets.
# Menus never call this; their existing animated backdrop is unchanged.
func set_camera_pose(center: Vector2, world_scale: float, zoom: float) -> void:
	if not center.is_finite() or world_scale <= 0.0 or not material is ShaderMaterial:
		return
	if _previous_center.is_finite():
		_pan_pixels += (center - _previous_center) * minf(_previous_scale, world_scale)
	_previous_center = center
	_previous_scale = world_scale
	var shift: Vector2 = _pan_pixels / maxf(1.0, size.y)
	var zoom_log: float = log(maxf(0.5, zoom))
	var mat: ShaderMaterial = material
	if not shift.is_equal_approx(_last_shift):
		mat.set_shader_parameter("camera_shift", shift)
		_last_shift = shift
	if not is_finite(_last_zoom) or not is_equal_approx(zoom_log, _last_zoom):
		mat.set_shader_parameter("camera_zoom_log", zoom_log)
		_last_zoom = zoom_log

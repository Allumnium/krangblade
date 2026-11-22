extends Control
## Client trade threshold widget; emits committed percentages without changing simulation state.
signal committed(minimum: float, maximum: float)
var lower: float = 50.0
var upper: float = 80.0
var stock_percent: float = 0.0
var stock_color: Color = Color.WHITE
var enabled: bool = true
var import_enabled: bool = true
var export_enabled: bool = true
var active_handle: int = -1
const PAD: float = 10.0
const TRACK_Y: float = 13.0

func set_range(minimum: float, maximum: float) -> void:
	active_handle = -1
	lower = clampf(minimum, 0.0, 100.0)
	upper = clampf(maximum, 0.0, 100.0)
	queue_redraw()

func set_stock(amount: float, maximum: float, tint: Color) -> void:
	stock_percent = clampf(100.0 * amount / maxf(maximum, 1.0), 0.0, 100.0)
	stock_color = Color("#b9c8d6")
	queue_redraw()

func _x(value: float) -> float:
	return PAD + maxf(1.0, size.x - PAD * 2.0) * value / 100.0

func _value(x: float) -> float:
	return roundf(clampf((x - PAD) / maxf(1.0, size.x - PAD * 2.0) * 100.0, 0.0, 100.0))

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var low_color := Color("#c9d6e2") if enabled else Color("#667687")
	var high_color := Color("#c9d6e2") if enabled else Color("#667687")
	var left: String = "Import < %d%%" % roundi(lower)
	var right: String = "Export > %d%%" % roundi(upper)

	var lo := Vector2(_x(lower), TRACK_Y)
	var hi := Vector2(_x(upper), TRACK_Y)
	draw_line(Vector2(PAD, TRACK_Y), Vector2(size.x - PAD, TRACK_Y), Color("#344960"), 5.0, true)
	if stock_percent > 0.0:
		draw_line(Vector2(PAD, TRACK_Y), Vector2(_x(stock_percent), TRACK_Y), stock_color, 7.0, true)
	# Offset the handles vertically when their values meet, keeping both visible.
	var overlap: bool = absf(lo.x - hi.x) < 13.0
	if overlap:
		lo.y -= 5.0
		hi.y += 5.0
	if import_enabled:
		draw_circle(lo, 7.0, low_color)
	if export_enabled:
		draw_circle(hi, 7.0, high_color)

func _move_handle(x: float) -> void:
	if active_handle == 0:
		lower = _value(x)
		if export_enabled:
			upper = maxf(upper, lower)
	elif active_handle == 1:
		upper = _value(x)
		if import_enabled:
			lower = minf(lower, upper)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var lo := Vector2(_x(lower), TRACK_Y)
			var hi := Vector2(_x(upper), TRACK_Y)
			if absf(lo.x - hi.x) < 13.0:
				lo.y -= 5.0
				hi.y += 5.0
			if not import_enabled and not export_enabled:
				return
			active_handle = 0 if import_enabled and (not export_enabled or event.position.distance_to(lo) < event.position.distance_to(hi)) else 1
			_move_handle(event.position.x)
		elif active_handle >= 0:
			_move_handle(event.position.x)
			active_handle = -1
			committed.emit(lower, upper)
		accept_event()
	elif event is InputEventMouseMotion and active_handle >= 0:
		_move_handle(event.position.x)
		accept_event()

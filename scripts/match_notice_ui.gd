extends RefCounted
## Per-match chat and notification history; client presentation only.
const HUD = preload("res://scripts/ui_theme.gd")
const ECONOMY = preload("res://scripts/economy_rules.gd")
const RULES = preload("res://scripts/lobby_rules.gd")
const COLORS = RULES.EMPIRE_COLORS

const NOTICE_HISTORY_LIMIT: int = 250
const NOTICE_LIFETIME_MS: int = 10000
var tactical_hit_rects: Array[Dictionary] = []
var match_chat_edit: LineEdit
var match_chat_panel: PanelContainer
var match_chat_log: RichTextLabel
var match_chat_content: VBoxContainer
var notice_history: Array[Dictionary] = []
var notice_seen: Dictionary = {}

var map_canvas: Control
var objectives_overlay: Control
var minimap: Control
var timer_panel: Control
var session: Node
var header_height: float
var objectives_width: float
var local_player: Callable
var color_index: Callable
var jump_location: Callable

func build(canvas: Control, overlay: Control, session_node: Node, header: float, objective_width: float, player_query: Callable, color_query: Callable, jump_query: Callable) -> void:
	map_canvas = canvas
	objectives_overlay = overlay
	session = session_node
	header_height = header
	objectives_width = objective_width
	local_player = player_query
	color_index = color_query
	jump_location = jump_query
	match_chat_panel = PanelContainer.new()
	match_chat_panel.z_index = 6
	match_chat_panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928d9"), Color("#45617b"), 6, 4))
	map_canvas.add_child(match_chat_panel)
	match_chat_content = VBoxContainer.new()
	match_chat_content.add_theme_constant_override("separation", 4)
	match_chat_panel.add_child(match_chat_content)
	match_chat_log = RichTextLabel.new()
	match_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	match_chat_log.add_theme_font_size_override("normal_font_size", 13)
	match_chat_log.scroll_active = true
	match_chat_log.scroll_following = true
	match_chat_log.selection_enabled = true
	match_chat_log.meta_clicked.connect(_jump_history_alert)
	match_chat_content.add_child(match_chat_log)
	match_chat_edit = LineEdit.new()
	match_chat_edit.placeholder_text = "All chat · Enter sends · Esc closes"
	match_chat_edit.max_length = 250
	match_chat_content.add_child(match_chat_edit)
	match_chat_panel.hide()


func attach_minimap(control: Control, timer: Control = null) -> void:
	minimap = control
	timer_panel = timer
	minimap.item_rect_changed.connect(layout)
	if is_instance_valid(timer_panel):
		timer_panel.item_rect_changed.connect(layout)

func is_built() -> bool:
	return is_instance_valid(match_chat_panel)

func is_open() -> bool:
	return is_built() and match_chat_panel.visible

func contains_point(point: Vector2) -> bool:
	return is_open() and match_chat_panel.get_global_rect().has_point(point)

func open(state: Dictionary, alerts: Dictionary) -> void:
	sync_history(state, alerts)
	layout()
	_rebuild_notice_log()
	match_chat_panel.show()
	match_chat_log.call_deferred("scroll_to_line", maxi(0, match_chat_log.get_line_count() - 1))
	match_chat_edit.grab_focus()

func clear_hit_rects() -> void:
	tactical_hit_rects.clear()

func jump_tactical_alert(point: Vector2) -> bool:
	for hit in tactical_hit_rects:
		if (hit["rect"] as Rect2).has_point(point):
			jump_location.call(hit["alert"])
			return true
	return false

func _jump_history_alert(meta: Variant) -> void:
	if meta is Dictionary:
		jump_location.call(meta)

func layout() -> void:
	if not is_instance_valid(match_chat_panel) or not is_instance_valid(minimap):
		return
	var width: float = _notification_width()
	var bottom: float = _notification_bottom()
	var height: float = minf(300.0, maxf(80.0, bottom - header_height - 12.0))
	match_chat_panel.size = Vector2(width, height)
	match_chat_panel.position = Vector2(_notification_left(), bottom - match_chat_panel.size.y)

func close() -> void:
	if is_instance_valid(match_chat_panel):
		match_chat_edit.release_focus()
		match_chat_panel.hide()
		match_chat_edit.clear()

func _notification_width() -> float:
	var available: float = maxf(80.0, map_canvas.size.x - objectives_width - 16.0)
	return minf(clampf(minimap.size.x + 80.0, 260.0, 420.0), available) if is_instance_valid(minimap) else minf(320.0, available)

func _notification_left() -> float:
	return minimap.global_position.x - map_canvas.global_position.x if is_instance_valid(minimap) else 8.0

func _notification_bottom() -> float:
	return minimap.global_position.y - map_canvas.global_position.y - 6.0 - (timer_panel.size.y if is_instance_valid(timer_panel) else 0.0) if is_instance_valid(minimap) else map_canvas.size.y * 0.6

func _append_notice(entry: Dictionary) -> void:
	notice_history.append(entry)
	if notice_history.size() > NOTICE_HISTORY_LIMIT:
		notice_history.pop_front()
		if is_instance_valid(match_chat_panel) and match_chat_panel.visible:
			_rebuild_notice_log()
	elif is_instance_valid(match_chat_panel) and match_chat_panel.visible:
		_append_notice_log(entry)

func _append_notice_log(entry: Dictionary) -> void:
	if not match_chat_log.get_parsed_text().is_empty():
		match_chat_log.newline()
	match_chat_log.push_color(entry["tint"])
	if entry.has("alert"):
		match_chat_log.push_meta(entry["alert"])
	match_chat_log.add_text(entry["text"])
	if entry.has("alert"):
		match_chat_log.pop()
	match_chat_log.pop()

func _rebuild_notice_log() -> void:
	match_chat_log.clear()
	for entry in notice_history:
		_append_notice_log(entry)

func local_console_notice(message: String) -> void:
	_append_notice({"text": message, "tint": HUD.MUTED, "born": Time.get_ticks_msec()})

func clear_history() -> void:
	notice_history.clear()
	match_chat_log.clear()
	tactical_hit_rects.clear()
	objectives_overlay.queue_redraw()

func sync_history(state: Dictionary, alerts: Dictionary) -> void:
	if not is_instance_valid(match_chat_panel) or str(session.get("phase")) != "match" or state.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var current: Dictionary = {}
	var incoming: Array[Dictionary] = []
	for item in session.get("match_chat"):
		var key: String = "chat:" + str([item["sender"], item["received_ms"], item["text"]])
		current[key] = true
		if not notice_seen.has(key):
			var index: int = clampi(int(item.get("sender_color", color_index.call(int(item["sender"])))), 0, RULES.MAX_PLAYERS)
			incoming.append({"text": str(item["text"]), "tint": COLORS[index], "born": int(item["received_ms"])})
	for key in alerts:
		var alert: Dictionary = alerts[key]
		var identity: String = "alert:" + str([key, alert["born"]])
		current[identity] = true
		if not notice_seen.has(identity):
			var tint := Color("#ffb16b") if str(key).begins_with("approach:") else Color("#ff7777")
			incoming.append({"text": str(alert["text"]), "tint": tint, "born": int(alert["born"]), "alert": alert.duplicate(true)})
	var roster: Dictionary = session.get("players")
	var transfers: Dictionary = state.get("defeat_credit_transfers", {})
	for defeated in transfers:
		var identity: String = "defeat_gc:" + str(defeated)
		current[identity] = true
		if notice_seen.has(identity):
			continue
		var payouts: Dictionary = transfers[defeated]
		var total: float = 0.0
		for amount in payouts.values():
			total += float(amount)
		var name_text: String = str(roster.get(defeated, {}).get("name", "Player")).left(20)
		var message: String = "%s defeated · %.2f GC shared among %d allies" % [name_text, total, payouts.size()]
		if payouts.has(local_player.call()):
			message += " · You received %.2f GC" % float(payouts[local_player.call()])
		incoming.append({"text": message, "tint": Color("#e9cb7c"), "born": now})
	for event in state.get("objective_events", []):
		if int(event["player"]) != local_player.call():
			continue
		var identity: String = "objective:" + str([event.get("objective", ""), event.get("reward", ""), event["elapsed"]])
		current[identity] = true
		if notice_seen.has(identity):
			continue
		var name_text: String = str(roster.get(event["player"], {}).get("name", "Player")).left(20)
		var message: String
		var tint := Color("#e9cb7c")
		if event.has("reward"):
			message = "%s acquired %s (Unique)" % [name_text, ECONOMY.CONQUEST_REWARDS[event["reward"]][0]]
			tint = Color("#c7aaff")
		else:
			message = "%s completed %s · +%d CP" % [name_text, ECONOMY.objective_label(str(event["objective"])), int(event["award"])]
			if not bool(event["first"]):
				tint = Color("#b8d9ef")
		incoming.append({"text": message, "tint": tint, "born": now})
	notice_seen = current
	incoming.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["born"]) < int(b["born"]))
	for entry in incoming:
		_append_notice(entry)

func _draw_notice_text(font: Font, point: Vector2, message: String, width: float, tint: Color) -> float:
	var height: float = font.get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, width, 13).y
	objectives_overlay.draw_multiline_string_outline(font, point, message, HORIZONTAL_ALIGNMENT_LEFT, width, 13, -1, 4, Color(0.04, 0.08, 0.13, tint.a))
	objectives_overlay.draw_multiline_string(font, point, message, HORIZONTAL_ALIGNMENT_LEFT, width, 13, -1, tint)
	return height

func draw(font: Font) -> void:
	tactical_hit_rects.clear()
	if is_instance_valid(match_chat_panel) and match_chat_panel.visible:
		return
	var bottom: float = _notification_bottom()
	var width: float = _notification_width() - 12.0
	var left: float = _notification_left() + 4.0
	var now: int = Time.get_ticks_msec()
	var visible_count: int = 0
	for index in range(notice_history.size() - 1, -1, -1):
		var entry: Dictionary = notice_history[index]
		var age: int = now - int(entry["born"])
		if age >= NOTICE_LIFETIME_MS:
			continue
		var message: String = entry["text"]
		var height: float = font.get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, width, 13).y
		var top: float = bottom - height
		if top < header_height + 8.0:
			break
		var tint: Color = entry["tint"]
		tint.a = clampf(float(NOTICE_LIFETIME_MS - age) / 2000.0, 0.0, 1.0)
		_draw_notice_text(font, Vector2(left, top + font.get_ascent(13)), message, width, tint)
		if entry.has("alert"):
			tactical_hit_rects.append({"rect": Rect2(left - 4.0, top, width + 8.0, height), "alert": entry["alert"]})
		bottom = top - 6.0
		visible_count += 1
		if visible_count >= 5:
			break


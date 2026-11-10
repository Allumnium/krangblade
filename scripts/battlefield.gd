extends Control
## Graph renderer and camera; consumes snapshots and never changes gameplay state.
signal node_selected(node: int)
const MAP = preload("res://scripts/map_generator.gd")
const SIM = preload("res://scripts/match_simulation.gd")
const PAN_SPEED: float = 650.0
const EDGE_MARGIN: float = 20.0
const COLORS := [Color("#415268"), Color("#67d4a9"), Color("#f4a46a"), Color("#77aafe"), Color("#ce91ed"), Color("#eed16b"), Color("#f084a6"), Color("#6bcbd4"), Color("#ed7577")]
var network: Node
var zoom: float = 0.2
var pan := Vector2.ZERO
var selected: int = -1
var dragging: bool = false
var last_state: Dictionary = {}
var previous_positions: Dictionary = {}
var current_positions: Dictionary = {}
var blend: float = 1.0
var preview: Array[int] = []
var preview_key: String = ""
var hover: int = -1
var fitted: bool = false
var previous_size := Vector2.ZERO
var pointer_inside: bool = false

func _ready() -> void:
    network = get_node("/root/GameSession")
    clip_contents = true
    mouse_default_cursor_shape = Control.CURSOR_CROSS
    network.connect("state_changed", _snapshot)
    resized.connect(_resized)
    gui_input.connect(_input_map)
    mouse_entered.connect(func() -> void: pointer_inside = true)
    mouse_exited.connect(func() -> void: pointer_inside = false)
    previous_size = size
    _snapshot()
    call_deferred("fit_map")

func fit_map() -> void:
    zoom = maxf(0.04, minf(size.x - 48.0, size.y - 64.0) / 2600.0)
    pan = size * 0.5 - Vector2(0, 6)
    fitted = true
    previous_size = size
    queue_redraw()

func _resized() -> void:
    if fitted:
        fit_map()
    else:
        # Preserve the viewed world position when fullscreen or HUD wrapping
        # changes the battlefield dimensions, rather than resetting the zoom.
        pan += (size - previous_size) * 0.5
        previous_size = size

func _snapshot() -> void:
    previous_positions = current_positions.duplicate()
    current_positions.clear()
    var map: Dictionary = network.get("map_data")
    last_state = network.get("match_state")
    if map.is_empty() or last_state.is_empty():
        queue_redraw()
        return
    for id in last_state.units:
        var unit: Dictionary = last_state.units[id]
        var position: Vector2 = map.nodes[unit.node].position
        if int(unit.to) >= 0:
            position = position.lerp(map.nodes[unit.to].position, float(unit.progress))
        current_positions[id] = position
        if not previous_positions.has(id):
            previous_positions[id] = position
    blend = 0.0
    _update_preview()
    queue_redraw()

func _process(delta: float) -> void:
    blend = minf(1.0, blend + delta / SIM.TICK)
    if get_window().has_focus() and not last_state.is_empty():
        var direction: Vector2 = _keyboard_direction()
        var focus: Control = get_viewport().gui_get_focus_owner()
        var editing: bool = focus is LineEdit or focus is TextEdit
        if direction.is_zero_approx() and pointer_inside and not dragging and not editing:
            direction += _edge_direction(get_local_mouse_position())
        var speed: float = PAN_SPEED * (2.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
        if not direction.is_zero_approx():
            _pan_by(-direction.limit_length() * speed * minf(delta, 0.1))
    queue_redraw()

func _keyboard_direction() -> Vector2:
    var focus: Control = get_viewport().gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit:
        return Vector2.ZERO
    return Vector2(
        float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
        float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

func _edge_direction(position: Vector2) -> Vector2:
    if not Rect2(Vector2.ZERO, size).has_point(position):
        return Vector2.ZERO
    return Vector2(
        -1.0 if position.x < EDGE_MARGIN else (1.0 if position.x > size.x - EDGE_MARGIN else 0.0),
        -1.0 if position.y < EDGE_MARGIN else (1.0 if position.y > size.y - EDGE_MARGIN else 0.0))

func _pan_by(offset: Vector2) -> void:
    pan += offset
    fitted = false
    hover = _hit(get_local_mouse_position())
    _update_preview()

func _world(screen: Vector2) -> Vector2:
    return (screen - pan) / zoom

func _screen(world: Vector2) -> Vector2:
    return world * zoom + pan

func _hit(position: Vector2) -> int:
    var map: Dictionary = network.get("map_data")
    if map.is_empty():
        return -1
    var nearest: int = -1
    var distance: float = 16.0
    for node in map.nodes:
        var candidate: float = position.distance_to(_screen(node.position))
        if candidate < distance:
            distance = candidate
            nearest = int(node.id)
    return nearest

func _input_map(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_MIDDLE:
            dragging = event.pressed
            accept_event()
        elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            var anchor: Vector2 = _world(event.position)
            zoom = clampf(zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.04, 2.0)
            pan = event.position - anchor * zoom
            fitted = false
            accept_event()
        elif event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
            var node: int = _hit(event.position)
            if node >= 0:
                if event.button_index == MOUSE_BUTTON_LEFT:
                    selected = node
                    node_selected.emit(node)
                else:
                    network.call("command", "rally", node)
                _update_preview()
            accept_event()
    elif event is InputEventMouseMotion:
        if dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
            _pan_by(event.relative)
        hover = _hit(event.position)
        _update_preview()

func _update_preview() -> void:
    if last_state.is_empty():
        return
    var player: Dictionary = last_state.players.get(multiplayer.get_unique_id(), {})
    if player.is_empty():
        return
    var target: int = hover if hover >= 0 else int(player.rally)
    var origin: int = selected if selected >= 0 else int(player.base)
    var key: String = "%d:%d:%d" % [origin, target, int(last_state.topology)]
    if key == preview_key:
        return
    preview_key = key
    var map: Dictionary = network.get("map_data")
    var table: Dictionary = MAP.routing(map, MAP.adjacency(map, last_state.dynamic), target)
    preview.clear()
    preview.append(origin)
    while origin != target and preview.size() <= map.nodes.size():
        origin = int(table.next[origin])
        if origin < 0:
            preview.clear()
            break
        preview.append(origin)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#142435"))
    if network == null:
        return
    var map: Dictionary = network.get("map_data")
    if map.is_empty() or last_state.is_empty():
        return
    var font: Font = ThemeDB.fallback_font
    draw_circle(_screen(Vector2.ZERO), 310.0 * zoom, Color("#1b2c40"))
    for link in map.edges:
        draw_line(_screen(map.nodes[link.x].position), _screen(map.nodes[link.y].position), Color("#40566e"), 1.3, true)
    for link in last_state.dynamic:
        var closing: bool = not last_state.pending.is_empty() and not last_state.pending.has(link)
        draw_line(_screen(map.nodes[link.x].position), _screen(map.nodes[link.y].position), Color("#ed9865") if closing else Color("#a78bdf"), 2.0, true)
    for link in last_state.pending:
        if not last_state.dynamic.has(link):
            _dashed(_screen(map.nodes[link.x].position), _screen(map.nodes[link.y].position), Color("#6fdbdc"))
    for index in range(preview.size() - 1):
        draw_line(_screen(map.nodes[preview[index]].position), _screen(map.nodes[preview[index + 1]].position), Color("#f6e7a1"), 2.2, true)
    for node in map.nodes:
        var id: int = int(node.id)
        var point: Vector2 = _screen(node.position)
        var kind: String = str(node.kind)
        var radius: float = clampf(19.0 * zoom, 3.0, 20.0)
        if kind in ["base", "objective", "central"]:
            radius += 3.0
        var color: Color = COLORS[clampi(int(last_state.owners[id]), 0, 8)]
        if selected == id or hover == id:
            draw_arc(point, radius + 5.0, 0, TAU, 28, Color("#fff1be"), 2.0, true)
        draw_circle(point, radius + 1.5, Color("#09121e"))
        if kind == "base":
            draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color)
            draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), Color("#e3e9f0"), false, 1.0)
        elif kind in ["objective", "central"]:
            var diamond := PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, 0), point + Vector2(0, radius), point + Vector2(-radius, 0)])
            draw_colored_polygon(diamond, color)
            draw_arc(point, radius + 2, 0, TAU, 20, Color("#ffd57a"), 1.0, true)
        else:
            draw_circle(point, radius, color)
        if float(last_state.capture_progress[id]) > 0:
            var duration: float = SIM.BASE_CAPTURE_TIME if kind == "base" else SIM.CAPTURE_TIME
            draw_arc(point, radius + 4, -PI * 0.5, -PI * 0.5 + TAU * float(last_state.capture_progress[id]) / duration, 24, COLORS[int(last_state.capture_team[id])], 2.5, true)
        if zoom > 0.38 or kind == "base" or selected == id:
            draw_string(font, point + Vector2(radius + 4, -3), str(id + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#d1ddeb"))
    var stacks: Dictionary = {}
    for id in current_positions:
        var unit: Dictionary = last_state.units[id]
        var position: Vector2 = (previous_positions.get(id, current_positions[id]) as Vector2).lerp(current_positions[id], blend)
        var point: Vector2 = _screen(position)
        var offset := Vector2.from_angle(float(int(id) % 17) * 2.4) * (2.0 + float(int(id) % 4) * 1.3) * clampf(zoom, 0.2, 1.0)
        var radius: float = clampf(zoom * 2.6, 0.9, 2.6)
        draw_circle(point + offset, radius, COLORS[int(unit.team)])
        if bool(unit.fighting) and zoom >= 0.4:
            draw_line(point + offset - Vector2(2, 2), point + offset + Vector2(2, 2), Color("#fff5da"), 1.5)
        if int(unit.to) < 0:
            stacks[unit.node] = int(stacks.get(unit.node, 0)) + 1
    for node in stacks:
        if zoom < 0.4 and int(node) not in [selected, hover]:
            continue
        var point: Vector2 = _screen(map.nodes[node].position) + Vector2(8, 18)
        draw_string(font, point, str(stacks[node]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#edf4fc"))
    var player: Dictionary = last_state.players.get(multiplayer.get_unique_id(), {})
    for node in player.get("reserves", {}):
        var target: int = int(player.reserves[node])
        if target <= 0:
            continue
        var point: Vector2 = _screen(map.nodes[node].position)
        var radius: float = clampf(19.0 * zoom, 3.0, 20.0) + 7.0
        draw_arc(point, radius, 0, TAU, 24, Color("#80dfed"), 1.5, true)
        if zoom >= 0.4 or int(node) in [selected, hover]:
            draw_string(font, point + Vector2(8, -12), "HOLD %d" % target, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#80dfed"))
    draw_string(font, Vector2(12, size.y - 12), "■ Base   ◇ Income   Purple: changing routes   Dashed cyan: opening soon", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a9bacd"))

func _dashed(a: Vector2, b: Vector2, color: Color) -> void:
    var length: float = a.distance_to(b)
    var direction: Vector2 = a.direction_to(b)
    var offset: float = 0.0
    while offset < length:
        draw_line(a + direction * offset, a + direction * minf(offset + 5, length), color, 1.5, true)
        offset += 10.0

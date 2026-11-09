extends Control
## Territory prototype UI. All network RPCs and load synchronization live in GameSession.

const RULES = preload("res://scripts/lobby_rules.gd")
const RADIUS: float = 27.0
const TEAM_COLORS := [
    Color("#526374"), Color("#67d4a9"), Color("#f4a46a"),
    Color("#77aafe"), Color("#ce91ed"), Color("#eed16b"),
    Color("#f084a6"), Color("#6bcbd4"), Color("#ed7577")
]

var network: Node
var status_label: Label
var leave_button: Button

func _ready() -> void:
    network = get_node("/root/GameSession")
    network.connect("phase_changed", _refresh_ui)
    network.connect("status_changed", _refresh_ui)
    network.connect("owners_changed", queue_redraw)
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    panel.offset_bottom = 75
    add_child(panel)
    var row := HBoxContainer.new()
    panel.add_child(row)
    leave_button = Button.new()
    leave_button.pressed.connect(_leave)
    row.add_child(leave_button)
    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(status_label)
    _refresh_ui()
    queue_redraw()
    network.call("match_scene_loaded")

func _refresh_ui() -> void:
    if not is_instance_valid(status_label):
        return
    var phase: String = str(network.get("phase"))
    var team: int = int((network.get("players") as Dictionary).get(
        multiplayer.get_unique_id(), {}).get("team", 0))
    if phase == "loading":
        leave_button.text = "CANCEL START" if multiplayer.is_server() else "LEAVE SESSION"
        status_label.text = "Team %d | Loading match — waiting for every player..." % team
    else:
        leave_button.text = "RETURN TO LOBBY" if multiplayer.is_server() else "LEAVE SESSION"
        status_label.text = "Team %d | %s" % [team, str(network.get("status"))]

func _leave() -> void:
    var phase: String = str(network.get("phase"))
    if multiplayer.is_server():
        if phase == "loading":
            network.call("cancel_loading")
        elif phase == "match":
            network.call("return_to_lobby")
    else:
        network.call("leave_session")
        get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _positions() -> Array[Vector2]:
    var result: Array[Vector2] = []
    var outer_radius: float = minf(size.x * 0.39, size.y * 0.32)
    var center := Vector2(size.x * 0.5, size.y * 0.55)
    for ring in range(2):
        var radius: float = outer_radius if ring == 0 else outer_radius * 0.5
        for index in range(8):
            var angle: float = float(index) * TAU / 8.0 - PI * 0.5
            result.append(center + Vector2.from_angle(angle) * radius)
    result.append(center)
    return result

func _unhandled_input(event: InputEvent) -> void:
    if str(network.get("phase")) != "match":
        return
    if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
        return
    var point: Vector2 = get_local_mouse_position()
    var positions: Array[Vector2] = _positions()
    for index in range(positions.size()):
        if point.distance_to(positions[index]) <= RADIUS:
            network.call("request_capture", index)
            get_viewport().set_input_as_handled()
            return

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#14232f"))
    var positions: Array[Vector2] = _positions()
    var line_color := Color("#627c8d")
    for ring in range(2):
        for index in range(8):
            var a: int = ring * 8 + index
            var b: int = ring * 8 + (index + 1) % 8
            draw_line(positions[a], positions[b], line_color, 3.0, true)
    for index in range(8):
        draw_line(positions[index], positions[8 + index], line_color, 3.0, true)
        draw_line(positions[8 + index], positions[16], line_color, 3.0, true)
    var owners: Array[int] = network.get("owners")
    var font: Font = ThemeDB.fallback_font
    for index in range(mini(positions.size(), owners.size())):
        var point: Vector2 = positions[index]
        draw_circle(point, RADIUS + 3.0, Color("#0b1720"))
        draw_circle(point, RADIUS, TEAM_COLORS[clampi(owners[index], 0, 8)])
        draw_string(font, point + Vector2(-20, 6), str(index + 1),
            HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color("#12212a"))
    draw_string(font, Vector2(20, size.y - 22),
        "Each player has a starting territory • Teammates share ownership • Gray is neutral",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#d4e3eb"))

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

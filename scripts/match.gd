extends Control

# Thin vertical slice: the host owns the simulation; clients send capture requests.
const PORT := 24567
const RADIUS := 38.0
const POSITIONS := [
    Vector2(-370, -70), Vector2(-245, -185), Vector2(-135, -45),
    Vector2(0, -145), Vector2(135, -45), Vector2(245, -185),
    Vector2(370, -70)
]
const LINKS := [[0, 1], [0, 2], [1, 2], [1, 3], [2, 3], [2, 4], [3, 4], [3, 5], [4, 5], [4, 6], [5, 6]]
const COLORS := [Color("#526374"), Color("#6cd8ae"), Color("#f5aa70")]
var owners: Array[int] = [1, 0, 0, 0, 0, 0, 2]
var status_label: Label
var address_field: LineEdit
var host_button: Button
var join_button: Button
var my_faction := 0


func _ready() -> void:
    my_faction = 1 if multiplayer.is_server() else 2
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    panel.offset_bottom = 88
    add_child(panel)
    var row := HBoxContainer.new()
    panel.add_child(row)
    var leave := Button.new()
    leave.text = "Leave match"
    leave.pressed.connect(_leave_match)
    row.add_child(leave)
    status_label = Label.new()
    row.add_child(status_label)
    _set_status("Warbound | %s faction | Capture adjacent neutral territories" % ("Green" if my_faction == 1 else "Orange"))
    queue_redraw()

func _leave_match() -> void:
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_peer_disconnected(_id: int) -> void:
    _set_status("Opponent disconnected. Leave match to host again.")

func _on_server_disconnected() -> void:
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

@rpc("authority", "call_remote", "reliable")
func _send_snapshot(new_owners: Array[int]) -> void:
    owners = new_owners.duplicate()
    queue_redraw()

@rpc("any_peer", "call_remote", "reliable")
func _request_capture(index: int) -> void:
    if not multiplayer.is_server():
        return
    var sender := multiplayer.get_remote_sender_id()
    if multiplayer.get_peers().has(sender):
        _apply_capture(2, index)

func _apply_capture(faction: int, index: int) -> void:
    if index < 0 or index >= owners.size() or owners[index] != 0:
        return
    var adjacent := false
    for link in LINKS:
        if link[0] == index and owners[link[1]] == faction:
            adjacent = true
        if link[1] == index and owners[link[0]] == faction:
            adjacent = true
    if not adjacent:
        _set_status("Capture a neutral territory adjacent to your own.")
        return
    owners[index] = faction
    _send_snapshot.rpc(owners)
    _set_status("Territory %d captured by %s" % [index + 1, "Green" if faction == 1 else "Orange"])
    queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
        return
    if my_faction == 0:
        return
    var point := get_local_mouse_position()
    var center := Vector2(size.x * 0.5, size.y * 0.57)
    for index in POSITIONS.size():
        if point.distance_to(center + POSITIONS[index]) <= RADIUS:
            if multiplayer.is_server():
                _apply_capture(1, index)
            else:
                _request_capture.rpc_id(1, index)
            get_viewport().set_input_as_handled()
            return

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#14232f"))
    var center := Vector2(size.x * 0.5, size.y * 0.57)
    for link in LINKS:
        draw_line(center + POSITIONS[link[0]], center + POSITIONS[link[1]], Color("#7991a2"), 5.0, true)
    var font := ThemeDB.fallback_font
    for index in POSITIONS.size():
        var point: Vector2 = center + POSITIONS[index]
        draw_circle(point, RADIUS + 4.0, Color("#0b1720"))
        draw_circle(point, RADIUS, COLORS[owners[index]])
        draw_string(font, point + Vector2(-8, 7), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#101e28"))
    draw_string(font, Vector2(20, size.y - 35), "Green: host    Orange: client    Gray: neutral    Click adjacent gray territories", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#d4e3eb"))

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _set_status(value: String) -> void:
    if status_label != null:
        status_label.text = value

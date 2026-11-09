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
    _make_ui()
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    _set_status("Host a match or join by IP. Steam is not required.")
    queue_redraw()

func _make_ui() -> void:
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    panel.offset_bottom = 92
    add_child(panel)
    var layout := VBoxContainer.new()
    panel.add_child(layout)
    var row := HBoxContainer.new()
    layout.add_child(row)
    host_button = Button.new()
    host_button.text = "Host"
    host_button.pressed.connect(_host)
    row.add_child(host_button)
    address_field = LineEdit.new()
    address_field.placeholder_text = "Host IP"
    address_field.text = "127.0.0.1"
    address_field.custom_minimum_size.x = 190
    row.add_child(address_field)
    join_button = Button.new()
    join_button.text = "Join"
    join_button.pressed.connect(_join)
    row.add_child(join_button)
    status_label = Label.new()
    layout.add_child(status_label)

func _host() -> void:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(PORT, 2)
    if error != OK:
        _set_status("Cannot host. Error code: %d" % error)
        return
    multiplayer.multiplayer_peer = peer
    my_faction = 1
    owners = [1, 0, 0, 0, 0, 0, 2]
    _lock_connection_controls()
    _set_status("Hosting on UDP %d | Green faction | Waiting for opponent" % PORT)
    queue_redraw()

func _join() -> void:
    var peer := ENetMultiplayerPeer.new()
    var ip := address_field.text.strip_edges()
    if ip.is_empty():
        _set_status("Enter the host IP.")
        return
    var error := peer.create_client(ip, PORT)
    if error != OK:
        _set_status("Cannot join. Error code: %d" % error)
        return
    multiplayer.multiplayer_peer = peer
    _lock_connection_controls()
    _set_status("Connecting to %s:%d..." % [ip, PORT])

func _lock_connection_controls() -> void:
    host_button.disabled = true
    join_button.disabled = true
    address_field.editable = false

func _unlock_connection_controls() -> void:
    host_button.disabled = false
    join_button.disabled = false
    address_field.editable = true

func _on_connected() -> void:
    my_faction = 2
    _set_status("Connected | Orange faction | Click a neighboring neutral territory")
    queue_redraw()

func _on_peer_connected(peer_id: int) -> void:
    if multiplayer.is_server():
        _set_status("Player connected | Green faction | Capture adjacent neutral territories")
        _send_snapshot.rpc_id(peer_id, owners)

func _on_peer_disconnected(_peer_id: int) -> void:
    if multiplayer.is_server():
        _set_status("Opponent disconnected | Waiting for another player")

func _on_connection_failed() -> void:
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    my_faction = 0
    _unlock_connection_controls()
    _set_status("Connection failed. Check IP and UDP port %d." % PORT)

func _on_server_disconnected() -> void:
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    my_faction = 0
    _unlock_connection_controls()
    _set_status("Host disconnected.")

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

extends Control

# Thin territory prototype: eight spawn slots, up to eight independently
# assigned teams. The host validates capture requests against the roster.
const RULES = preload("res://scripts/lobby_rules.gd")
const RADIUS: float = 27.0
const TEAM_COLORS := [
    Color("#526374"), # Neutral
    Color("#67d4a9"), # 1
    Color("#f4a46a"), # 2
    Color("#77aafe"), # 3
    Color("#ce91ed"), # 4
    Color("#eed16b"), # 5
    Color("#f084a6"), # 6
    Color("#6bcbd4"), # 7
    Color("#ed7577")  # 8
]

var owners: Array[int] = []
var status_label: Label
var my_team: int = 0

func _ready() -> void:
    var mine: Dictionary = MatchSession.roster.get(multiplayer.get_unique_id(), {})
    my_team = int(mine.get("team", 0))
    owners = RULES.starting_owners(MatchSession.roster)
    multiplayer.peer_connected.connect(_reject_late_join)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    panel.offset_bottom = 78
    add_child(panel)
    var row := HBoxContainer.new()
    panel.add_child(row)
    var leave := Button.new()
    leave.text = "Leave match"
    leave.pressed.connect(_leave_match)
    row.add_child(leave)
    status_label = Label.new()
    row.add_child(status_label)
    _set_status("Warbound | Team %d | %d players | Capture adjacent neutral territories" % [
        my_team, MatchSession.roster.size()
    ])
    queue_redraw()

func _reject_late_join(id: int) -> void:
    if multiplayer.is_server():
        var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
        if peer != null:
            peer.disconnect_peer(id)

func _leave_match() -> void:
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    MatchSession.clear_roster()
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_peer_disconnected(id: int) -> void:
    if multiplayer.is_server():
        _set_status("Player %d disconnected. Existing territory remains." % id)

func _on_server_disconnected() -> void:
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    MatchSession.clear_roster()
    get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

@rpc("authority", "call_remote", "reliable")
func _send_snapshot(new_owners: Array[int]) -> void:
    if new_owners.size() != RULES.MAP_NODE_COUNT:
        return
    owners = new_owners.duplicate()
    queue_redraw()

@rpc("any_peer", "call_remote", "reliable")
func _request_capture(index: int) -> void:
    if not multiplayer.is_server():
        return
    var sender: int = multiplayer.get_remote_sender_id()
    if not multiplayer.get_peers().has(sender):
        return
    var data: Dictionary = MatchSession.roster.get(sender, {})
    var team: int = int(data.get("team", 0))
    if RULES.valid_team(team):
        _apply_capture(team, index)

func _linked(a: int, b: int) -> bool:
    if a == 16:
        return b >= 8 and b < 16
    if b == 16:
        return a >= 8 and a < 16
    if a < 8 and b >= 8:
        return a == b - 8
    if b < 8 and a >= 8:
        return b == a - 8
    if a / 8 != b / 8:
        return false
    return (a + 1) % 8 == b % 8 or (b + 1) % 8 == a % 8

func _apply_capture(team: int, index: int) -> void:
    if not RULES.valid_team(team) or index < 0 or index >= owners.size() or owners[index] != 0:
        return
    var adjacent: bool = false
    for other in range(owners.size()):
        if owners[other] == team and _linked(index, other):
            adjacent = true
            break
    if not adjacent:
        _set_status("Capture a neutral territory adjacent to your team's territory.")
        return
    owners[index] = team
    _send_snapshot.rpc(owners)
    _set_status("Territory %d captured by Team %d" % [index + 1, team])
    queue_redraw()

func _positions() -> Array[Vector2]:
    var result: Array[Vector2] = []
    var outer_radius: float = minf(size.x * 0.39, size.y * 0.32)
    var center := Vector2(size.x * 0.50, size.y * 0.55)
    for ring in range(2):
        var ring_radius: float = outer_radius if ring == 0 else outer_radius * 0.50
        for index in range(8):
            var angle: float = float(index) * TAU / 8.0 - PI * 0.5
            result.append(center + Vector2.from_angle(angle) * ring_radius)
    result.append(center)
    return result

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
        return
    if not RULES.valid_team(my_team):
        return
    var point: Vector2 = get_local_mouse_position()
    var positions: Array[Vector2] = _positions()
    for index in range(positions.size()):
        if point.distance_to(positions[index]) <= RADIUS:
            if multiplayer.is_server():
                _apply_capture(my_team, index)
            else:
                _request_capture.rpc_id(1, index)
            get_viewport().set_input_as_handled()
            return

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#14232f"))
    var positions: Array[Vector2] = _positions()
    var link_color := Color("#627c8d")
    for ring in range(2):
        for index in range(8):
            var a: int = ring * 8 + index
            var b: int = ring * 8 + (index + 1) % 8
            draw_line(positions[a], positions[b], link_color, 3.0, true)
    for index in range(8):
        draw_line(positions[index], positions[8 + index], link_color, 3.0, true)
        draw_line(positions[8 + index], positions[16], link_color, 3.0, true)
    var font: Font = ThemeDB.fallback_font
    for index in range(mini(positions.size(), owners.size())):
        var point: Vector2 = positions[index]
        var team: int = owners[index]
        draw_circle(point, RADIUS + 3.0, Color("#0b1720"))
        draw_circle(point, RADIUS, TEAM_COLORS[clampi(team, 0, 8)])
        draw_string(font, point + Vector2(-20, 6), str(index + 1),
            HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color("#12212a"))
    draw_string(font, Vector2(20, size.y - 22),
        "Team colors match lobby assignments  •  Gray = neutral  •  Click adjacent nodes",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#d4e3eb"))

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _set_status(value: String) -> void:
    if status_label != null:
        status_label.text = value

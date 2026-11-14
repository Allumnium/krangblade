extends Control
## Shared solo/multiplayer economy sandbox: click neutral neighbors to claim,
## then select a friendly territory to choose its building.

const RULES = preload("res://scripts/lobby_rules.gd")
const ECONOMY = preload("res://scripts/economy_rules.gd")
const RADIUS: float = 25.0
const TEAM_COLORS = [
    Color("#526374"), Color("#67d4a9"), Color("#f4a46a"),
    Color("#77aafe"), Color("#ce91ed"), Color("#eed16b"),
    Color("#f084a6"), Color("#6bcbd4"), Color("#ed7577")
]
const IRON_COLOR := Color("#b5c9d6")
const COPPER_COLOR := Color("#e5a46f")

var network: Node
var status_label: Label
var leave_button: Button
var summary_label: Label
var selection_label: Label
var mine_button: Button
var smelter_button: Button
var factory_button: Button
var clear_button: Button
var selected_index: int = -1

func _ready() -> void:
    network = get_node("/root/GameSession")
    network.connect("phase_changed", _refresh_ui)
    network.connect("status_changed", _refresh_ui)
    network.connect("owners_changed", _refresh_economy)
    network.connect("economy_changed", _refresh_economy)
    _create_ui()
    _refresh_ui()
    _refresh_economy()
    network.call("match_scene_loaded")

func _create_ui() -> void:
    var header := PanelContainer.new()
    header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    header.offset_bottom = 76
    add_child(header)
    var header_row := HBoxContainer.new()
    header.add_child(header_row)
    leave_button = Button.new()
    leave_button.custom_minimum_size.x = 158
    leave_button.pressed.connect(_leave)
    header_row.add_child(leave_button)
    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header_row.add_child(status_label)

    var sidebar := PanelContainer.new()
    add_child(sidebar)
    sidebar.anchor_left = 1.0
    sidebar.anchor_right = 1.0
    sidebar.anchor_top = 0.0
    sidebar.anchor_bottom = 1.0
    sidebar.offset_left = -300
    sidebar.offset_right = -8
    sidebar.offset_top = 84
    sidebar.offset_bottom = -12
    var margins := MarginContainer.new()
    for edge in ["left", "right", "top", "bottom"]:
        margins.add_theme_constant_override("margin_" + edge, 12)
    sidebar.add_child(margins)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 10)
    margins.add_child(body)
    body.add_child(_label("ECONOMY NETWORK", 19))
    body.add_child(_label("Connected friendly territories transport goods at up to 3 units per edge per second.", 12))
    summary_label = _label("", 14)
    body.add_child(summary_label)
    body.add_child(HSeparator.new())
    body.add_child(_label("SELECTED TERRITORY", 18))
    selection_label = _label("", 14)
    body.add_child(selection_label)
    mine_button = _build_button("BUILD MINE  •  2 raw/s", "mine", body)
    smelter_button = _build_button("BUILD SMELTER  •  2 iron → 1 steel", "smelter", body)
    factory_button = _build_button("BUILD FACTORY  •  steel + copper → supplies", "factory", body)
    clear_button = _build_button("CLEAR BUILDING", "", body)
    body.add_spacer(false)
    body.add_child(_label("Click a gray territory adjacent to your team to capture it. Click an owned territory to build. Goods route automatically to consumers and supplies return to HQ.", 12))

func _label(value: String, font_size: int) -> Label:
    var result := Label.new()
    result.text = value
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.add_theme_font_size_override("font_size", font_size)
    return result

func _build_button(title: String, kind: String, container: VBoxContainer) -> Button:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size.y = 35
    button.pressed.connect(_build.bind(kind))
    container.add_child(button)
    return button

func _my_team() -> int:
    if bool(network.get("is_solo")):
        return 1
    var roster: Dictionary = network.get("players")
    var mine: Dictionary = roster.get(multiplayer.get_unique_id(), {})
    return int(mine.get("team", 0))

func _refresh_ui() -> void:
    if not is_instance_valid(status_label):
        return
    var phase: String = str(network.get("phase"))
    var team: int = _my_team()
    if phase == "loading":
        leave_button.text = "CANCEL START" if multiplayer.is_server() else "LEAVE SESSION"
        status_label.text = "Team %d | Loading match — waiting for every player..." % team
    else:
        leave_button.text = "RETURN TO MENU" if bool(network.get("is_solo"))             else ("RETURN TO LOBBY" if multiplayer.is_server() else "LEAVE SESSION")
        status_label.text = "Team %d | %s" % [team, str(network.get("status"))]

func _refresh_economy() -> void:
    queue_redraw()
    if not is_instance_valid(summary_label):
        return
    var owners: Array[int] = network.get("owners")
    var buildings: Array[String] = network.get("buildings")
    var stocks: Array[Dictionary] = network.get("stocks")
    var team: int = _my_team()
    var total: Dictionary = ECONOMY.total_for_team(owners, stocks, team)
    summary_label.text = "TEAM %d  •  STOCK ON NETWORK\nIron: %d    Copper: %d\nSteel: %d    Supplies: %d" % [
        team, int(total["iron"]), int(total["copper"]),
        int(total["steel"]), int(total["supplies"])]
    if selected_index < 0 or selected_index >= owners.size()             or selected_index >= buildings.size() or selected_index >= stocks.size():
        selection_label.text = "Select a node on the map."
    else:
        var owner: int = owners[selected_index]
        var d: String = ECONOMY.deposit(selected_index)
        var building: String = buildings[selected_index]
        var stock: Dictionary = stocks[selected_index]
        var owner_text: String = "Neutral" if owner == 0 else "Team %d" % owner
        selection_label.text = "NODE %d  •  %s\nDeposit: %s\nBuilding: %s\n\nLocal inventory\nIron: %d    Copper: %d\nSteel: %d    Supplies: %d" % [
            selected_index + 1, owner_text,
            d.capitalize() if not d.is_empty() else "None",
            building.capitalize() if not building.is_empty() else "Empty",
            int(stock.get("iron", 0)), int(stock.get("copper", 0)),
            int(stock.get("steel", 0)), int(stock.get("supplies", 0))]
    mine_button.disabled = not ECONOMY.can_build(owners, buildings, team, selected_index, "mine")
    smelter_button.disabled = not ECONOMY.can_build(owners, buildings, team, selected_index, "smelter")
    factory_button.disabled = not ECONOMY.can_build(owners, buildings, team, selected_index, "factory")
    clear_button.disabled = not ECONOMY.can_build(owners, buildings, team, selected_index, "")

func _build(kind: String) -> void:
    if selected_index >= 0:
        network.call("request_build", selected_index, kind)

func _leave() -> void:
    var phase: String = str(network.get("phase"))
    if bool(network.get("is_solo")):
        network.call("leave_solo")
    elif multiplayer.is_server():
        if phase == "loading":
            network.call("cancel_loading")
        elif phase == "match":
            network.call("return_to_lobby")
    else:
        network.call("leave_session")
        get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _positions() -> Array[Vector2]:
    var result: Array[Vector2] = []
    var map_width: float = maxf(300.0, size.x - 310.0)
    var outer_radius: float = minf(map_width * 0.39, size.y * 0.31)
    var center := Vector2(map_width * 0.5, size.y * 0.55)
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
            selected_index = index
            var owners: Array[int] = network.get("owners")
            if owners.size() == RULES.MAP_NODE_COUNT and owners[index] == 0:
                network.call("request_capture", index)
            _refresh_economy()
            get_viewport().set_input_as_handled()
            return

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#14232f"))
    if network == null:
        return
    var positions: Array[Vector2] = _positions()
    var owners: Array[int] = network.get("owners")
    var buildings: Array[String] = network.get("buildings")
    for a in range(RULES.MAP_NODE_COUNT):
        for b in range(a + 1, RULES.MAP_NODE_COUNT):
            if not RULES.linked(a, b):
                continue
            draw_line(positions[a], positions[b], Color("#415565"), 3.0, true)
            if owners.size() == RULES.MAP_NODE_COUNT and owners[a] > 0                     and owners[a] == owners[b]:
                draw_line(positions[a], positions[b],
                    TEAM_COLORS[clampi(owners[a], 0, 8)].darkened(0.24), 5.0, true)
    var font: Font = ThemeDB.fallback_font
    for index in range(RULES.MAP_NODE_COUNT):
        var point: Vector2 = positions[index]
        var raw: String = ECONOMY.deposit(index)
        var outline: Color = IRON_COLOR if raw == "iron" else (
            COPPER_COLOR if raw == "copper" else Color("#78899a"))
        if buildings.size() == RULES.MAP_NODE_COUNT and buildings[index] == "hq":
            outline = Color("#f4dc77")
        draw_circle(point, RADIUS + 4.0, outline)
        draw_circle(point, RADIUS, TEAM_COLORS[clampi(
            owners[index] if owners.size() == RULES.MAP_NODE_COUNT else 0, 0, 8)])
        if index == selected_index:
            draw_arc(point, RADIUS + 9.0, 0.0, TAU, 48, Color.WHITE, 2.5, true)
        draw_string(font, point + Vector2(-17, 6), str(index + 1),
            HORIZONTAL_ALIGNMENT_CENTER, 34, 16, Color("#101e2a"))
        var marker: String = ""
        if buildings.size() == RULES.MAP_NODE_COUNT:
            match buildings[index]:
                "hq": marker = "HQ"
                "mine": marker = "M"
                "smelter": marker = "S"
                "factory": marker = "F"
        if not marker.is_empty():
            draw_string(font, point + Vector2(-16, RADIUS + 17), marker,
                HORIZONTAL_ALIGNMENT_CENTER, 32, 13, Color("#eaf3f8"))
    draw_string(font, Vector2(16, size.y - 20),
        "Silver rim: Iron   •   Orange rim: Copper   •   M: Mine   S: Smelter   F: Factory",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#d4e3eb"))

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

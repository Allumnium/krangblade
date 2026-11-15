extends Control
## Planet map and inspector. Host/solo session owns all simulation mutations.
const MAP = preload("res://scripts/planet_map.gd")
const ECONOMY = preload("res://scripts/economy_rules.gd")
const COLORS = [Color("#607286"), Color("#67d4a9"), Color("#f4a46a"), Color("#77aafe"),
    Color("#ce91ed"), Color("#eed16b"), Color("#f084a6"), Color("#6bcbd4"), Color("#ed7577")]
const PANEL_WIDTH: float = 380.0
const RADIUS: float = 17.0

var session: Node
var selected: int = -1
var heading: Label
var info: Label
var fleet: Label
var resource_picker: OptionButton
var resource_detail: Label
var min_stock: SpinBox
var max_stock: SpinBox
var threshold_button: Button
var upgrade_resource: Button
var ship_button: Button
var yard_button: Button
var yard_picker: OptionButton
var yard_info: Label
var upgrade_yard: Button
var jobs: ItemList
var cancel_button: Button
var leave: Button
var last_job_text: String = ""
var last_yard_text: String = ""

func _ready() -> void:
    session = get_node("/root/GameSession")
    session.connect("phase_changed", _refresh)
    session.connect("status_changed", _refresh)
    session.connect("economy_changed", _refresh)
    _build_ui()
    _refresh()
    session.call("match_scene_loaded")

func _label(value: String, font_size: int = 14) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    return label

func _button(text: String, action: Callable, parent: Container) -> Button:
    var b := Button.new()
    b.text = text
    b.pressed.connect(action)
    b.custom_minimum_size.y = 32
    parent.add_child(b)
    return b

func _build_ui() -> void:
    var header := PanelContainer.new()
    add_child(header)
    header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    header.offset_bottom = 54
    var row := HBoxContainer.new()
    header.add_child(row)
    leave = _button("RETURN", _leave, row)
    heading = _label("WARBOUND / EMPIRE", 16)
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(heading)
    var panel := PanelContainer.new()
    add_child(panel)
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.anchor_bottom = 1.0
    panel.offset_left = -PANEL_WIDTH
    panel.offset_right = -8
    panel.offset_top = 62
    panel.offset_bottom = -8
    var scroll := ScrollContainer.new()
    panel.add_child(scroll)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 10)
    scroll.add_child(margin)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 6)
    margin.add_child(body)
    fleet = _label("", 14)
    body.add_child(fleet)
    info = _label("", 15)
    body.add_child(info)
    body.add_child(HSeparator.new())
    body.add_child(_label("RESOURCE MANAGEMENT", 16))
    resource_picker = OptionButton.new()
    for resource in ECONOMY.RESOURCES:
        resource_picker.add_item(resource)
    resource_picker.item_selected.connect(func(_i: int) -> void: _load_thresholds(); _refresh())
    body.add_child(resource_picker)
    resource_detail = _label("")
    body.add_child(resource_detail)
    var thresholds := HBoxContainer.new()
    body.add_child(thresholds)
    for i in range(2):
        var col := VBoxContainer.new()
        col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        thresholds.add_child(col)
        col.add_child(_label("Import below" if i == 0 else "Export above", 12))
        var spin := SpinBox.new()
        spin.max_value = 1000000
        spin.step = 1
        spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        col.add_child(spin)
        if i == 0:
            min_stock = spin
        else:
            max_stock = spin
    threshold_button = _button("APPLY THRESHOLDS", _apply_thresholds, body)
    upgrade_resource = _button("QUEUE PRODUCTION UPGRADE", func() -> void: _operation("production", _resource()), body)
    body.add_child(HSeparator.new())
    body.add_child(_label("SHIPYARDS", 16))
    yard_picker = OptionButton.new()
    yard_picker.item_selected.connect(func(_i: int) -> void: _refresh())
    body.add_child(yard_picker)
    yard_info = _label("")
    body.add_child(yard_info)
    ship_button = _button("QUEUE LOGISTICS SHIP", func() -> void: _operation("ship"), body)
    yard_button = _button("QUEUE NEW SHIPYARD", func() -> void: _operation("yard"), body)
    upgrade_yard = _button("QUEUE SHIPYARD UPGRADE", func() -> void: _operation("yard_upgrade", str(yard_picker.selected)), body)
    body.add_child(HSeparator.new())
    body.add_child(_label("CONSTRUCTION QUEUE", 16))
    jobs = ItemList.new()
    jobs.custom_minimum_size.y = 130
    jobs.item_selected.connect(func(_i: int) -> void: _refresh())
    body.add_child(jobs)
    cancel_button = _button("CANCEL SELECTED / REFUND", _cancel, body)
    body.add_child(_label("Development values only. Click an adjacent neutral planet to claim it. Cargo ships automatically serve friendly planets.", 12))

func _state() -> Dictionary:
    return session.get("economy")

func _planet() -> Dictionary:
    var planets: Array = _state().get("planets", [])
    if selected < 0 or selected >= planets.size():
        return {}
    return planets[selected]

func _me() -> int:
    return 1 if bool(session.get("is_solo")) else multiplayer.get_unique_id()

func _resource() -> String:
    return resource_picker.get_item_text(resource_picker.selected)

func _load_thresholds() -> void:
    var p: Dictionary = _planet()
    if p.is_empty():
        return
    var t: Dictionary = p["thresholds"][_resource()]
    min_stock.value = float(t["min"])
    max_stock.value = float(t["max"])

func _apply_thresholds() -> void:
    if min_stock.value > max_stock.value:
        max_stock.value = min_stock.value
    session.call("request_thresholds", selected, _resource(), min_stock.value, max_stock.value)

func _operation(kind: String, target: String = "") -> void:
    session.call("request_operation", selected, kind, target)

func _cancel() -> void:
    var selection: PackedInt32Array = jobs.get_selected_items()
    if not selection.is_empty():
        session.call("request_cancel", selected, int(jobs.get_item_metadata(selection[0])))

func _refresh() -> void:
    queue_redraw()
    if not is_instance_valid(heading):
        return
    var state: Dictionary = _state()
    var phase: String = str(session.get("phase"))
    heading.text = "EMPIRE  /  " + str(session.get("status"))
    leave.text = "MENU" if bool(session.get("is_solo")) else ("RETURN TO LOBBY" if multiplayer.is_server() else "LEAVE")
    if phase == "loading":
        leave.text = "CANCEL START" if multiplayer.is_server() else "LEAVE"
    var count: int = 0
    var moving: int = 0
    for ship in state.get("ships", []):
        if int(ship["owner"]) == _me():
            count += 1
            if not (ship["route"] as Array).is_empty():
                moving += 1
    fleet.text = "LOGISTICS FLEET   %d ships  /  %d traveling" % [count, moving]
    var planets: Array = state.get("planets", [])
    if selected < 0 and not planets.is_empty():
        for i in range(planets.size()):
            if int(planets[i]["owner"]) == _me():
                selected = i
                _load_thresholds()
                break
    var p: Dictionary = _planet()
    var owned: bool = not p.is_empty() and int(p["owner"]) == _me() and phase == "match"
    threshold_button.disabled = not owned
    upgrade_resource.disabled = true
    ship_button.disabled = true
    yard_button.disabled = not owned
    upgrade_yard.disabled = true
    cancel_button.disabled = true
    if p.is_empty():
        info.text = "Select a planet."
        resource_detail.text = ""
        yard_info.text = ""
        jobs.clear()
        return
    var owner: int = int(p["owner"])
    var roster: Dictionary = session.get("players")
    var name_text: String = "Neutral" if owner == 0 else str(roster.get(owner, {}).get("name", "Player"))
    info.text = "PLANET %02d%s  •  %s\n" % [selected + 1, " / HOME" if bool(p["home"]) else "", name_text]
    for r in ECONOMY.RESOURCES:
        info.text += "%s  %.1f   |  Lv %d\n" % [r, float(p["stock"][r]), int(p["levels"][r])]
    var resource: String = _resource()
    var available: bool = ECONOMY.EXTRACTED.has(resource) and float(p["abundance"].get(resource, 0.0)) > 0.0
    var modifier: float = float(p["bonuses"].get(resource, 1.0))
    var detail: String = "Production rules not defined yet."
    if ECONOMY.EXTRACTED.has(resource):
        detail = "Deposit: %.2fx  •  Output: %.1f/s" % [float(p["abundance"].get(resource, 0.0)), ECONOMY.rate(p, resource)]
    var t: Dictionary = p["thresholds"][resource]
    resource_detail.text = "%s\nPlanet bonus: %.2fx  |  Current min/max: %.0f / %.0f" % [detail, modifier, float(t["min"]), float(t["max"])]
    upgrade_resource.disabled = not owned or not available or ECONOMY._has_job(p, "production", resource)
    ship_button.disabled = not owned or not bool(p["home"])
    var yards: Array = p["yards"]
    var yard_text: String = str(yards.size())
    for y in yards:
        yard_text += ":" + str(y["level"])
    if yard_text != last_yard_text:
        var previous: int = yard_picker.selected
        yard_picker.clear()
        for i in range(yards.size()):
            yard_picker.add_item("Shipyard %d / Level %d" % [i + 1, int(yards[i]["level"])])
        if not yards.is_empty():
            yard_picker.select(clampi(previous, 0, yards.size() - 1))
        last_yard_text = yard_text
    var y_index: int = yard_picker.selected
    if y_index >= 0 and y_index < yards.size():
        var y: Dictionary = yards[y_index]
        var upgrading: bool = ECONOMY._has_job(p, "yard_upgrade", str(y_index))
        yard_info.text = "Work/s: %.1f  •  Max size: %d  •  %s" % [ECONOMY.yard_speed(int(y["level"])), ECONOMY.max_size(int(y["level"])), "Upgrading" if upgrading else ("Idle" if int(y["job"]) < 0 else "Building")]
        upgrade_yard.disabled = not owned or upgrading
    else:
        yard_info.text = "No shipyards"
    var selected_job: int = -1
    var old: PackedInt32Array = jobs.get_selected_items()
    if not old.is_empty():
        selected_job = int(jobs.get_item_metadata(old[0]))
    var job_text: String = str(selected) + str(p["queue"])
    if job_text != last_job_text:
        jobs.clear()
        for item in p["queue"]:
            var name_value: String = str(item["kind"]).replace("_", " ").capitalize()
            var line: String = "%s %s — %.0f%%" % [name_value, str(item["target"]), 100.0 * float(item["progress"]) / float(item["work"])]
            if ECONOMY._possible(p, item) <= ECONOMY.EPS:
                line += " (waiting for materials)"
            jobs.add_item(line)
            var i: int = jobs.item_count - 1
            jobs.set_item_metadata(i, int(item["id"]))
            if int(item["id"]) == selected_job:
                jobs.select(i)
        last_job_text = job_text
    cancel_button.disabled = not owned or jobs.get_selected_items().is_empty()

func _leave() -> void:
    if bool(session.get("is_solo")):
        session.call("leave_solo")
    elif multiplayer.is_server():
        if str(session.get("phase")) == "loading":
            session.call("cancel_loading")
        else:
            session.call("return_to_lobby")
    else:
        session.call("leave_session")
        get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _screen_point(point: Vector2) -> Vector2:
    var area := Vector2(maxf(100.0, size.x - PANEL_WIDTH - 24), maxf(100.0, size.y - 90))
    var factor: float = minf(area.x / MAP.SIZE.x, area.y / MAP.SIZE.y)
    return Vector2(12, 62) + (area - MAP.SIZE * factor) * 0.5 + point * factor

func _unhandled_input(event: InputEvent) -> void:
    if str(session.get("phase")) != "match" or not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
        return
    var state: Dictionary = _state()
    if state.is_empty():
        return
    var points: Array = state["map"]["points"]
    for i in range(points.size()):
        if get_local_mouse_position().distance_to(_screen_point(points[i])) <= RADIUS + 5:
            selected = i
            _load_thresholds()
            if int(state["planets"][i]["owner"]) == 0:
                session.call("request_capture", i)
            _refresh()
            get_viewport().set_input_as_handled()
            return

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#0b141e"))
    if session == null:
        return
    var state: Dictionary = _state()
    if state.is_empty():
        return
    var points: Array = state["map"]["points"]
    var teams: Array[int] = ECONOMY.planet_teams(state)
    for edge in state["map"]["edges"]:
        var a: int = int(edge[0])
        var b: int = int(edge[1])
        var color: Color = COLORS[teams[a]].darkened(0.3) if teams[a] > 0 and teams[a] == teams[b] else Color("#40566b")
        draw_line(_screen_point(points[a]), _screen_point(points[b]), color, 2.0, true)
    var font: Font = ThemeDB.fallback_font
    for i in range(points.size()):
        var pos: Vector2 = _screen_point(points[i])
        var radius: float = RADIUS + (3.0 if bool(state["planets"][i]["home"]) else 0.0)
        draw_circle(pos, radius + 2, Color("#c5d9e8") if i == selected else Color("#253748"))
        draw_circle(pos, radius, COLORS[teams[i]])
        draw_string(font, pos + Vector2(-18, 5), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 36, 14, Color("#09131e"))
    for ship in state["ships"]:
        var at: int = int(ship["at"])
        var pos: Vector2 = points[at]
        var route: Array = ship["route"]
        if not route.is_empty():
            var next: Vector2 = points[int(route[0])]
            var factor: float = clampf(float(ship["leg"]) / maxf(1.0, pos.distance_to(next)), 0.0, 1.0)
            pos = pos.lerp(next, factor)
        var team: int = int(state["teams"].get(int(ship["owner"]), 0))
        var point: Vector2 = _screen_point(pos) + Vector2(0, -5)
        draw_circle(point, 5, Color("#09131e"))
        draw_circle(point, 3.5, COLORS[team].lightened(0.2))
    draw_string(font, Vector2(12, size.y - 12), "Fixed routes · Neutral planets in gray · Cargo ships are moving dots", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b6c4d2"))

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

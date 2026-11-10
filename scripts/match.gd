extends Control
## Responsive match HUD. The battlefield owns drawing, selection, and camera.
const SIM = preload("res://scripts/match_simulation.gd")
const FIELD = preload("res://scripts/battlefield.gd")
var network: Node
var battlefield: Control
var selected: int = -1
var metrics: Label
var status_label: Label
var selection_label: Label
var objectives_label: Label
var buy_one: Button
var buy_five: Button
var auto_box: CheckBox
var base_button: Button
var rally_button: Button
var retreat_button: Button
var reserve_button: Button
var reserve_edit: SpinBox
var reserve_help: Label
var reserve_timer: Timer
var pending_reserve_node: int = -1
var pending_reserve_count: int = 0
var reserve_targets: Dictionary = {}
var leave_button: Button
var result_label: Label

func _ready() -> void:
    network = get_node("/root/GameSession")
    var background := ColorRect.new()
    background.color = Color("#101c29")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for edge in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + edge, 12)
    add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    margin.add_child(column)
    var header := HFlowContainer.new()
    column.add_child(header)
    var title := Label.new()
    title.text = "WARBOUND / FRONTLINES"
    title.add_theme_font_size_override("font_size", 22)
    header.add_child(title)
    leave_button = _button("RETURN TO LOBBY", _leave)
    header.add_child(leave_button)
    header.add_child(_button("FIT MAP", func() -> void: battlefield.call("fit_map")))
    header.add_child(get_node("/root/WindowControls").call("make_button"))
    metrics = _label(column, 17)
    status_label = _label(column, 13)
    result_label = _label(column, 24)
    result_label.add_theme_color_override("font_color", Color("#ffd57a"))
    battlefield = FIELD.new()
    battlefield.size_flags_vertical = Control.SIZE_EXPAND_FILL
    battlefield.custom_minimum_size = Vector2(0, 180)
    battlefield.connect("node_selected", _select)
    column.add_child(battlefield)
    var help := _label(column, 12)
    help.text = "Left-click: inspect  |  Right-click: rally  |  Wheel: zoom  |  WASD / edges / middle-drag: pan  |  Shift: faster"
    help.add_theme_color_override("font_color", Color("#9bafc5"))
    var controls_scroll := ScrollContainer.new()
    controls_scroll.custom_minimum_size.y = 188
    controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(controls_scroll)
    var controls := VBoxContainer.new()
    controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    controls_scroll.add_child(controls)
    selection_label = _label(controls, 14)
    var actions := HFlowContainer.new()
    actions.add_theme_constant_override("h_separation", 8)
    actions.add_theme_constant_override("v_separation", 6)
    controls.add_child(actions)
    buy_one = _button("BUY 1 · 20", func() -> void: _order("recruit", 1))
    buy_five = _button("BUY 5 · 100", func() -> void: _order("recruit", 5))
    actions.add_child(buy_one)
    actions.add_child(buy_five)
    auto_box = CheckBox.new()
    auto_box.text = "AUTO-RECRUIT"
    auto_box.toggled.connect(func(enabled: bool) -> void: _order("auto", 1 if enabled else 0))
    actions.add_child(auto_box)
    base_button = _button("RECRUIT HERE", func() -> void: _order("base", selected))
    actions.add_child(base_button)
    rally_button = _button("RALLY HERE", func() -> void: _order("rally", selected))
    actions.add_child(rally_button)
    retreat_button = _button("RETREAT HERE", func() -> void: _order("retreat", selected))
    actions.add_child(retreat_button)
    var reserves := HFlowContainer.new()
    controls.add_child(reserves)
    var reserve_title := Label.new()
    reserve_title.text = "Entrench troops here: "
    reserves.add_child(reserve_title)
    reserve_edit = SpinBox.new()
    reserve_edit.min_value = 0
    reserve_edit.max_value = SIM.UNIT_CAP
    reserve_edit.step = 1
    reserve_edit.custom_minimum_size.x = 90
    reserve_edit.update_on_text_changed = true
    reserve_edit.tooltip_text = "Keep this many of your troops at this node. Extra troops pass through. Set 0 to release them. Orders also apply after capturing a node; retreat overrides them."
    reserves.add_child(reserve_edit)
    reserve_timer = Timer.new()
    reserve_timer.one_shot = true
    reserve_timer.wait_time = 0.3
    reserve_timer.timeout.connect(_commit_reserve)
    add_child(reserve_timer)
    reserve_edit.value_changed.connect(_reserve_changed)
    reserve_edit.get_line_edit().text_submitted.connect(func(_text: String) -> void: _submit_reserve())
    reserve_button = _button("ENTRENCH", _submit_reserve)
    reserves.add_child(reserve_button)
    reserve_help = _label(controls, 13)
    objectives_label = _label(controls, 13)
    network.connect("state_changed", _refresh)
    network.connect("phase_changed", _refresh)
    network.connect("status_changed", _refresh)
    _refresh()
    network.call("match_scene_loaded")

func _button(text_value: String, handler: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size.y = 34
    button.pressed.connect(handler)
    return button

func _label(parent: Node, font_size: int) -> Label:
    var label := Label.new()
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    parent.add_child(label)
    return label

func _order(action: String, value: int = 0, extra: int = 0) -> void:
    network.call("command", action, value, extra)

func _select(node: int) -> void:
    _commit_reserve()
    selected = node
    var state: Dictionary = network.get("match_state")
    var map: Dictionary = network.get("map_data")
    var player: Dictionary = state.get("players", {}).get(multiplayer.get_unique_id(), {})
    if not player.is_empty():
        var kind: String = str(map.nodes[node].kind)
        var fallback: int = 2 if kind == "base" else (1 if kind in ["objective", "central"] else 0)
        reserve_edit.set_value_no_signal(float(reserve_targets.get(node, player.reserves.get(node, fallback))))
    _refresh()

func _reserve_changed(value: float) -> void:
    if selected < 0 or not reserve_edit.editable:
        return
    pending_reserve_node = selected
    pending_reserve_count = int(value)
    reserve_targets[selected] = int(value)
    reserve_timer.start()
    _refresh()

func _submit_reserve() -> void:
    if selected < 0 or not reserve_edit.editable:
        return
    reserve_edit.apply()
    _reserve_changed(reserve_edit.value)
    _commit_reserve()

func _commit_reserve() -> void:
    if reserve_timer == null or pending_reserve_node < 0:
        return
    reserve_timer.stop()
    _order("reserve", pending_reserve_node, pending_reserve_count)
    pending_reserve_node = -1

func _refresh() -> void:
    var phase: String = str(network.get("phase"))
    leave_button.text = "CANCEL START" if phase == "loading" else "RETURN TO LOBBY"
    if not multiplayer.is_server():
        leave_button.text = "LEAVE SESSION"
    var state: Dictionary = network.get("match_state")
    var map: Dictionary = network.get("map_data")
    var player: Dictionary = state.get("players", {}).get(multiplayer.get_unique_id(), {})
    var active: bool = phase == "match" and not player.is_empty() and not bool(player.get("eliminated", true)) and str(state.get("result", "")).is_empty()
    var one_reason: String = _purchase_reason(player, state, map, 1) if active else "Waiting or spectating."
    var five_reason: String = _purchase_reason(player, state, map, 5) if active else one_reason
    buy_one.disabled = not one_reason.is_empty()
    buy_one.tooltip_text = one_reason
    buy_five.disabled = not five_reason.is_empty()
    buy_five.tooltip_text = five_reason
    auto_box.disabled = not active
    auto_box.set_pressed_no_signal(bool(player.get("auto", false)))
    var friendly: bool = selected >= 0 and not state.is_empty() and int(state.owners[selected]) == int(player.get("team", -1))
    base_button.disabled = not active or not friendly or map.nodes[selected].kind != "base" or bool(state.contested[selected])
    rally_button.disabled = not active or selected < 0
    retreat_button.disabled = not active or not friendly
    reserve_button.disabled = not active or selected < 0
    reserve_edit.editable = active and selected >= 0
    result_label.text = str(state.get("result", ""))
    if bool(player.get("eliminated", false)) and result_label.text.is_empty():
        result_label.text = "Your team has been eliminated · Watching the battle"
    result_label.visible = not result_label.text.is_empty()
    if player.is_empty():
        metrics.text = "Loading battlefield — waiting for every player…"
        status_label.text = str(network.get("status"))
        selection_label.text = "The match starts when everyone has loaded."
        return
    metrics.text = "TEAM %d   |   %.1f credits   |   +%.2f/s (base %.0f + objectives %.2f)   |   %d/%d troops   |   Refunds %.1f" % [int(player.team), float(player.credits), float(player.income), SIM.BASE_INCOME if not bool(player.eliminated) else 0.0, float(player.objective_income), int(player.count), SIM.UNIT_CAP, float(player.refunds)]
    var remaining: float = maxf(0.0, float(int(state.shift_at) - int(state.tick)) * SIM.TICK)
    var warning: String = "ROUTES SHIFT IN %.1fs" % remaining if not state.pending.is_empty() else "Route shift in %.0fs" % remaining
    status_label.text = "%s  |  %s%s" % [warning, str(network.get("status")), "  |  " + one_reason if not one_reason.is_empty() and active else ""]
    var objective_counts: Dictionary = {}
    for index in range(map.nodes.size()):
        if map.nodes[index].kind in ["objective", "central"] and int(state.owners[index]) > 0:
            var owner: int = int(state.owners[index])
            objective_counts[owner] = int(objective_counts.get(owner, 0)) + 1
    var summaries: PackedStringArray = []
    var teams: Array = objective_counts.keys()
    teams.sort()
    for team in teams:
        summaries.append("T%d: %d" % [int(team), int(objective_counts[team])])
    objectives_label.text = "Objectives  %s   |   Recruiting: #%d   |   Rally: #%d%s" % [" · ".join(summaries) if not summaries.is_empty() else "none held", int(player.base) + 1, int(player.rally) + 1, "   |   Cooperative sandbox" if bool(state.sandbox) else ""]
    if selected < 0:
        selection_label.text = "Select a node to inspect it. Right-click any node to rally your army there."
        reserve_help.text = "Select a node, then enter how many of your troops should stop there."
    else:
        var troops: int = 0
        var mine: int = 0
        for unit in state.units.values():
            if int(unit.node) == selected and int(unit.to) < 0:
                troops += 1
                if int(unit.player) == multiplayer.get_unique_id():
                    mine += 1
        var owner_text: String = "Neutral" if int(state.owners[selected]) == 0 else "Team %d" % int(state.owners[selected])
        selection_label.text = "#%d · %s · %s · %d troops (%d yours)%s" % [selected + 1, str(map.nodes[selected].kind).capitalize(), owner_text, troops, mine, " · CONTESTED" if bool(state.contested[selected]) else ""]
        var target: int = int(reserve_edit.value)
        var held: int = mini(mine, target) if friendly and not bool(player.retreat) else 0
        if not friendly:
            reserve_help.text = "Will entrench %d of your troops after capture. Extra troops continue toward your rally." % target
        elif bool(player.retreat):
            reserve_help.text = "Retreat active — entrenchment paused. Set a rally target to resume holding %d troops here." % target
        elif selected == int(player.rally):
            reserve_help.text = "Entrenched %d/%d · All troops hold at a rally destination. Choose another rally to send the surplus onward." % [held, target]
        else:
            reserve_help.text = "Entrenched %d/%d · Arrivals fill this target; surplus troops pass through. Set 0 to release defenders." % [held, target]

func _purchase_reason(player: Dictionary, state: Dictionary, map: Dictionary, amount: int) -> String:
    var base: int = int(player.base)
    if map.nodes[base].kind != "base" or int(state.owners[base]) != int(player.team) or bool(state.contested[base]):
        return "Recruitment paused: choose a safe allied base."
    if int(player.count) + amount > SIM.UNIT_CAP:
        return "Army limit reached."
    if float(player.credits) + 0.00001 < SIM.UNIT_COST * amount:
        return "Need %d credits to buy %d." % [int(SIM.UNIT_COST * amount), amount]
    return ""

func _leave() -> void:
    if multiplayer.is_server():
        if str(network.get("phase")) == "loading":
            network.call("cancel_loading")
        else:
            network.call("return_to_lobby")
    else:
        network.call("leave_session")
        get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

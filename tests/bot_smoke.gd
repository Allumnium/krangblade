extends SceneTree
## Real scenes and controls, with accelerated host time for the smoke test.
var session: Node
var failed: bool = false

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failed = true
        push_error("FAIL: " + message)

func _run() -> void:
    create_timer(20.0).timeout.connect(func() -> void: quit(1))
    session = root.get_node("GameSession")
    session.call("add_bot")
    _check((session.get("players") as Dictionary).is_empty(), "no offline bots")
    _check(bool(session.call("host_game", "BotTester", 0)), "host")
    change_scene_to_file("res://scenes/main.tscn")
    await process_frame
    await process_frame
    var menu: Control = current_scene
    var add_button: Button = menu.get("add_bot_button")
    add_button.pressed.emit()
    var players: Dictionary = session.get("players")
    _check(players.size() == 2 and bool(players[-1].ready), "UI adds a ready bot")
    session.call("choose_team", -1, 1)
    _check(bool(session.call("can_start")), "cooperative ready")
    session.call("choose_team", -1, 2)
    for index in range(6):
        session.call("add_bot")
    _check(players.size() == 8 and add_button.disabled, "lobby capacity")
    session.call("add_bot")
    _check(players.size() == 8, "cannot overfill")
    for id in players.keys():
        if int(id) < -1:
            session.call("remove_bot", id)
    session.call("start_match")
    while str(session.get("phase")) != "match":
        await process_frame
    await process_frame
    var match_ui: Control = current_scene
    _check((session.get("map_data") as Dictionary).nodes.size() == 129, "new map loaded")
    (match_ui.get("buy_five") as Button).pressed.emit()
    session.call("command", "rally", 6)
    (match_ui.get("auto_box") as CheckBox).toggled.emit(true)
    var timer: Timer = session.get("simulation_timer")
    timer.wait_time = 0.01
    while int((session.get("match_state") as Dictionary).tick) < 350:
        await process_frame
    var state: Dictionary = session.get("match_state")
    _check(int(state.players[1].count) > 5, "HUD recruitment")
    _check(int(state.owners[6]) == 1 and float(state.players[1].objective_income) > 0, "human travel and objective income")
    _check(int(state.owners[58]) == 2 and float(state.players[-1].objective_income) > 0, "bot travel and objective income")
    _check(int(state.topology) >= 1, "dynamic center")
    session.call("return_to_lobby")
    await process_frame
    await process_frame
    _check(timer.is_stopped() and (session.get("match_state") as Dictionary).is_empty(), "return clears simulation")
    _check(bool(session.call("can_start")), "bot stays ready")
    session.call("start_match")
    while str(session.get("phase")) != "match":
        await process_frame
    state = session.get("match_state")
    _check(int(state.tick) == 0 and float(state.players[1].credits) == 100.0 and state.units.size() == 10, "new round resets resources and troops")
    session.call("return_to_lobby")
    await process_frame
    await process_frame
    session.call("remove_bot", -1)
    _check(not bool(session.call("can_start")), "remove bot")
    session.call("leave_session")
    if not failed:
        print("PASS: lobby bots, match controls, recruitment, travel, income, route shifts, and fresh rounds")
    quit(1 if failed else 0)

extends SceneTree
const MAP = preload("res://scripts/planet_map.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var session: Node = root.get_node("GameSession")
    assert(not bool(session.call("start_solo", 1, [2], [1, 1])))
    assert(not bool(session.call("start_solo", 1, [2], [1, 9])))
    assert(not bool(session.call("start_solo", 1, [2], [1])))
    var menu: Control = load("res://scenes/main.tscn").instantiate()
    root.add_child(menu)
    menu.call("_show_solo_setup")
    var initial: Dictionary = menu.get("solo_players")
    assert(initial.size() == 4)
    for id in range(1, 5):
        assert(initial[id]["team"] == id and initial[id]["color"] == id)
        var row: Dictionary = menu.get("solo_rows")[id]
        assert((row["team"] as OptionButton).item_count == 4)
        assert((row["color"] as OptionButton).is_item_disabled(0) == (id != 1))
    menu.call("_solo_color_selected", 4, 1)
    assert(initial[1]["color"] == 5)
    menu.call("_solo_color_selected", 1, 1)
    assert(initial[1]["color"] == 5)
    for i in range(4):
        (menu.get("solo_add_button") as Button).pressed.emit()
    assert(initial.size() == 8 and (menu.get("solo_add_button") as Button).disabled)
    for row in (menu.get("solo_rows") as Dictionary).values():
        assert((row["team"] as OptionButton).item_count == 8)
    menu.call("_solo_team_selected", 7, 1)
    menu.call("_remove_solo_player", 8)
    assert((menu.get("solo_players") as Dictionary).size() == 7)
    assert(int(menu.get("solo_players")[1]["team"]) <= 7)
    assert(not (menu.get("solo_add_button") as Button).disabled)
    menu.call("_show_menu")
    menu.call("_show_solo_setup")
    assert((menu.get("solo_players") as Dictionary).size() == 4)
    menu.call("_show_multiplayer")
    assert(menu.get("screen") == "multiplayer")
    menu.call("_show_solo_setup")
    menu.call("_solo_color_selected", 6, 1)
    menu.call("_start_solo_from_setup")
    assert(session.get("players").size() == 4 and session.get("players")[1]["color"] == 7)
    assert(session.get("economy")["ships"].size() == 20)
    session.call("leave_solo")
    menu.free()
    assert(bool(session.call("start_solo")))
    assert(bool(session.get("is_solo")))
    assert(session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
    var state: Dictionary = session.get("economy")
    assert(int(state["time_speed"]) == 1)
    assert(state["ships"].size() == 5)
    assert(state["ships"].filter(func(craft: Dictionary) -> bool: return craft["kind"] == "miner").size() == 3)
    # Isolate original construction and colonization assertions.
    state["ships"].clear()
    session.call("request_time_speed", 0)
    var frozen: Dictionary = state.duplicate(true)
    for i in range(4):
        session.call("_economy_tick")
    assert(state == frozen)
    session.call("request_time_speed", 3)
    assert(int(state["time_speed"]) == 0)
    for speed in [1, 2, 5]:
        session.call("request_time_speed", speed)
        var before: float = float(state["elapsed"])
        session.call("_economy_tick")
        assert(is_equal_approx(float(state["elapsed"]) - before, 0.1 * float(speed)))
    session.call("request_time_speed", 1)
    var planets: Array = state["planets"]
    assert(planets.size() == state["map"]["points"].size())
    assert(state["map"]["cluster_sizes"].size() == 3)
    var neighbor: int = -1
    for i in range(1, planets.size()):
        if MAP.linked(state["map"], 0, i):
            neighbor = i
            break
    assert(neighbor >= 0)
    session.call("request_operation", 0, "colony_ship")
    for i in range(125):
        session.call("_economy_tick")
    assert(state["ships"].size() == 1)
    session.call("request_colonize", int(state["ships"][0]["id"]), neighbor)
    assert(int(planets[neighbor]["owner"]) == 0)
    for i in range(1020):
        session.call("_economy_tick")
        if int(planets[neighbor]["owner"]) == 1:
            break
    assert(int(planets[neighbor]["owner"]) == 1)
    assert(state["ships"].is_empty())
    session.call("request_operation", 0, "ship")
    assert(planets[0]["queue"].size() == 1)
    for i in range(100):
        session.call("_economy_tick")
    assert(state["ships"].size() == 1)
    session.call("leave_solo")
    assert(str(session.get("phase")) == "offline")
    assert((session.get("economy") as Dictionary).is_empty())
    assert(bool(session.call("start_solo", 3, [3, 2], [8, 4, 6])))
    assert(session.get("players")[1]["color"] == 8 and session.get("players")[2]["color"] == 4 and session.get("players")[3]["color"] == 6)
    var setup: Dictionary = session.get("economy")
    assert(int(setup["time_speed"]) == 1)
    assert(setup["map"]["cluster_sizes"].size() == 9)
    assert(setup["teams"][1] == 3 and setup["teams"][2] == 3 and setup["teams"][3] == 2)
    assert(session.get("players")[2]["ai"])
    assert(setup["ai_players"] == [2, 3])
    assert(setup["ships"].size() == 15)
    session.call("_economy_tick")
    assert(not setup["planets"][1]["queue"].is_empty())
    assert(not setup["planets"][2]["queue"].is_empty())
    assert(setup["planets"][0]["queue"].is_empty())
    for i in range(150):
        session.call("_economy_tick")
    for player in [2, 3]:
        assert(setup["ships"].any(func(ship: Dictionary) -> bool: return int(ship["owner"]) == player and ship["kind"] == "colony_ship"))
    session.call("leave_solo")
    print("PASS: offline solo planetary match, colonization, ship construction, reset")
    quit(0)

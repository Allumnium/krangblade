extends SceneTree
const MAP = preload("res://scripts/planet_map.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var session: Node = root.get_node("GameSession")
    assert(bool(session.call("start_solo")))
    assert(bool(session.get("is_solo")))
    assert(session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
    var state: Dictionary = session.get("economy")
    var planets: Array = state["planets"]
    assert(planets.size() == MAP.COUNT)
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
    print("PASS: offline solo planetary match, colonization, ship construction, reset")
    quit(0)

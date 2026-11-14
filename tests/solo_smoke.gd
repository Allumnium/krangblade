extends SceneTree
## In-process solo smoke: no ENet host or other player is required.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var session: Node = root.get_node("GameSession")
    assert(str(session.get("phase")) == "offline")
    assert(bool(session.call("start_solo")))
    assert(bool(session.get("is_solo")))
    assert(str(session.get("phase")) == "match")
    assert(session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
    assert((session.get("players") as Dictionary).size() == 1)
    assert((session.get("owners") as Array[int])[0] == 1)
    session.call("request_capture", 8)
    assert((session.get("owners") as Array[int])[8] == 1)
    session.call("request_build", 8, "mine")
    assert((session.get("buildings") as Array[String])[8] == "mine")
    session.call("_economy_tick")
    assert(int((session.get("stocks") as Array[Dictionary])[8]["iron"]) == 2)
    session.call("leave_solo")
    assert(str(session.get("phase")) == "offline")
    assert((session.get("buildings") as Array[String]).is_empty())
    print("PASS: solo starts, captures, builds, produces and returns offline")
    quit(0)

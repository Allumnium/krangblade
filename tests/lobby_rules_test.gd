extends SceneTree
const RULES = preload("res://scripts/lobby_rules.gd")

func _initialize() -> void:
    assert(not RULES.can_start({1: {"ready": true, "team": 1}}))
    assert(not RULES.valid_team(0) and not RULES.valid_team(9))
    assert(RULES.valid_team(1) and RULES.valid_team(8))
    var cases: Array[Array] = [
        [1, 1, 1, 1, 1, 1, 1, 1],
        [1, 2, 3, 4, 5, 6, 7, 8],
        [1, 2, 2, 2, 2, 2, 2, 2],
        [1, 1, 2, 2, 3, 3, 3, 3]
    ]
    for teams in cases:
        var players: Dictionary = {}
        for index in range(teams.size()):
            players[index + 1] = {"team": teams[index], "ready": true}
        assert(RULES.can_start(players))
        var loaded: Dictionary = {1: true}
        assert(not RULES.all_loaded(players, loaded))
        for id in players.keys():
            loaded[id] = true
        assert(RULES.all_loaded(players, loaded))
        RULES.reset_guest_ready(players)
        assert(not RULES.can_start(players))
        assert(bool(players[1]["ready"]))
        for id in players.keys():
            if int(id) != 1:
                assert(not bool(players[id]["ready"]))
    var coop: Dictionary = {1: {"ready": true, "team": 1}, 5: {"ready": true, "team": 1}}
    assert(RULES.can_start(coop))
    var bots: Dictionary = {
        1: {"ready": true, "team": 1},
        -1: {"ready": true, "team": 2},
        -2: {"ready": true, "team": 3}
    }
    assert(RULES.ordered_peers(bots) == [1, -1, -2])
    RULES.reset_guest_ready(bots)
    assert(RULES.can_start(bots))
    assert(not RULES.all_loaded(bots, {}))
    assert(RULES.all_loaded(bots, {1: true}))
    bots[7] = {"ready": true, "team": 4}
    assert(not RULES.all_loaded(bots, {1: true}))
    assert(RULES.all_loaded(bots, {1: true, 7: true}))
    RULES.reset_guest_ready(bots)
    assert(not RULES.can_start(bots))
    assert(bool(bots[-1]["ready"]) and bool(bots[-2]["ready"]))
    assert(not bool(bots[7]["ready"]))
    print("PASS: 2-8 teams, ready reset, and human/bot load barrier")
    quit(0)

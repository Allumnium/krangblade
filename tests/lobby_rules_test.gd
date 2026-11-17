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
    assert(RULES.ordered_peers(coop) == [1, 5])
    var bot_id: int = RULES.FIRST_AI_ID
    var mixed: Dictionary = {1: {"ready": true, "team": 1}, 5: {"ready": true, "team": 2}, bot_id: {"ready": true, "team": 3, "ai": true}}
    assert(bot_id > 2147483647)
    assert(RULES.ordered_peers(mixed) == [1, 5, bot_id])
    assert(RULES.can_start(mixed))
    assert(RULES.all_loaded(mixed, {1: true, 5: true}))
    RULES.reset_guest_ready(mixed)
    assert(mixed[bot_id]["ready"] and not mixed[5]["ready"])
    assert(not RULES.can_start(mixed))
    print("PASS: 2–8 teams, mixed AI readiness and load barrier")
    quit(0)

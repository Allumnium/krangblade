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
        var owners: Array[int] = RULES.starting_owners(players)
        assert(owners.size() == 17)
        for index in range(8):
            assert(owners[index] == teams[index])
        for index in range(8, 17):
            assert(owners[index] == 0)
    var two: Dictionary = {1: {"ready": true, "team": 1}, 5: {"ready": true, "team": 1}}
    assert(RULES.can_start(two))
    assert(RULES.starting_owners(two)[1] == 1)
    two[5]["ready"] = false
    assert(not RULES.can_start(two))
    two[5]["ready"] = true
    two[5]["team"] = 9
    assert(not RULES.can_start(two))
    print("PASS: 2–8 players, arbitrary team assignments and starting territories")
    quit(0)

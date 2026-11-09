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
    var territory: Array[int] = RULES.starting_owners(coop)
    assert(territory[0] == 1 and territory[1] == 1)
    assert(RULES.can_capture(territory, 1, 8))
    assert(not RULES.can_capture(territory, 2, 8))
    assert(not RULES.can_capture(territory, 1, 16))
    assert(not RULES.can_capture(territory, 1, 0))
    print("PASS: 2-8 teams, ready reset, load barrier, and team captures")
    quit(0)

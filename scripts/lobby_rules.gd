extends RefCounted
# Pure, headless-testable rules. Team numbers are independent of player slots.
const MAX_PLAYERS: int = 8
const MAP_NODE_COUNT: int = 17

static func valid_team(team: int) -> bool:
    return team >= 1 and team <= MAX_PLAYERS

static func ordered_peers(players: Dictionary) -> Array[int]:
    var ids: Array[int] = []
    for key in players.keys():
        ids.append(int(key))
    ids.sort()
    return ids

static func can_start(players: Dictionary) -> bool:
    if players.size() < 2 or players.size() > MAX_PLAYERS or not players.has(1):
        return false
    for entry in players.values():
        if not entry is Dictionary:
            return false
        if not bool(entry.get("ready", false)):
            return false
        if not valid_team(int(entry.get("team", 0))):
            return false
    return true

static func starting_owners(players: Dictionary) -> Array[int]:
    var owners: Array[int] = []
    owners.resize(MAP_NODE_COUNT)
    owners.fill(0)
    var peers: Array[int] = ordered_peers(players)
    for seat in range(mini(peers.size(), MAX_PLAYERS)):
        var entry: Dictionary = players[peers[seat]]
        owners[seat] = int(entry.get("team", 0))
    return owners

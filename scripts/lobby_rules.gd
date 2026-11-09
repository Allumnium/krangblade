extends RefCounted
## Pure logic for lobby readiness, team assignments, load barrier and captures.
const MAX_PLAYERS: int = 8
const MAP_NODE_COUNT: int = 17

static func valid_team(team: int) -> bool:
    return team >= 1 and team <= MAX_PLAYERS

static func ordered_peers(players: Dictionary) -> Array[int]:
    var ids: Array[int] = []
    for id in players.keys():
        ids.append(int(id))
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

static func reset_guest_ready(players: Dictionary) -> void:
    for id in players.keys():
        var item: Dictionary = players[id]
        item["ready"] = int(id) == 1
        players[id] = item

static func all_loaded(players: Dictionary, loaded: Dictionary) -> bool:
    if players.size() < 2 or players.size() > MAX_PLAYERS:
        return false
    for id in players.keys():
        if not bool(loaded.get(id, false)):
            return false
    return true

static func starting_owners(players: Dictionary) -> Array[int]:
    var owners: Array[int] = []
    owners.resize(MAP_NODE_COUNT)
    owners.fill(0)
    var peers: Array[int] = ordered_peers(players)
    for seat in range(mini(peers.size(), MAX_PLAYERS)):
        var item: Dictionary = players[peers[seat]]
        owners[seat] = int(item.get("team", 0))
    return owners

static func linked(a: int, b: int) -> bool:
    if a < 0 or b < 0 or a >= MAP_NODE_COUNT or b >= MAP_NODE_COUNT or a == b:
        return false
    if a == 16:
        return b >= 8 and b < 16
    if b == 16:
        return a >= 8 and a < 16
    if a < 8 and b >= 8:
        return a == b - 8
    if b < 8 and a >= 8:
        return b == a - 8
    if (a < 8) != (b < 8):
        return false
    return (a + 1) % 8 == b % 8 or (b + 1) % 8 == a % 8

static func can_capture(owners: Array[int], team: int, node: int) -> bool:
    if not valid_team(team) or owners.size() != MAP_NODE_COUNT:
        return false
    if node < 0 or node >= owners.size() or owners[node] != 0:
        return false
    for other in range(owners.size()):
        if owners[other] == team and linked(other, node):
            return true
    return false

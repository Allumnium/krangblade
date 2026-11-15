extends RefCounted
## Pure logic for lobby readiness, team assignments, and load barrier.
const MAX_PLAYERS: int = 8

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


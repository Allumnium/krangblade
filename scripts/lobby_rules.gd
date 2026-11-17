extends RefCounted
## Pure logic for lobby readiness, team assignments, and load barrier.
const MAX_PLAYERS: int = 8
const FIRST_AI_ID: int = 2147483648
const EMPIRE_COLORS = [Color("#607286"), Color("#67d4a9"), Color("#f4a46a"), Color("#77aafe"),
    Color("#ce91ed"), Color("#eed16b"), Color("#f084a6"), Color("#6bcbd4"), Color("#ed7577")]
const COLOR_NAMES = ["Neutral", "Jade", "Orange", "Blue", "Violet", "Gold", "Rose", "Cyan", "Red"]

static func color_available(players: Dictionary, id: int, choice: int) -> bool:
    if choice < 1 or choice > MAX_PLAYERS:
        return false
    for peer in players:
        if int(peer) != id and int(players[peer].get("color", 0)) == choice:
            return false
    return true

static func free_color(players: Dictionary) -> int:
    for choice in range(1, MAX_PLAYERS + 1):
        if color_available(players, -1, choice):
            return choice
    return 0

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
        item["ready"] = int(id) == 1 or bool(item.get("ai", false))
        players[id] = item

static func all_loaded(players: Dictionary, loaded: Dictionary) -> bool:
    if players.size() < 2 or players.size() > MAX_PLAYERS:
        return false
    for id in players.keys():
        if not bool(players[id].get("ai", false)) and not bool(loaded.get(id, false)):
            return false
    return true


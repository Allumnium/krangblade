extends SceneTree
## Reordered/lost UDP chunks must never expose partial or stale match state.
const SIM = preload("res://scripts/match_simulation.gd")
var session: Node
var failed: bool = false

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failed = true
        push_error("FAIL: " + message)

func _send(state: Dictionary, state_round: int, reverse: bool = false, omit: int = -1) -> void:
    var bytes: PackedByteArray = var_to_bytes(state).compress(FileAccess.COMPRESSION_DEFLATE)
    var total: int = ceili(float(bytes.size()) / 1000.0)
    var order: Array[int] = []
    for part in range(total):
        order.append(part)
    if reverse:
        order.reverse()
    for part in order:
        if part != omit:
            session.call("_rpc_state", state_round, int(state.tick), part, total, bytes.slice(part * 1000, (part + 1) * 1000))

func _run() -> void:
    session = root.get_node("GameSession")
    var sim := SIM.new()
    sim.setup({1: {"name": "A", "team": 1}, -1: {"name": "B", "team": 2}}, 12345)
    for index in range(95):
        sim._spawn(1, 0, 20.0)
        sim._spawn(-1, 52, 20.0)
    session.set("phase", "match")
    session.set("round_id", 7)
    session.set("map_data", sim.map)
    session.set("match_state", sim.snapshot())
    var snapshot: Dictionary = sim.snapshot()
    snapshot.tick = 1
    _send(snapshot, 6)
    _check(int((session.get("match_state") as Dictionary).tick) == 0, "reject old round")
    _send(snapshot, 7, true)
    _check(int((session.get("match_state") as Dictionary).tick) == 1, "assemble reversed chunks")
    snapshot.tick = 2
    _send(snapshot, 7, false, 0)
    _check(int((session.get("match_state") as Dictionary).tick) == 1, "missing chunk leaves previous state intact")
    snapshot.tick = 3
    _send(snapshot, 7, true)
    _check(int((session.get("match_state") as Dictionary).tick) == 3, "new snapshot supersedes incomplete one")
    snapshot.tick = 2
    _send(snapshot, 7)
    _check(int((session.get("match_state") as Dictionary).tick) == 3, "late snapshot cannot rewind state")
    snapshot.tick = 4
    snapshot.result = "Team 1 wins!"
    var payload: PackedByteArray = var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_DEFLATE)
    session.call("_rpc_final_state", 6, payload)
    _check(str((session.get("match_state") as Dictionary).result).is_empty(), "reject previous-round results")
    session.call("_rpc_final_state", 7, payload)
    _check(str((session.get("match_state") as Dictionary).result) == "Team 1 wins!", "reliable final state accepted")
    snapshot.tick = 5
    snapshot.result = ""
    _send(snapshot, 7, true)
    _check(int((session.get("match_state") as Dictionary).tick) == 4, "late snapshots cannot unfreeze result")
    session.call("_clear_match")
    _check((session.get("incoming_parts") as Dictionary).is_empty() and int(session.get("incoming_tick")) == -1, "new round clears receive buffers")
    session.set("phase", "offline")
    if not failed:
        print("PASS: reversed/incomplete/stale snapshot chunks, round isolation, final freeze, and cleanup")
    quit(1 if failed else 0)

# Warbound — territory-control RTS economy prototype

**Engine:** Godot 4.7.2 (GDScript, Compatibility renderer)  
**Networking:** ENet (UDP port 24567) for multiplayer; no Steam dependency.  
**Current milestone:** Solo economy sandbox and shared host-authoritative production simulation.

## Play single player

1. Open the project in Godot and press Run.
2. Choose **SINGLE PLAYER**. The match starts immediately without opening a multiplayer socket or requiring a lobby.
3. Click a neutral (gray) node touching your colored territory to capture it.
4. Select your nodes and build **Mines**, **Smelters** and **Factories** in the panel at right.
5. Mine the silver-rimmed iron deposits and orange-rimmed copper deposits. Build a smelter and factory on connected friendly nodes. Goods move automatically across territory links toward buildings that consume them.
6. Watch the team-wide and per-node inventories to identify logistical bottlenecks. Finished supplies are transported back to your gold-rimmed headquarters.
7. Choose **RETURN TO MENU** to end the solo match.

**Example chain:** Iron Mine → Smelter (2 iron → 1 steel); Copper Mine + Steel → Factory (1 steel + 1 copper → 1 supply); Factory → Headquarters. A mine generates 2 raw units per second. Each connected friendly edge carries up to 3 units **total** per second, with goods traveling at most one edge per second. Per-node stock is capped at 30 units per resource, except HQ supplies, which can accumulate. Buildings can be reconfigured without cost in this sandbox. Owned adjacent nodes automatically form transport links; there is no manual road construction yet.

The first eight starting territories are HQs for the participating players. The node graph and resource deposits are fixed for now; the economy model is separate from map rendering so regions can replace nodes later.

## Play multiplayer

1. Run the project and choose **MULTIPLAYER**.
2. Host chooses **HOST GAME**. Guests choose **JOIN GAME**, using 127.0.0.1 for same-machine tests or the host's Tailscale IPv4 address for internet play.
3. Host or guests assign teams. A host can set anyone's team; guests control their own. Two to eight players can use any distribution among Teams 1–8, including a single cooperative team.
4. Guests toggle **READY**. Host chooses **START MATCH** once everyone is ready.
5. Input is locked until all peers have loaded their match scenes; the host then sends a synchronized start. Players begin with separate HQs, with team-shared territory ownership and resource transport.
6. The host validates captures and construction and advances the economy once per second, broadcasting inventory/building snapshots to all clients.
7. **RETURN TO LOBBY** (host) preserves connections, chat and teams but resets the match; guests can leave at any time. Host departure returns guests to the menu.

## Architecture

- `scripts/game_session.gd`: persistent host-authoritative session, RPCs, lobby/chat, synchronized scene loads, captures, construction and economy sync; solo is an offline local authority.
- `scripts/lobby_rules.gd`: pure team, readiness, loading and node-adjacency rules.
- `scripts/economy_rules.gd`: pure deterministic resource extraction, recipes, BFS resource routing on team-owned connected nodes, edge-throughput limits, stock caps and rules for construction.
- `scripts/main.gd`: title menu and multiplayer lobby/chat.
- `scripts/match.gd`: shared solo/multiplayer node map, construction UI, economy summary and node inventories.

## Automated validation

GitHub Actions for Godot 4.7.2 validates import, script parsing, rules, a solo start/capture/build/economy/end-to-menu smoke, startup, and real two- and eight-process headless ENet round trips including return-to-lobby and disconnect recovery. For manual testing, start a solo game and assemble the full chain, then try multiplayer over LAN/Tailscale.

## Future milestones

The current milestone deliberately has **no combat, armies, victory conditions, unit micromanagement, construction costs, building upgrades, player-drawn roads, saved matches, procedural maps, Steam integration, or AI opponents**. The next major work is economic interaction and territory-conflict systems; the economic and map layers are separated so a node map can evolve into regions.

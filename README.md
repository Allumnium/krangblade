# Warbound — multiplayer army-and-economy RTS

Godot 4.7.2, GDScript, Compatibility renderer. Host-authoritative ENet networking on UDP **24567**. Play locally, over LAN, or through Tailscale; Steam is not required.

## Start a match

1. Open `project.godot` in Godot and run the project. Choose **Multiplayer → Host Game**.
2. For solo testing, choose **Add Bot** in the lobby. Guests can join using `127.0.0.1` on the same PC or the host's LAN/Tailscale IPv4 address.
3. Assign Teams 1–8. The host can change everyone's team and remove bots; guests can change their own team. Bots are always ready. Adding/removing bots or changing teams resets human guests' ready states.
4. Once all guests are ready, the host chooses **Start Match**. Two to eight participants, including bots, are supported. Input and simulation wait for all human match scenes to load. A 20-second timeout cancels a stalled start.
5. The host can **Return to Lobby** after or during a match. Connections, teams, and chat persist; armies and resources reset for the next round. Guests can leave independently. A departing guest's army and budget are controlled by a bot for the rest of that round; that disconnected slot is removed on return to the lobby. Host departure returns guests to the menu.

## Army controls

- **Left-click** a node to inspect its owner, type, and troop count.
- **Right-click** a node, or select it and choose **Rally Here**, to send your mobile troops and future reinforcements toward it. Troops choose shortest available routes and capture intermediate territory before advancing.
- **Buy 1 / Buy 5** recruits at your chosen base. **Auto-Recruit** purchases one troop per simulation tick whenever funds, capacity, and a safe base are available. It starts disabled for humans.
- Select an uncontested allied base and choose **Recruit Here** to change your production location. If your base falls or becomes contested, production automatically switches to another safe allied base if available.
- Select any node and set **Entrench troops here** to the number of your troops that should stay. Changes save automatically after a short pause; Enter or **Entrench** applies immediately. The first N troops stop there, new arrivals fill shortages, and surplus troops follow the rally. Set **0** to release defenders. You can plan entrenchment on neutral/enemy nodes before capture. Cyan rings mark configured holding points, and the HUD shows the current/target count. Defaults: two at bases, one at income objectives, zero elsewhere. All troops hold at their rally destination until you choose another rally; retreat overrides entrenchment.
- Select an allied node and choose **Retreat Here** to withdraw your own troops. Troops on links reverse to their departure node first. Retreat overrides garrison reserves; a subsequent rally order restores normal advancing behavior.
- **WASD / arrow keys** move the camera; hold **Shift** for faster movement. Move the mouse to the battlefield's edges or **middle-drag** to pan. **Mouse wheel** zooms around the cursor; **Fit Map** shows the whole battlefield. Camera movement pauses while editing text or a garrison number. Hover/select a node to preview the route from the selected node, or your recruitment base when none is selected.
- **F11**, **Alt+Enter**, or the **Fullscreen** button toggles fullscreen from menus, the lobby, or a match. **Esc** leaves fullscreen. Your previous window size and camera view are preserved.

## Battlefield and objectives

The map has **129 nodes**: eight identical 13-node branches and a 25-node central web. Each branch has a base location and four diamonds offering alternate paths. Two junctions per branch earn income. Participants begin evenly spaced around the outside; unused starting locations are ordinary neutral territory.

The center has eight entrances, sixteen irregular inner-ring nodes, and a central objective. A permanent backbone and six seeded shortcuts always remain connected. Four additional purple shortcuts change every **30 seconds**. During the **five-second warning**, orange routes will close and dashed cyan routes will open. Troops already on a closing route finish crossing it; new paths use the changed network. Four inner-ring objectives and the center provide additional income.

Squares are bases, gold-ringed diamonds are income objectives, and circles are ordinary territory. Ownership uses team colors. Moving dots are individual troops; the battlefield interpolates between host snapshots. Battles show combat flashes, and capture arcs show progress. Zoom in to read troop totals and node IDs in dense areas.

## Economy and combat

| Rule | Initial balance |
|---|---|
| Starting resources per player | 100 credits and 5 free troops |
| Troop cost | 20 credits |
| Base income | 4 credits/second per active player |
| Objective income | 2 credits/second; center 4 |
| Army limit | 100 living troops per player |
| Troop statistics | 10 health, 3 damage/second, 60 world units/second |
| Captures | 3 seconds; bases 10 seconds |
| Combat-loss refund | 10% of the killed troop's purchase cost |

Budgets and troop commands are personal. Territory belongs to the team. Objective income is divided evenly among active teammates, retaining fractional credits; base income continues while the team has a base. Contested objectives stop paying. The HUD shows your budget, income breakdown, troop count, cumulative refunds, recruitment base, rally target, and objective ownership.

Opposing troops fight automatically at nodes and when meeting on a link. Health persists, damage is simultaneous, and multi-team battles divide outgoing damage equally among hostile teams. Friendly fire is disabled. Only uncontested attackers progress a capture; opposing troops pause it, and defending troops clearing the attackers reset it.

Combat refunds go to the purchaser and provide a small recovery after losses. Free starting troops and administrative/elimination cleanup give no refunds. Bots pay the same costs and follow the same movement, combat, and income rules as humans; they recruit automatically, seek objectives, then attack enemy bases.

## Victory

Captured bases can recruit for their new team. Losing your own base does not eliminate you while your team has another. Losing every team base eliminates the team and removes its troops without refunds. Eliminated players can watch until the round ends. The last team wins; simultaneous final-base losses produce a draw, including simultaneous base swaps. Results freeze the simulation until the host returns everyone to the lobby.

A lobby that starts entirely on one team runs as a cooperative testing sandbox without an automatic victory.

## Code and networking

- `scripts/map_generator.gd`: seeded graph generation, connectivity, weighted routing, and stable node IDs.
- `scripts/match_simulation.gd`: pure match state, centralized balance constants, validated orders, armies, income, combat, captures, bots, and victory. Runs at fixed 100ms ticks.
- `scripts/game_session.gd`: persistent lobby and RPC endpoints, loading barrier, authoritative simulation timer, commands, and round/tick checks. Initial maps and final results are reliable; 10Hz snapshots use DEFLATE compression and sub-MTU chunks on an unreliable channel. Application-level tick ordering rejects stale snapshots while allowing chunks to arrive out of order. Incomplete snapshots are discarded when a newer tick arrives.
- `scripts/match.gd` and `scripts/battlefield.gd`: responsive HUD, camera, route previews, and interpolated troop rendering.
- `scripts/main.gd` and `scripts/lobby_rules.gd`: menu/lobby UI and map-independent readiness/team rules.

## Validation

Run with a Godot executable on PATH:

```powershell
godot --headless --path . --script res://tests/lobby_rules_test.gd
godot --headless --path . --script res://tests/simulation_test.gd
godot --headless --path . --script res://tests/snapshot_test.gd
godot --headless --path . --script res://tests/bot_smoke.gd
godot --path . --script res://tests/ui_smoke.gd
```

The simulation suite covers branch symmetry, connectivity, income sharing, purchases, limits, combat/refunds, captures, retreats, route changes during travel, elimination, draws, bots, and an eight-player/800-troop load. The rendered test checks normal/narrow layouts and a dense central battle, saving `warbound-ui-*.png` in the system temporary directory.

GitHub Actions additionally runs real two- and eight-process ENet sessions, including an 800-troop network load, mixed human/bot lobbies, guest takeover, loading departures, and host departures. It verifies movement, purchasing, combat, income, changing routes, results, stale-order rejection, and clean lobby return. Smaller network smoke tests accelerate the host timer to cover route shifts quickly; the 800-troop network test uses the production 10Hz rate.

For manual testing, use LAN/Tailscale clients, inspect route changes while armies are crossing, try allied recruitment and retreats during battles, resize the window, and play through base elimination. Balance values are an initial playable preset and need playtesting.

Not included: additional unit classes, upgrades, fog of war, persistent progression, saves, Steam matchmaking/invites, reconnecting to running matches, or host migration.

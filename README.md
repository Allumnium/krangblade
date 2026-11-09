# Warbound — multiplayer territory-control RTS

Engine: Godot 4.7.2 (GDScript, Compatibility renderer).
Networking: ENet, UDP port 24567. No Steam required for local or Tailscale play.

## Host and join

1. Run the project and choose Multiplayer.
2. Host chooses Host Game. Guests choose Join Game using 127.0.0.1 for same-PC tests or the host's Tailscale IPv4 address for internet play.
3. Host or guests assign teams. A host can set anyone's team, while guests control their own. Two to eight players can use any distribution among Teams 1–8, including a single cooperative team.
4. Guests toggle Ready. Host chooses Start Match once everyone is ready.
5. Input is locked until **all participants report their match scenes loaded**. The host then sends a synchronized start. Each player begins with a territory; teammates share territory ownership and colors.
6. During a match, Return to Lobby (host) brings everyone back without disconnecting. Ready states reset, while teams, chat, and connections persist. Guests can leave independently.
7. If a player disconnects while loading, the host removes them; if at least two players remain and all remaining peers load, the match begins. If fewer remain, the host returns everyone to the lobby. A 20-second timeout cancels a stalled start.
8. If the host disconnects, guests return to the multiplayer menu.

## Architecture

- scripts/game_session.gd: persistent GameSession autoload with all RPC endpoints, lobby state, chat, load acknowledgments, match roster and territory ownership. Changing scenes does not remove networking RPC handlers.
- scripts/main.gd: menu and lobby UI; player list scrolls, and lobby panels flow-wrap vertically for narrow windows.
- scripts/match.gd: the visual territory prototype; sends capture requests through GameSession and disables input until the host starts.
- scripts/lobby_rules.gd: pure, testable team, readiness, load barrier and capture rules.

## Validation

GitHub Actions on Godot 4.7.2 checks import, script types, rules, startup, and real two- and eight-process headless ENet round trips: hosting, joining, ready, synchronized match start, and return to lobby. Manually launch 2–8 game instances over LAN/Tailscale to test closing a client during loading, guest departure mid-match, host departure, and narrow window sizes.

Not yet included: Steam matchmaking/invites, spectators, reconnecting to running matches, host migration, combat, economy, victory conditions, or persistence.

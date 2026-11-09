# Warbound — territory-control RTS

Godot **4.7.2**, GDScript, Compatibility renderer. Multiplayer uses direct ENet over UDP **24567**, without Steam.

## Test with 2–8 instances
1. Launch 2–8 copies (or use Godot's multiple run instances).
2. One player chooses **Multiplayer → Host Game**.
3. Other players choose **Multiplayer → Join Game**, address `127.0.0.1` locally or the host's Tailscale IPv4 address remotely.
4. Assign **Team 1–8** in the lobby. Any composition works: 1v7, 2v2v4, 8 free-for-all, or all players on one team.
5. The host can change any player's team; each guest can change their own. Changes reset guest ready states.
6. All guests press **Ready**. The host starts once 2–8 players are present and ready.
7. Each player begins with a territory on a 17-node prototype map. Teammates share a color and can capture neutrals adjacent to any territory owned by their team.

The lobby supports **up to 8 players** in **1–8 teams**, with no forced balancing. Empty seats are permitted. Host is always ready; the host owns and validates the roster, readiness, assignments, and chat. Chat has a 250-character limit, 100-message history, and basic throttling. Host departure ends the lobby.

This is an early **team-capable territory prototype**: team colors/capture work, but there is no combat, team scoring, elimination, AI, Steam integration, invites, public matchmaking, or map selection. Players on the same team jointly control territories.

## Validation

GitHub Actions imports with Godot 4.7.2, parses both scene scripts and the rules, runs headless rules tests, and smoke-tests startup. Real 2–8 player network testing must still be done manually.

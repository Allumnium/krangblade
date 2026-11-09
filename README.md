# Krangblade — Territory RTS prototype

**Engine:** Godot **4.7.2-stable** (Godot 4.7 series), standard GDScript edition, Compatibility renderer.

An intentionally tiny multiplayer-first vertical slice with **no Steam dependency**. Steam integration is planned later, but all current testing uses ENet.

## Run locally

1. Install [Godot 4.7.2-stable](https://godotengine.org/download/archive/4.7.2-stable/) and clone this repository.
2. Import `project.godot` using the Godot 4.7.2 Project Manager. If opening an older local copy, close Godot, pull the latest files, and reopen it with 4.7.2.
3. Launch two game instances (in the Godot editor, **Debug > Customize Run Instances**, set 2 instances, or run the project twice).
4. In the first window choose **Host**.
5. In the second window leave `127.0.0.1` in Host IP and choose **Join**.
6. Host is green; joining player is orange. Click a gray territory connected to one you own. Both windows should display the capture.

On separate LAN machines, enter the host's LAN IP. For internet testing without Steam, use a VPN such as Tailscale or configure UDP port forwarding for **24567**. ENet uses UDP, not TCP.

## Scope

- Seven connected territories with deterministic layout
- Two factions: host (green) and first client (orange)
- Server-authoritative neutral territory capture
- Shared ownership state sent over Godot ENet RPC
- Minimal host/join IP controls and procedural rendering
- No textures, Steam SDK, dedicated server, army AI, economy, combat, or persistence

## Architecture

`scenes/main.tscn` is the entry scene and `scripts/main.gd` implements the current prototype. The host validates adjacency and claims; clients only request actions. Steam transport can later replace the ENet peer without changing territory ownership rules. This is a scaffold, not production-ready lobby/security/network recovery code.

## Acceptance test (Godot 4.7.2)

Host and client connect on localhost; each claims at least one adjacent gray territory; both screens show identical territory ownership. Attempting to claim a non-adjacent territory or an owned territory should have no effect.

## Next step

Extract the map and capture rules into a headless-testable simulation model, then add autonomous army movement between adjacent territories.

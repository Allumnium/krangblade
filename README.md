# Warbound — territory-control RTS

Godot **4.7.2**, GDScript, Compatibility renderer. Multiplayer uses direct ENet over UDP **24567**, without Steam.

## Test with two instances
1. Launch two copies (or configure two run instances in Godot).
2. First copy: **Multiplayer → Host Game**.
3. Second copy: **Multiplayer → Join Game**, address `127.0.0.1`. For internet play, use the host's Tailscale IPv4 address.
4. Send messages in lobby chat. Guest presses **Ready**; host presses **Start Match**.
5. Both instances load the seven-territory prototype; capture adjacent neutral nodes.

The prototype currently supports **two players only**. Host owns roster, ready state and chat validation; chat is capped at 250 characters, 100 history entries, and throttled per sender. Host is always ready. Disconnecting the host closes the lobby for guests.

Steam friends, invitations, matchmaking, map selection and full RTS gameplay are not implemented yet.

GitHub Actions checks Godot import, both scripts, and headless startup. Manual two-instance network validation is still required.

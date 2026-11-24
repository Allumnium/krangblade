# Optional Warbound native kernels

Experimental, not required to play, not enabled by default. Initial implementation moves ordered laser and missile block target searches to C++. It uses the same packed points/IDs, bounding-box pruning, tie and focus rules as scripts/combat_kernels.gd. Host-only computation; no RPC or snapshot change.

## Local build (Linux or Windows x86_64)

Install SCons and a supported C++ compiler. In this directory, place a matching Godot 4.7-compatible godot-cpp checkout at godot-cpp/; pin the tested revision for reproducible builds. See the [official GDExtension guide](https://docs.godotengine.org/en/latest/tutorials/scripting/cpp/gdextension_cpp_example.html). Use the same single/double engine precision as the Godot executable (the project uses standard precision).

Run from native/:

    scons platform=linux target=template_release arch=x86_64

For Windows use platform=windows. Copy warbound_kernels.gdextension.example to warbound_kernels.gdextension only after the shared library exists at the descriptor's path. Restart/import the project in Godot. Generated binaries, dependency checkout and active local descriptor are ignored by Git; an ordinary clone remains GDScript-only.

Run from the project root (replace godot with the actual executable):

    godot --headless --editor --path . --import --quit
    godot --headless --path . --script res://tests/economy_rules_test.gd -- --warbound-native-kernels

The parity test fails if native is explicitly requested but absent. Compare seeded replay hashes and fleet benchmarks with and without --warbound-native-kernels (append after --). For a game run:

    godot --path . -- --warbound-native-kernels

The flag is local, opt-in, not a multiplayer setting. No default activation until compiled and verified on supported platforms. Missing extension falls back to GDScript; remove the local descriptor if its library is missing. Native compilation, engine parity, ENet and speedup are not yet verified.

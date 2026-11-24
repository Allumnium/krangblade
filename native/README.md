# Optional Warbound native kernels

Experimental, not required to play, not enabled by default. Initial implementation moves ordered laser and missile block target searches to C++. It uses the same packed points/IDs, bounding-box pruning, tie and focus rules as scripts/combat_kernels.gd. Host-only computation; no RPC or snapshot change.

## Local build (Linux or Windows x86_64)

Install SCons and a supported C++ compiler. The Windows x86_64 build was verified with Godot 4.7.2, SCons 4.11.1, and godot-cpp commit `7fd5c4bc3efda6487fd6e6486c50016faa622f92` (standard 64-bit precision). To reproduce from the project root:

    git clone --filter=blob:none --depth 1 https://github.com/godotengine/godot-cpp.git native/godot-cpp
    git -C native/godot-cpp checkout 7fd5c4bc3efda6487fd6e6486c50016faa622f92

See the [official GDExtension guide](https://docs.godotengine.org/en/latest/tutorials/scripting/cpp/gdextension_cpp_example.html). On Windows, build from a Visual Studio Developer prompt. The project object file is emitted under the ignored godot-cpp checkout so Godot will not scan it as an OBJ model.

Run from native/:

    scons platform=linux target=template_release arch=x86_64

For Windows use platform=windows. Copy warbound_kernels.gdextension.example to warbound_kernels.gdextension only after the shared library exists at the descriptor's path. Restart/import the project in Godot. Generated binaries, dependency checkout and active local descriptor are ignored by Git; an ordinary clone remains GDScript-only.

Run from the project root (replace godot with the actual executable):

    godot --headless --editor --path . --import --quit
    godot --headless --path . --script res://tests/economy_rules_test.gd -- --warbound-native-kernels

The parity test fails if native is explicitly requested but absent. Compare seeded replay hashes and fleet benchmarks with and without `--warbound-native-kernels` (append after `--`). Native targeting parity passes on the verified build, but one target-scale headless comparison showed no meaningful speedup; keep the extension opt-in. For a game run:

    godot --path . -- --warbound-native-kernels

The flag is local, opt-in, not a multiplayer setting. No default activation until compiled and verified on supported platforms. Missing extension falls back to GDScript; remove the local descriptor if its library is missing. Native compilation and targeting parity are verified on the documented Windows build. Native-plus-threaded operation, other platforms and any speedup remain unverified.

# Optional Warbound native kernels

Experimental, not required to play, not enabled by default. The extension moves ordered laser and missile block target searches, whole frozen ship-contact and soft-separation passes, and live ordered hull-obstacle queries to C++. It preserves packed inputs, bounding-box pruning, ties, roster and correction order; GDScript still applies movement and owns gameplay state. Host-only computation; no RPC or snapshot change.

## Local build (Linux or Windows x86_64)

Install SCons and a supported C++ compiler. An earlier Windows x86_64 targeting-only build was verified with Godot 4.7.2, SCons 4.11.1, and godot-cpp commit `7fd5c4bc3efda6487fd6e6486c50016faa622f92` (standard 64-bit precision). To reproduce from the project root:

    git init native/godot-cpp
    git -C native/godot-cpp remote add origin https://github.com/godotengine/godot-cpp.git
    git -C native/godot-cpp fetch --depth 1 origin 7fd5c4bc3efda6487fd6e6486c50016faa622f92
    git -C native/godot-cpp checkout --detach FETCH_HEAD

See the [official GDExtension guide](https://docs.godotengine.org/en/latest/tutorials/scripting/cpp/gdextension_cpp_example.html). On Windows, build from a Visual Studio Developer prompt. The project object file is emitted under the ignored godot-cpp checkout so Godot will not scan it as an OBJ model.

Run from native/:

    scons platform=linux target=template_release arch=x86_64 build_profile=build_profile.json

For Windows use platform=windows (the trimmed profile and contact/separation and steering kernels still require Windows validation). The profile limits generated bindings to required classes; omitting it builds the full bindings. Copy warbound_kernels.gdextension.example to warbound_kernels.gdextension only after the shared library exists at the descriptor's path. Restart/import the project in Godot. Generated binaries, dependency checkout and active local descriptor are ignored by Git; an ordinary clone remains GDScript-only.

Run from the project root (replace godot with the actual executable):

    godot --headless --editor --path . --import --quit
    godot --headless --path . --script res://tests/economy_rules_test.gd -- --warbound-native-kernels

The parity test fails if native is explicitly requested but absent. For focused native geometry and movement settlement parity, append `--native-kernels-only` to the test command. Compare seeded replay hashes and fleet benchmarks with and without `--warbound-native-kernels` (append after `--`). Native targeting parity passes on the verified build, but one target-scale headless comparison showed no meaningful speedup; keep the extension opt-in. For a game run:

    godot --path . -- --warbound-native-kernels

The flag is local, opt-in, not a multiplayer setting. No default activation until compiled and verified on supported platforms. Missing extension falls back to GDScript; remove the local descriptor if its library is missing. The earlier targeting-only Windows build and current Linux contact/separation/steering build were verified. Linux native-plus-threaded worker and 2/4/8-peer ENet gameplay checks pass (shutdown warnings remain); Windows contact/separation/steering/threaded parity, packaged distribution and full-scale acceptance remain open.


## Manual cross-platform validation

Run the [Native validation workflow](https://github.com/Allumnium/krangblade/actions/workflows/native-validation.yml) to build pinned Linux/Windows x86_64 libraries, check focused parity and threaded integration, and collect validated library/descriptor artifacts. This workflow is newly prepared and has not yet run. No automatic native activation until supported-platform correctness and hardware benefit are demonstrated; normal GDScript execution remains available.

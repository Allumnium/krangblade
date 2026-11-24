#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <algorithm>
#include <cmath>
#include <cstdint>

using namespace godot;

// Consume immutable ordered blocks. No gameplay state or SceneTree access.
class WarboundNativeKernels : public RefCounted {
    GDCLASS(WarboundNativeKernels, RefCounted);

    static Array nearest(const Array &blocks, Vector2 pos, double best,
                         int64_t target, bool missile, bool focused, int64_t focus_id) {
        for (int64_t b = 0; b < blocks.size(); ++b) {
            const Array block = blocks[b];
            const Vector2 low = block[0];
            const Vector2 high = block[1];
            const double bound = pos.distance_squared_to(pos.clamp(low, high));
            if (bound > best + std::max(0.001, std::abs(best) * 0.0001)) {
                continue;
            }
            const PackedInt64Array ids = block[2];
            const PackedVector2Array points = block[3];
            const int64_t *id_data = ids.ptr();
            const Vector2 *point_data = points.ptr();
            const int64_t count = ids.size();
            for (int64_t i = 0; i < count; ++i) {
                const int64_t id = id_data[i];
                if (missile && focused && id != focus_id) {
                    continue;
                }
                const double distance = pos.distance_squared_to(point_data[i]);
                const bool take = missile ? distance <= best :
                    (distance < best || (Math::is_equal_approx(distance, best) &&
                                        (target < 0 || id < target)));
                if (take) {
                    best = distance;
                    target = id;
                }
            }
        }
        Array result;
        result.append(best);
        result.append(target);
        return result;
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("laser_block_nearest", "blocks", "pos", "best", "target"),
                             &WarboundNativeKernels::laser_block_nearest);
        ClassDB::bind_method(D_METHOD("missile_block_nearest", "blocks", "pos", "best", "target", "focused", "focus_id"),
                             &WarboundNativeKernels::missile_block_nearest);
    }

public:
    Array laser_block_nearest(const Array &blocks, Vector2 pos, double best, int64_t target) const {
        return nearest(blocks, pos, best, target, false, false, -1);
    }

    Array missile_block_nearest(const Array &blocks, Vector2 pos, double best, int64_t target,
                                bool focused, int64_t focus_id) const {
        return nearest(blocks, pos, best, target, true, focused, focus_id);
    }
};

static void initialize(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        GDREGISTER_CLASS(WarboundNativeKernels);
    }
}
static void uninitialize(ModuleInitializationLevel) {}

extern "C" GDExtensionBool GDE_EXPORT warbound_kernels_init(
        GDExtensionInterfaceGetProcAddress get_proc_address,
        GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(initialize);
    init.register_terminator(uninitialize);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}

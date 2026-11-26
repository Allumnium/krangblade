#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
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
        ClassDB::bind_method(D_METHOD("contact_batch", "ids", "positions", "previous", "cells", "bounds", "reach", "epsilon"),
                             &WarboundNativeKernels::contact_batch);
        ClassDB::bind_method(D_METHOD("laser_block_nearest", "blocks", "pos", "best", "target"),
                             &WarboundNativeKernels::laser_block_nearest);
        ClassDB::bind_method(D_METHOD("missile_block_nearest", "blocks", "pos", "best", "target", "focused", "focus_id"),
                             &WarboundNativeKernels::missile_block_nearest);
    }

public:
    // Frozen pass. Iterate the same roster, x/y neighborhood and bucket order
    // as the reference; only GDScript applies the resulting movement.
    Array contact_batch(const PackedInt64Array &ids, const PackedVector2Array &positions,
                        const PackedVector2Array &previous, const Dictionary &cells,
                        const Dictionary &bounds, double reach, double epsilon) const {
        const int64_t count = positions.size();
        PackedVector2Array corrections;
        corrections.resize(count);
        corrections.fill(Vector2());
        PackedByteArray touched;
        touched.resize(count);
        touched.fill(0);
        Array order;
        Vector2 *result = corrections.ptrw();
        uint8_t *seen = touched.ptrw();
        const Vector2 *points = positions.ptr();
        const Vector2 *before = previous.ptr();
        const int64_t *stable_ids = ids.ptr();
        const double cutoff = (reach - epsilon) * (reach - epsilon);
        const double margin = std::max(0.001, cutoff * 0.0001);
        for (int64_t i = 0; i < count; ++i) {
            const Vector2 pa = points[i];
            const Vector2i cell(int32_t(std::floor(double(pa.x) / reach)),
                                int32_t(std::floor(double(pa.y) / reach)));
            for (int x = -1; x <= 1; ++x) {
                for (int y = -1; y <= 1; ++y) {
                    const Vector2i key = cell + Vector2i(x, y);
                    if (!bounds.has(key)) continue;
                    const Rect2 box = bounds[key];
                    if (pa.distance_squared_to(pa.clamp(box.position, box.get_end())) > cutoff + margin) continue;
                    const Array bucket = cells[key];
                    for (int64_t k = 0; k < bucket.size(); ++k) {
                        const int64_t j = bucket[k];
                        if (j <= i) continue;
                        const Vector2 offset = pa - points[j];
                        if (offset.length_squared() >= cutoff) continue;
                        const double distance = offset.length();
                        Vector2 direction;
                        if (distance <= epsilon) {
                            const Vector2 prior = before[i] - before[j];
                            // Modular arithmetic also avoids signed overflow for large IDs.
                            const int64_t angle = ((stable_ids[i] % 360 * 97 + stable_ids[j] % 360 * 193) % 360 + 360) % 360;
                            direction = prior.length_squared() > epsilon ? prior.normalized().orthogonal() :
                                Vector2::from_angle(real_t(double(angle) * 3.14159265358979323846 / 180.0));
                        } else {
                            direction = offset / real_t(distance);
                        }
                        const Vector2 push = direction * real_t(reach - distance) * real_t(0.12);
                        if (!seen[i]) { seen[i] = 1; order.append(i); }
                        if (!seen[j]) { seen[j] = 1; order.append(j); }
                        result[i] += push;
                        result[j] -= push;
                    }
                }
            }
        }
        Array out;
        out.append(corrections);
        out.append(order);
        return out;
    }

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

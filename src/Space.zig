pub const t = @import("numtypes.zig");
const std = @import("std");

iterations: u8,
gravity: t.Vect3,
damping: t.Float,
current_dt: t.Float,
idle_speed_threshold: t.Float,
sleep_speed_threshold: t.Float,

const SpaceInitOptions = struct {
    iterations: u8 = 10,
    gravity: t.Vect3 = [_]t.Float{ 0, 0, 0 },
    damping: t.Float = 1.0,
    idle_speed_threshold: t.Float = 0,
    sleep_speed_threshold: t.Float = std.math.inf(t.Float),
};

pub fn init(ally: std.mem.Allocator, options: SpaceInitOptions) !*@This() {
    var mem = try ally.create(@This());
    mem.iterations = options.iterations;
    mem.gravity = options.gravity;
    mem.damping = options.damping;
    mem.idle_speed_threshold = options.idle_speed_threshold;
    mem.sleep_speed_threshold = options.sleep_speed_threshold;

    mem.current_dt = 0;

    return mem;
}

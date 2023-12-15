const std = @import("std");

pub fn initalizeSpace(ally: std.mem.Allocator) !void {
    _ = ally;
}

test {
    _ = @import("data_structures/Grid.zig");
    _ = @import("data_structures/FreeList.zig").FreeList(u8, 4);
    _ = @import("data_structures/FreeList.zig");
    _ = @import("data_structures/OctTree.zig");
    _ = @import("Space.zig");

    std.testing.expect(block: {
        initalizeSpace(std.testing.allocator) catch break :block false;
        break :block true;
    }) catch @panic("OOM from initializing a space.");
}

const std = @import("std");

pub fn initalizeSpace(ally: std.mem.Allocator) !void {
    _ = ally;
}

test {
    std.testing.refAllDeclsRecursive(@import("data_structures/Grid.zig"));
    std.testing.refAllDeclsRecursive(@import("data_structures/FreeList.zig"));
    std.testing.refAllDeclsRecursive(@import("data_structures/OctTree.zig"));
    std.testing.refAllDeclsRecursive(@import("Space.zig"));

    std.testing.expect(block: {
        initalizeSpace(std.testing.allocator) catch break :block false;
        break :block true;
    }) catch @panic("OOM from initializing a space.");
}

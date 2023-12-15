const std = @import("std");
const testing = @import("std").testing;
const phyzig = @import("phyzig.zig");

test {
    testing.expect(block: {
        phyzig.initalizeSpace(testing.allocator) catch break :block false;
        break :block true;
    }) catch @panic("OOM from initializing a space.");
}

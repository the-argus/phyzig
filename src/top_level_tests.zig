const std = @import("std");
const testing = @import("std").testing;
const phyzig = @import("phyzig.zig");

test {
    testing.expect(block: {
        phyzig.initalizeSpace(testing.allocator) catch break :block false;
        break :block true;
    }) catch @panic("OOM from initializing a space.");
}

test "octtree" {
    const ot = @import("data_structures/OctTree.zig");
    var node: ot.Node = .{};
    node.makeEmpty();
    std.testing.expect(node.isEmpty()) catch @panic("makeEmpty does not match with isEmpty.");
    std.testing.expect(!node.isLeaf()) catch @panic("Empty node is considered a leaf, but it shouldn't be");
}

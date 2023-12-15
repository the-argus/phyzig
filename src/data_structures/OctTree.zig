const std = @import("std");
const t = @import("../numtypes.zig");

/// octtree based on writeup of quadtree from
/// https://stackoverflow.com/questions/41946007/efficient-and-well-explained-implementation-of-a-quadtree-for-2d-collision-det
/// Index numerical type. Could be a smaller unsigned integer if preferred
pub const Index = u32;
/// Numerical type use for counting nodes. Should usually be the same as the
/// index type
pub const Count = Index;
/// The integer type used for counting how many layers deep a node is in the
/// octtree
pub const Depth = u8;

// this isn't meant to be changed, just to reduce amount of magic numbers.
// some parts of the OCT-tree implementation rely on this being 8, believe it
// or not.
pub const Degree = 8;

pub const Node = struct {
    first_child: ?Index = null,
    // TODO: make OctTree a function accepting some options, one of
    // those being to use an implementation that doesn't keep track
    // of count (the number of children it has, if its a leaf node).
    count: ?Count = null,

    pub fn isLeaf(self: @This()) bool {
        return self.count != null;
    }

    pub fn isEmpty(self: @This()) bool {
        return self.first_child == null and self.count == 0;
    }

    pub fn makeEmpty(self: *@This()) void {
        self.first_child = null;
        self.count = 0;
    }
};

/// A bounding box defined by a center point and a width, height, and depth
pub const CenterBounding = struct {
    pos: t.Vect3,
    size: t.Vect3,
};

/// A bounding box defined by a top (more positive) corner and bottom (more
/// negative) corner.
pub const OctTreeBounds = struct {
    top: t.Vect3,
    bottom: t.Vect3,

    pub fn assertValid(self: @This()) void {
        const status = self.top > self.bottom;
        std.debug.assert(status[0]);
        std.debug.assert(status[1]);
        std.debug.assert(status[2]);
    }
};

/// A way of referring to nodes, primarily used during traversal of the tree
/// (for example, center_bounding can only be calculated given the parent node's
/// center_bounding)
pub const NodeData = struct {
    index: Index,
    center_bounding: CenterBounding,
    depth: Depth,
};

pub const NodeList = std.ArrayList(Node);
pub const NodeDataList = std.ArrayList(NodeData);

// struct fields
ally: std.mem.Allocator,
nodes: NodeList,
free_index_stack: std.ArrayList(Index),
free_node: ?Index,

pub fn init(ally: std.mem.Allocator) !@This() {
    var nodes = NodeList.init(ally);
    // initialize with one root node
    // TODO: probably reserve initial memory
    try nodes.append(.{});
    return .{
        .ally = ally,
        .nodes = nodes,
        .free_index_stack = std.ArrayList(Index).init(ally),
        .free_node = null,
    };
}

pub fn deinit(self: *@This()) void {
    self.nodes.deinit();
    self.free_index_stack.deinit();
}

pub fn root(self: *@This()) *Node {
    std.debug.assert(self.nodes.items.len >= 1);
    return &self.nodes.items[0];
}

/// Traverses the nodes in the tree and finds all leaves within a given bounds.
/// Returns them as an owned list of NodeData, to be freed with user_allocator
pub fn findLeaves(
    self: @This(),
    user_allocator: std.mem.Allocator,
    root_of_search: NodeData,
    bounds: OctTreeBounds,
) !NodeDataList {
    bounds.assertValid();
    var leaves = NodeDataList.init(user_allocator);
    var nodes_to_process = NodeDataList.init(self.ally);
    defer nodes_to_process.deinit();
    errdefer leaves.deinit();

    try nodes_to_process.append(root_of_search);

    while (nodes_to_process.items.len > 0) {
        const top_node = nodes_to_process.pop();
        if (self.nodes.items[top_node.index].isLeaf()) {
            try leaves.append(top_node);
        } else {
            const mx = top_node.center_bounding.pos[0];
            const my = top_node.center_bounding.pos[1];
            const mz = top_node.center_bounding.pos[2];
            const half_x = top_node.center_bounding.size[0] / 2;
            const half_y = top_node.center_bounding.size[1] / 2;
            const half_z = top_node.center_bounding.size[2] / 2;

            const first_child = self.nodes.items[top_node.index].first_child.?;
            const left = mx - half_x;
            const top = my - half_y;
            const front = mz - half_z;
            const right = mx + half_x;
            const bottom = my + half_y;
            const back = mz + half_z;

            if (bounds.bottom[2] <= mz) {
                if (bounds.bottom[1] <= my) {
                    if (bounds.bottom[0] <= mx) {
                        // most negative quadrant
                        try nodes_to_process.append(.{
                            .index = first_child + 0,
                            .depth = top_node.depth + 1,
                            .center_bounding = CenterBounding{
                                .pos = t.Vect3{ left, top, front },
                                .size = t.Vect3{ half_x, half_y, half_z },
                            },
                        });
                    }
                    if (bounds.top[0] > mx) {
                        // most negative except for on X
                        try nodes_to_process.append(.{
                            .index = first_child + 1,
                            .depth = top_node.depth + 1,
                            .center_bounding = CenterBounding{
                                .pos = t.Vect3{ right, top, front },
                                .size = t.Vect3{ half_x, half_y, half_z },
                            },
                        });
                    }
                }
                if (bounds.top[1] > my) {
                    if (bounds.bottom[0] <= mx) {
                        // most negative on z and x, but y is more positive
                        try nodes_to_process.append(.{
                            .index = first_child + 2,
                            .depth = top_node.depth + 1,
                            .center_bounding = CenterBounding{
                                .pos = t.Vect3{ left, bottom, front },
                                .size = t.Vect3{ half_x, half_y, half_z },
                            },
                        });
                    }
                    if (bounds.top[0] > mx) {
                        // most negative only on z
                        try nodes_to_process.append(.{
                            .index = first_child + 3,
                            .depth = top_node.depth + 1,
                            .center_bounding = CenterBounding{
                                .pos = t.Vect3{ right, bottom, front },
                                .size = t.Vect3{ half_x, half_y, half_z },
                            },
                        });
                    }
                }
            }

            if (bounds.bottom[2] > mz) {
                if (bounds.bottom[1] <= my) {
                    if (bounds.bottom[0] <= mx) {
                        try nodes_to_process.append(.{
                            .index = first_child + 0,
                            .depth = top_node.depth + 1,
                            .center_bounding = CenterBounding{
                                .pos = t.Vect3{ left, top, back },
                                .size = t.Vect3{ half_x, half_y, half_z },
                            },
                        });
                    }
                    if (bounds.top[0] > mx) {
                        try nodes_to_process.append(.{
                            .index = first_child + 1,
                            .depth = top_node.depth + 1,
                            .center_bounding = CenterBounding{
                                .pos = t.Vect3{ right, top, back },
                                .size = t.Vect3{ half_x, half_y, half_z },
                            },
                        });
                    }
                }
                if (bounds.top[1] > my) {
                    if (bounds.bottom[0] <= mx) {
                        try nodes_to_process.append(.{
                            .index = first_child + 2,
                            .depth = top_node.depth + 1,
                            .center_bounding = CenterBounding{
                                .pos = t.Vect3{ left, bottom, back },
                                .size = t.Vect3{ half_x, half_y, half_z },
                            },
                        });
                    }
                    if (bounds.top[0] > mx) {
                        try nodes_to_process.append(.{
                            .index = first_child + 3,
                            .depth = top_node.depth + 1,
                            .center_bounding = CenterBounding{
                                .pos = t.Vect3{ right, bottom, back },
                                .size = t.Vect3{ half_x, half_y, half_z },
                            },
                        });
                    }
                }
            }
        }
    }
    return leaves;
}

/// Remove unused nodes from the tree
pub fn cleanup(self: *@This()) !void {
    var nodes_to_process = std.ArrayList(Index).init(self.ally);
    defer nodes_to_process.deinit();

    if (!self.root().isLeaf()) {
        try nodes_to_process.append(0);
    }

    while (nodes_to_process.items.len > 0) {
        const node_index = nodes_to_process.pop();
        var node = &self.nodes.items[node_index];
        std.debug.assert(node.first_child != null);

        var num_empty_leaves: Count = 0;

        for (0..Degree) |index| {
            const child_index = node.first_child.? + index;
            const child = &self.nodes.items[child_index];

            if (child.count) |count| {
                if (count == 0) num_empty_leaves += 1;
            } else {
                try nodes_to_process.append(@intCast(child_index));
            }
        }

        // if all children were empty leaves, remove em, this node is now the
        // empty leaf
        if (num_empty_leaves == Degree) {
            self.nodes.items[node.first_child.?].first_child = self.free_node orelse null;
            self.free_node = node.first_child;

            node.makeEmpty();
        }
    }
}

test "makeEmpty and isEmpty match" {
    var node: Node = .{};
    node.makeEmpty();
    std.testing.expect(node.isEmpty()) catch @panic("makeEmpty does not match with isEmpty.");
    std.testing.expect(!node.isLeaf()) catch @panic("Empty node is considered a leaf, but it shouldn't be");
}

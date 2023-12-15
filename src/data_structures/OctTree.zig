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
    first_child: ?Index,
    // TODO: make OctTree a function accepting some options, one of
    // those being to use an implementation that doesn't keep track
    // of count (the number of children it has, if its a leaf node).
    count: ?Count,
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
        std.debug.assert(self.top > self.bottom);
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

pub fn init(ally: std.mem.Allocator) @This() {
    return .{
        .ally = ally,
        .nodes = NodeList.init(ally),
    };
}

/// Traverses the nodes in the tree and finds all leaves within a given bounds.
/// Returns them as an owned list of NodeData, to be freed with user_allocator
pub fn findLeaves(self: @This(), user_allocator: std.mem.Allocator, root: NodeData, bounds: OctTreeBounds) !NodeDataList {
    bounds.assertValid();
    var leaves = NodeDataList.init(user_allocator);
    var nodes_to_process = NodeDataList.init(self.ally);
    defer nodes_to_process.deinit();
    errdefer leaves.deinit();

    try nodes_to_process.append(root);

    while (nodes_to_process.items.len > 0) {
        const top_node = nodes_to_process.getLast();
        if (self.nodes.items[top_node.index].count) {
            // only leaves have counts
            try leaves.append(top_node);
        } else {
            const mx = top_node.center_bounding.pos[0];
            const my = top_node.center_bounding.pos[1];
            const mz = top_node.center_bounding.pos[2];
            const half_x = top_node.center_bounding.size[0] / 2;
            const half_y = top_node.center_bounding.size[1] / 2;
            const half_z = top_node.center_bounding.size[2] / 2;

            const first_child = self.nodes.items[top_node.index].first_child;
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
                            .depth = top.depth + 1,
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
                            .depth = top.depth + 1,
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
                            .depth = top.depth + 1,
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
                            .depth = top.depth + 1,
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
                            .depth = top.depth + 1,
                            .center_bounding = CenterBounding{
                                .pos = t.Vect3{ left, top, back },
                                .size = t.Vect3{ half_x, half_y, half_z },
                            },
                        });
                    }
                    if (bounds.top[0] > mx) {
                        try nodes_to_process.append(.{
                            .index = first_child + 1,
                            .depth = top.depth + 1,
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
                            .depth = top.depth + 1,
                            .center_bounding = CenterBounding{
                                .pos = t.Vect3{ left, bottom, back },
                                .size = t.Vect3{ half_x, half_y, half_z },
                            },
                        });
                    }
                    if (bounds.top[0] > mx) {
                        try nodes_to_process.append(.{
                            .index = first_child + 3,
                            .depth = top.depth + 1,
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
    return user_allocator;
}

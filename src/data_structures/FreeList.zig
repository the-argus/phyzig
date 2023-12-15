/// A dynamically-allocated array type which can keep track of free spaces,
/// and only reallocates when no free spaces are left.
const std = @import("std");
const builtin = @import("builtin");

pub fn FreeList(comptime T: type, comptime index_size_bits: u16) type {
    const IndexT = std.meta.Int(.unsigned, index_size_bits);
    const Element = union {
        item: T,
        next: ?IndexT,
    };

    return struct {
        pub const FreeListError = error{IndexOutOfRange};
        pub const MaxPossibleSize = std.math.inf(IndexT);

        items: std.ArrayList(Element),
        first_free: ?IndexT,

        pub fn init(ally: std.mem.Allocator, initial_reservation: usize) !@This() {
            std.debug.assert(initial_reservation < MaxPossibleSize);
            var items = std.ArrayList(Element).init(ally);
            errdefer items.deinit();
            // perform allocation then set size back to 0, reservation
            try items.resize(initial_reservation);
            try items.resize(0);
            return .{
                .items = items,
                .first_free = null,
            };
        }

        /// inserts an item and returns the index. O(1) time.
        /// may cause reallocation.
        pub fn append(self: *@This(), item: T) !IndexT {
            if (self.first_free) |first_free| {
                std.debug.assert(first_free < self.items.items.len);
                const index = first_free;
                first_free = self.items.items[first_free].next;
                self.items.items[index] = .{ .item = item };
                return index;
            } else {
                var new = try self.items.addOne();
                new = .{ .item = item };
                return self.items.items.len - 1;
            }
        }

        pub fn erase(self: *@This(), index: IndexT) void {
            self.items.items[index] = .{ .next = self.first_free };
            self.first_free = index;
        }

        pub fn clear(self: *@This()) void {
            self.first_free = null;
            self.items.resize(0);
        }

        pub fn get(self: *@This(), index: IndexT) *T {
            std.debug.assert(index < self.items.len);
            return &self.items[index];
        }
    };
}

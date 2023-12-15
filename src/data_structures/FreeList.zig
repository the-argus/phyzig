/// A dynamically-allocated array type which can keep track of free spaces,
/// and only reallocates when no free spaces are left.
const std = @import("std");
const builtin = @import("builtin");

pub fn FreeList(comptime T: type, comptime index_size_bits: u16) type {
    const IndexT = std.meta.Int(.unsigned, index_size_bits);
    const Element = union(enum) {
        item: T,
        next: ?IndexT,
    };

    return struct {
        pub const FreeListType = @This(); // for use in subtypes
        pub const FreeListError = error{IndexOutOfRange};
        const max_possible_size = std.math.maxInt(IndexT);

        // TODO: use this to determine whether functions like Iterator.next()
        // pass by reference. benchmark it. not sure if zig already makes this
        // optimization in release mode
        //
        // const passes_by_reference = @sizeOf(T) > @sizeOf(*T);

        pub const Iterator = struct {
            parent: *FreeListType,
            index: IndexT = 0,

            /// Increment this iterator to the next occupied item. If it reaches
            /// the end, it returns null. If a FreeList is empty, its iterator
            /// will always return null.
            /// Items in a FreeList do not iterate in order of insertion.
            pub fn next(self: *@This()) ?*T {
                std.debug.assert(self.index < self.parent.items.items.len);
                const scan_begin = self.index + 1;
                if (scan_begin >= self.parent.items.items.len) return null;
                for (self.parent.items.items[scan_begin..], scan_begin..) |*potential_item, index| {
                    switch (potential_item) {
                        .next => continue,
                        .item => {
                            self.index = index;
                            return potential_item;
                        },
                    }
                }
                return null;
            }

            /// Create an iterator, even if there are no elements in the parent.
            pub fn create(parent: *FreeListType) @This() {
                var res = @This(){
                    .parent = parent,
                };

                // make sure the item at the index is valid to begin with
                switch (parent.items.items[res.index]) {
                    .next => _ = res.next(),
                    .item => {},
                }
                return res;
            }
        };

        items: std.ArrayList(Element),
        first_free: ?IndexT,

        pub fn init(ally: std.mem.Allocator, initial_reservation: usize) !@This() {
            std.debug.assert(initial_reservation < max_possible_size);
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

        pub fn deinit(self: *@This()) void {
            self.items.deinit();
        }

        pub fn getIter(self: *@This()) Iterator {
            return .{
                .parent = self,
            };
        }

        /// inserts an item and returns the index. O(1) time.
        /// may cause reallocation.
        pub fn append(self: *@This(), item: T) !IndexT {
            if (self.first_free) |first_free| {
                std.debug.assert(first_free < self.items.items.len);
                const index = first_free;
                self.first_free = self.items.items[first_free].next;
                self.items.items[index] = .{ .item = item };
                return index;
            } else {
                var new = try self.items.addOne();
                new.* = .{ .item = item };
                return @intCast(self.items.items.len - 1);
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

test "creation of freelist" {
    std.log.debug("running freelist tests...", .{});
    const fltype = FreeList(u8, 4);

    var flist = try fltype.init(std.testing.allocator, 512);
    std.testing.expect(flist.items.capacity == 512) catch @panic("memory reservation of FreeList does not work as expected");
    defer flist.deinit();
}

test "insertion into freelist" {
    const fltype = FreeList(u8, 4);

    var flist = try fltype.init(std.testing.allocator, 512);
    defer flist.deinit();

    _ = try flist.append('h');
    _ = try flist.append('e');
    _ = try flist.append('l');
    _ = try flist.append('l');
    _ = try flist.append('o');

    for (flist.items.items, 0..) |element, index| {
        std.testing.expect(element.item == "hello"[index]) catch @panic("FreeList does insert in the expected way");
    }
}

test "insertion and deletion into freelist" {
    const fltype = FreeList(u8, 4);

    var flist = try fltype.init(std.testing.allocator, 512);
    defer flist.deinit();

    _ = try flist.append('h');
    const to_remove = try flist.append('e');
    _ = try flist.append('l');
    _ = try flist.append('l');
    const o = try flist.append('o');

    // remove the "e"
    flist.erase(to_remove);

    std.testing.expect(flist.items.items[to_remove] == .next) catch @panic("FreeList erased items do not become indices");
    std.testing.expect(flist.items.items[o].item == 'o') catch @panic("FreeList move around items unexpectedly");
}

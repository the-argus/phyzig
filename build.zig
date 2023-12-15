const std = @import("std");
const builtin = @import("builtin");

const test_srcs = &[_][]const u8{
    "src/top_level_tests.zig",
    "src/data_structures/OctTree.zig",
    "src/data_structures/FreeList.zig",
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tests_step = b.step("test", "Run all phyzig tests.");

    for (test_srcs) |test_src_file| {
        const teststep = b.addTest(.{
            .optimize = optimize,
            .target = target,
            .root_source_file = .{ .path = test_src_file },
        });
        tests_step.dependOn(&teststep.step);
    }

    _ = b.addModule("phyzig", .{
        .source_file = .{ .path = "src/phyzig.zig" },
        .dependencies = &[_]std.Build.ModuleDependency{},
    });
}

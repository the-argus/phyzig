const std = @import("std");
const builtin = @import("builtin");

///
///Much of this is stolen from
///https://github.com/mitchellh/libxev/blob/main/build.zig
///
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const top_level_tests = b.addTest(.{
        .optimize = optimize,
        .target = target,
        .root_source_file = .{ .path = "src/top_level_tests.zig" },
    });

    const tests_step = b.step("test", "Run the top-level phyzig tests.");
    tests_step.dependOn(&top_level_tests.step);

    _ = b.addModule("phyzig", .{
        .source_file = .{ .path = "src/phyzig.zig" },
        .dependencies = &[_]std.Build.ModuleDependency{},
    });
}

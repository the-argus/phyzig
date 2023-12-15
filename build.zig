const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tests_step = b.step("test", "Run all phyzig tests.");

    const teststep = b.addTest(.{
        .optimize = optimize,
        .target = target,
        .root_source_file = .{ .path = "src/phyzig.zig" },
    });
    tests_step.dependOn(&teststep.step);

    _ = b.addModule("phyzig", .{
        .source_file = .{ .path = "src/phyzig.zig" },
        .dependencies = &[_]std.Build.ModuleDependency{},
    });
}

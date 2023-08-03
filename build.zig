const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    _ = b.addModule("mach-opus", .{ .source_file = .{ .path = "src/lib.zig" } });

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libopusfile_dep = b.dependency("opusfile", .{ .target = target, .optimize = optimize });

    const main_test = b.addTest(.{
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_test.linkLibrary(libopusfile_dep.artifact("opusfile"));
    main_test.main_pkg_path = .{ .path = "." };

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(main_test).step);
}

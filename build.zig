const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const opusfile_dep = b.dependency("opusfile", .{
        .target = target,
        .optimize = optimize,
    });
    const opusenc_dep = b.dependency("opusenc", .{
        .target = target,
        .optimize = optimize,
    });

    const module = b.addModule("mach-opus", .{
        .root_source_file = b.path("src/lib.zig"),
    });
    module.linkLibrary(opusfile_dep.artifact("opusfile"));
    module.linkLibrary(opusenc_dep.artifact("opusenc"));

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(main_tests).step);
}

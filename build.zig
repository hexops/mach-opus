const std = @import("std");
const builtin = @import("builtin");
const sysaudio = @import("mach_sysaudio");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sysaudio_dep = b.dependency("mach_sysaudio", .{
        .target = target,
        .optimize = optimize,
    });
    const opusfile_dep = b.dependency("opusfile", .{
        .target = target,
        .optimize = optimize,
    });
    const opusenc_dep = b.dependency("opusenc", .{
        .target = target,
        .optimize = optimize,
    });

    const module = b.addModule("mach-opus", .{
        .root_source_file = .{ .path = "src/lib.zig" },
    });
    module.linkLibrary(opusfile_dep.artifact("opusfile"));
    module.linkLibrary(opusenc_dep.artifact("opusenc"));

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });
    addPaths(main_tests);
    b.installArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(main_tests).step);

    const example = b.addExecutable(.{
        .name = "example-play",
        .root_source_file = .{ .path = "examples/play.zig" },
        .target = target,
        .optimize = optimize,
    });
    example.root_module.addImport("mach-opus", module);
    example.root_module.addImport("mach-sysaudio", sysaudio_dep.module("mach-sysaudio"));
    addPaths(example);
    b.installArtifact(example);

    const example_run_cmd = b.addRunArtifact(example);
    example_run_cmd.step.dependOn(b.getInstallStep());

    const example_run_step = b.step("run-example", "Run example");
    example_run_step.dependOn(&example_run_cmd.step);
}

pub fn addPaths(step: *std.Build.Step.Compile) void {
    sysaudio.addPaths(step);
}

pub fn link(b: *std.Build, step: *std.Build.Step.Compile) void {
    _ = b;
    _ = step;
    @panic("link(b, step) has been deprecated, use addPaths(step) instead");
}

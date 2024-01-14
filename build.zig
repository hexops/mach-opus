const std = @import("std");
const builtin = @import("builtin");
const sysaudio = @import("mach_sysaudio");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("mach-opus", .{ .source_file = .{ .path = "src/lib.zig" } });

    const sysaudio_dep = b.dependency("mach_sysaudio", .{ .target = target, .optimize = optimize });

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });
    link(b, main_tests);
    b.installArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(main_tests).step);

    const example = b.addExecutable(.{
        .name = "example-play",
        .root_source_file = .{ .path = "examples/play.zig" },
        .target = target,
        .optimize = optimize,
    });
    link(b, example);
    example.addModule("mach-opus", module);
    example.addModule("mach-sysaudio", sysaudio_dep.module("mach-sysaudio"));
    sysaudio.link(b, example);
    b.installArtifact(example);

    const example_run_cmd = b.addRunArtifact(example);
    example_run_cmd.step.dependOn(b.getInstallStep());

    const example_run_step = b.step("run-example", "Run example");
    example_run_step.dependOn(&example_run_cmd.step);
}

pub fn link(b: *std.Build, step: *std.build.CompileStep) void {
    const opusfile_dep = b.dependency("opusfile", .{ .target = step.target, .optimize = step.optimize });
    const opusenc_dep = b.dependency("opusenc", .{ .target = step.target, .optimize = step.optimize });
    step.linkLibrary(opusfile_dep.artifact("opusfile"));
    step.linkLibrary(opusenc_dep.artifact("opusenc"));
}

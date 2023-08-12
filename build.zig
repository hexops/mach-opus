const std = @import("std");
const builtin = @import("builtin");
const sysaudio = @import("mach_sysaudio");

pub fn build(b: *std.Build) void {
    const module = b.addModule("mach-opus", .{ .source_file = .{ .path = "src/lib.zig" } });
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const libopusfile_dep = b.dependency("opusfile", .{ .target = target, .optimize = optimize });

    const example = b.addExecutable(.{
        .name = "example-play",
        .root_source_file = .{ .path = "examples/play.zig" },
        .target = target,
        .optimize = optimize,
    });
    example.addModule("opus", module);
    example.addModule("sysaudio", sysaudio.module(b, optimize, target));
    example.linkLibrary(libopusfile_dep.artifact("opusfile"));
    sysaudio.link(b, example, .{});
    b.installArtifact(example);

    const example_run_cmd = b.addRunArtifact(example);
    example_run_cmd.step.dependOn(b.getInstallStep());

    const example_run_step = b.step("run-example", "Run example");
    example_run_step.dependOn(&example_run_cmd.step);
}

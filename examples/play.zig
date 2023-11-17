const std = @import("std");
const sysaudio = @import("mach-sysaudio");
const Opus = @import("mach-opus");

var file_decoded: Opus = undefined;
var player: sysaudio.Player = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ctx = try sysaudio.Context.init(null, allocator, .{});
    defer ctx.deinit();
    try ctx.refresh();
    const device = ctx.defaultDevice(.playback) orelse return error.NoDevice;

    const audio_file = try std.fs.cwd().openFile("examples/assets/time.opus", .{});

    file_decoded = try Opus.decodeStream(allocator, std.io.StreamSource{ .file = audio_file });
    defer allocator.free(file_decoded.samples);
    if (file_decoded.channels > device.channels.len) {
        return error.InvalidDevice;
    }

    // encode the decoded file
    const encoded_file = try std.fs.cwd().createFile("/tmp/time.opus", .{});
    var comments = try Opus.Comments.init();
    defer comments.deinit();
    try Opus.encodeStream(
        std.io.StreamSource{ .file = encoded_file },
        comments,
        file_decoded.sample_rate,
        file_decoded.channels,
        .mono_stereo,
        file_decoded.samples,
    );

    player = try ctx.createPlayer(device, writeCallback, .{});
    defer player.deinit();
    try player.start();

    try player.setVolume(0.75);

    var buf: [16]u8 = undefined;
    while (true) {
        std.debug.print("( paused = {}, volume = {d} )\n> ", .{ player.paused(), try player.volume() });
        const line = (try std.io.getStdIn().reader().readUntilDelimiterOrEof(&buf, '\n')) orelse break;
        var iter = std.mem.split(u8, line, ":");
        const cmd = std.mem.trimRight(u8, iter.first(), &std.ascii.whitespace);
        if (std.mem.eql(u8, cmd, "vol")) {
            var vol = try std.fmt.parseFloat(f32, std.mem.trim(u8, iter.next().?, &std.ascii.whitespace));
            try player.setVolume(vol);
        } else if (std.mem.eql(u8, cmd, "pause")) {
            try player.pause();
            try std.testing.expect(player.paused());
        } else if (std.mem.eql(u8, cmd, "play")) {
            try player.play();
            try std.testing.expect(!player.paused());
        } else if (std.mem.eql(u8, cmd, "exit")) {
            break;
        } else {
            std.debug.print("valid commands: play, pause, exit, vol:<float>; got '{s}'\n", .{cmd});
        }
    }
}

var i: usize = 0;
fn writeCallback(_: ?*anyopaque, output: []u8) void {
    if (i >= file_decoded.samples.len) i = 0;
    const to_write = @min(output.len / player.format().size(), file_decoded.samples.len - i);
    sysaudio.convertTo(
        f32,
        file_decoded.samples[i..][0..to_write],
        player.format(),
        output[0 .. to_write * player.format().size()],
    );
    i += to_write;
}

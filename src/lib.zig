const std = @import("std");
const c = @cImport(@cInclude("opusfile.h"));

const Opus = @This();

channels: u8,
sample_rate: u24,
samples: []f32,

pub const DecodeError = error{
    OutOfMemory,
    InvalidData,
    Reading,
    Seeking,
    UnknownError,
};

pub fn decodeStream(allocator: std.mem.Allocator, stream: std.io.StreamSource) (DecodeError || std.io.StreamSource.ReadError)!Opus {
    var decoder = Decoder{ .allocator = allocator, .stream = stream };
    var err: c_int = 0;
    var opus_file = c.op_open_callbacks(
        &decoder,
        &c.OpusFileCallbacks{
            .read = Decoder.readCallback,
            .seek = Decoder.seekCallback,
            .tell = Decoder.tellCallback,
            .close = null,
        },
        null,
        0,
        &err,
    );
    switch (err) {
        0 => {},
        // An underlying read operation failed. This may signal a truncation attack from an <https:> source.
        c.OP_EREAD => return error.Reading,
        // An internal memory allocation failed.
        c.OP_EFAULT => return error.OutOfMemory,
        // An unseekable stream encountered a new link that used a feature that is not implemented, such as an unsupported channel family.
        c.OP_EIMPL => return error.UnknownError,
        // The stream was only partially open.
        c.OP_EINVAL => return error.Seeking,
        // An unseekable stream encountered a new link that did not have any logical Opus streams in it.
        c.OP_ENOTFORMAT => return error.UnknownError,
        // An unseekable stream encountered a new link with a required header packet that was not properly formatted, contained illegal values, or was missing altogether.
        c.OP_EBADHEADER => return error.InvalidData,
        // An unseekable stream encountered a new link with an ID header that contained an unrecognized version number.
        c.OP_EVERSION => return error.InvalidData,
        // We failed to find data we had seen before.
        c.OP_EBADLINK => return error.Seeking,
        // An unseekable stream encountered a new link with a starting timestamp that failed basic validity checks.
        c.OP_EBADTIMESTAMP => return error.InvalidData,
        else => return error.UnknownError,
    }

    const header = c.op_head(opus_file, 0);
    const channels: u8 = @intCast(header.*.channel_count);
    const sample_rate: u24 = @intCast(header.*.input_sample_rate);
    const total_samples: usize = @intCast(c.op_pcm_total(opus_file, -1));
    var samples = try allocator.alloc(f32, total_samples * channels);
    errdefer allocator.free(samples);

    var i: usize = 0;
    while (i < samples.len) {
        const read = c.op_read_float(opus_file, samples[i..].ptr, @intCast(samples.len - i), null);
        if (read == 0) break else if (read < 0) return error.InvalidData;
        i += @intCast(read * channels);
    }

    return .{
        .channels = channels,
        .sample_rate = sample_rate,
        .samples = samples,
    };
}

const Decoder = struct {
    allocator: std.mem.Allocator,
    stream: std.io.StreamSource,
    samples: []f32 = &.{},
    sample_index: usize = 0,

    fn readCallback(decoder_opaque: ?*anyopaque, ptr: [*c]u8, nbytes: c_int) callconv(.C) c_int {
        const decoder: *Decoder = @ptrCast(@alignCast(decoder_opaque));
        return @intCast(decoder.stream.read(ptr[0..@intCast(nbytes)]) catch unreachable);
    }

    fn seekCallback(decoder_opaque: ?*anyopaque, offset: i64, whence: c_int) callconv(.C) c_int {
        const decoder: *Decoder = @ptrCast(@alignCast(decoder_opaque));
        switch (whence) {
            c.SEEK_SET => decoder.stream.seekTo(@intCast(offset)) catch return -1,
            c.SEEK_CUR => decoder.stream.seekBy(offset) catch return -1,
            c.SEEK_END => decoder.stream.seekTo(decoder.stream.getEndPos() catch return -1) catch return -1,
            else => unreachable,
        }
        return 0;
    }

    fn tellCallback(decoder_opaque: ?*anyopaque) callconv(.C) i64 {
        const decoder: *Decoder = @ptrCast(@alignCast(decoder_opaque));
        return @intCast(decoder.stream.getPos() catch 0);
    }
};

const std = @import("std");
const c = @import("c");

export fn base64_encode(src: [*c]const u8, src_len: usize) callconv(.c) [*c]u8 {
    std.debug.assert(src != null);

    const encoder = std.base64.standard.Encoder;
    const out_len = encoder.calcSize(src_len);

    const dest_ptr = c.xmalloc(out_len + 1);
    const dest = @as([*]u8, @ptrCast(dest_ptr));

    const src_slice = src[0..src_len];
    _ = encoder.encode(dest[0..out_len], src_slice);

    dest[out_len] = 0; // null terminator
    return @ptrCast(dest_ptr);
}

export fn base64_decode(src: [*c]const u8, src_len: usize, out_lenp: [*c]usize) callconv(.c) [*c]u8 {
    std.debug.assert(src != null);
    std.debug.assert(out_lenp != null);

    const decoder = std.base64.standard.Decoder;
    const src_slice = src[0..src_len];

    const out_len = decoder.calcSizeForSlice(src_slice) catch {
        out_lenp.* = 0;
        return null;
    };

    const dest_ptr = c.xmalloc(out_len);
    const dest = @as([*]u8, @ptrCast(dest_ptr));

    decoder.decode(dest[0..out_len], src_slice) catch {
        c.xfree(dest_ptr);
        out_lenp.* = 0;
        return null;
    };

    out_lenp.* = out_len;
    return @ptrCast(dest_ptr);
}

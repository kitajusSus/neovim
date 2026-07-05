const std = @import("std");
const c = @import("c");

inline fn s0(x: u32) u32 {
    return std.math.rotr(u32, x, 7) ^ std.math.rotr(u32, x, 18) ^ (x >> 3);
}

inline fn s1(x: u32) u32 {
    return std.math.rotr(u32, x, 17) ^ std.math.rotr(u32, x, 19) ^ (x >> 10);
}

inline fn s2(x: u32) u32 {
    return std.math.rotr(u32, x, 2) ^ std.math.rotr(u32, x, 13) ^ std.math.rotr(u32, x, 22);
}

inline fn s3(x: u32) u32 {
    return std.math.rotr(u32, x, 6) ^ std.math.rotr(u32, x, 11) ^ std.math.rotr(u32, x, 25);
}

inline fn f0(x: u32, y: u32, z: u32) u32 {
    return (x & y) | (z & (x | y));
}

inline fn f1(x: u32, y: u32, z: u32) u32 {
    return z ^ (x & (y ^ z));
}

fn sha256_process(ctx: *c.context_sha256_T, data: [*]const u8) void {
    var W: [64]u32 = undefined;
    for (0..16) |i| {
        W[i] = std.mem.readInt(u32, data[i * 4 ..][0..4], .big);
    }
    for (16..64) |i| {
        W[i] = s1(W[i - 2]) +% W[i - 7] +% s0(W[i - 15]) +% W[i - 16];
    }

    const K = [64]u32{
        0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5, 0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
        0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3, 0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
        0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC, 0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
        0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7, 0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
        0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13, 0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
        0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3, 0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
        0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5, 0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
        0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208, 0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
    };

    var state = [8]u32{
        ctx.state[0], ctx.state[1], ctx.state[2], ctx.state[3],
        ctx.state[4], ctx.state[5], ctx.state[6], ctx.state[7],
    };

    for (0..64) |t| {
        const temp1 = state[7] +% s3(state[4]) +% f1(state[4], state[5], state[6]) +% K[t] +% W[t];
        const temp2 = s2(state[0]) +% f0(state[0], state[1], state[2]);
        state[3] +%= temp1;
        state[7] = temp1 +% temp2;

        const last_val = state[7];
        state[7] = state[6];
        state[6] = state[5];
        state[5] = state[4];
        state[4] = state[3];
        state[3] = state[2];
        state[2] = state[1];
        state[1] = state[0];
        state[0] = last_val;
    }

    ctx.state[0] +%= state[0];
    ctx.state[1] +%= state[1];
    ctx.state[2] +%= state[2];
    ctx.state[3] +%= state[3];
    ctx.state[4] +%= state[4];
    ctx.state[5] +%= state[5];
    ctx.state[6] +%= state[6];
    ctx.state[7] +%= state[7];
}

export fn sha256_start(ctx: ?*c.context_sha256_T) callconv(.c) void {
    const g = ctx orelse return;
    g.total[0] = 0;
    g.total[1] = 0;

    g.state[0] = 0x6A09E667;
    g.state[1] = 0xBB67AE85;
    g.state[2] = 0x3C6EF372;
    g.state[3] = 0xA54FF53A;
    g.state[4] = 0x510E527F;
    g.state[5] = 0x9B05688C;
    g.state[6] = 0x1F83D9AB;
    g.state[7] = 0x5BE0CD19;
}

export fn sha256_update(ctx: ?*c.context_sha256_T, input: [*c]const u8, length: usize) callconv(.c) void {
    const g = ctx orelse return;
    if (length == 0) return;

    var left = g.total[0] & (64 - 1);

    g.total[0] = g.total[0] +% @as(u32, @intCast(length));
    g.total[0] &= 0xFFFFFFFF;

    if (g.total[0] < length) {
        g.total[1] +%= 1;
    }

    const fill = 64 - left;
    var inp = input;
    var len = length;

    if (left != 0 and len >= fill) {
        @memcpy(g.buffer[left..][0..fill], inp[0..fill]);
        sha256_process(g, &g.buffer);
        len -= fill;
        inp += fill;
        left = 0;
    }

    while (len >= 64) {
        sha256_process(g, inp);
        len -= 64;
        inp += 64;
    }

    if (len > 0) {
        @memcpy(g.buffer[left..][0..len], inp[0..len]);
    }
}

const sha256_padding = [64]u8{
    0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

export fn sha256_finish(ctx: ?*c.context_sha256_T, digest: [*c]u8) callconv(.c) void {
    const g = ctx orelse return;
    const high = (g.total[0] >> 29) | (g.total[1] << 3);
    const low = g.total[0] << 3;

    var msglen: [8]u8 = undefined;
    std.mem.writeInt(u32, msglen[0..4], high, .big);
    std.mem.writeInt(u32, msglen[4..8], low, .big);

    const last = g.total[0] & 0x3F;
    const padn = if (last < 56) (56 - last) else (120 - last);

    sha256_update(g, &sha256_padding, padn);
    sha256_update(g, &msglen, 8);

    std.mem.writeInt(u32, digest[0..4], g.state[0], .big);
    std.mem.writeInt(u32, digest[4..8], g.state[1], .big);
    std.mem.writeInt(u32, digest[8..12], g.state[2], .big);
    std.mem.writeInt(u32, digest[12..16], g.state[3], .big);
    std.mem.writeInt(u32, digest[16..20], g.state[4], .big);
    std.mem.writeInt(u32, digest[20..24], g.state[5], .big);
    std.mem.writeInt(u32, digest[24..28], g.state[6], .big);
    std.mem.writeInt(u32, digest[28..32], g.state[7], .big);
}

export fn sha256_bytes(buf: [*c]const u8, buf_len: usize, salt: [*c]const u8, salt_len: usize) callconv(.c) [*c]const u8 {
    const State = struct {
        var hexit: [65]u8 = undefined;
    };

    _ = sha256_self_test();

    var ctx: c.context_sha256_T = undefined;
    sha256_start(&ctx);
    sha256_update(&ctx, buf, buf_len);

    if (salt != null) {
        sha256_update(&ctx, salt, salt_len);
    }
    var sha256sum: [32]u8 = undefined;
    sha256_finish(&ctx, &sha256sum);

    _ = std.fmt.bufPrint(State.hexit[0..64], "{x}", .{&sha256sum}) catch unreachable;
    State.hexit[64] = 0;
    return @ptrCast(&State.hexit);
}

const sha_self_test_msg = [_]?[*:0]const u8{
    "abc",
    "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
    null,
};

const sha_self_test_vector = [_][*:0]const u8{
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
    "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0",
};

export fn sha256_self_test() callconv(.c) bool {
    var output: [65]u8 = undefined;
    var ctx: c.context_sha256_T = undefined;
    var buf: [1000]u8 = undefined;
    var sha256sum: [32]u8 = undefined;

    const State = struct {
        var sha256_self_tested: bool = false;
        var failures: bool = false;
    };

    if (State.sha256_self_tested) {
        return !State.failures;
    }
    State.sha256_self_tested = true;

    for (0..3) |i| {
        if (i < 2) {
            const msg = sha_self_test_msg[i].?;
            const len = std.mem.len(msg);
            const hexit = sha256_bytes(msg, len, null, 0);
            @memcpy(output[0..64], hexit[0..64]);
        } else {
            sha256_start(&ctx);
            @memset(&buf, 'a');

            for (0..1000) |_| {
                sha256_update(&ctx, &buf, 1000);
            }
            sha256_finish(&ctx, &sha256sum);

            _ = std.fmt.bufPrint(output[0..64], "{x}", .{&sha256sum}) catch unreachable;
        }

        const expected = sha_self_test_vector[i][0..64];
        if (!std.mem.eql(u8, output[0..64], expected)) {
            State.failures = true;
        }
    }

    return !State.failures;
}

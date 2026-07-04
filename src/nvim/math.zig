const std = @import("std");
const c = @import("c");

const OK = 1;
const FAIL = 0;

export fn xfpclassify(d: f64) callconv(.c) c_int {
    const m = @as(u64, @bitCast(d));
    const e = @as(c_int, @intCast(0x7ff & (m >> 52)));
    const fraction = 0xfffffffffffff & m;

    return switch (e) {
        0x000 => if (fraction != 0) c.FP_SUBNORMAL else c.FP_ZERO,
        0x7ff => if (fraction != 0) c.FP_NAN else c.FP_INFINITE,
        else => c.FP_NORMAL,
    };
}

export fn xisinf(d: f64) callconv(.c) c_int {
    return if (std.math.isInf(d)) 1 else 0;
}

export fn xisnan(d: f64) callconv(.c) c_int {
    return if (std.math.isNan(d)) 1 else 0;
}

export fn xctz(x: u64) callconv(.c) c_int {
    if (x == 0) {
        return @as(c_int, @intCast(8 * @sizeOf(u64)));
    }
    return @as(c_int, @intCast(@ctz(x)));
}

export fn xpopcount(x: u64) callconv(.c) c_uint {
    return @as(c_uint, @intCast(@popCount(x)));
}

export fn vim_append_digit_int(value: *c_int, digit: c_int) callconv(.c) c_int {
    const x = value.*;
    const int_max = std.math.maxInt(c_int);
    if (x > @divTrunc(int_max - digit, 10)) {
        return FAIL;
    }
    value.* = x * 10 + digit;
    return OK;
}

export fn trim_to_int(x: i64) callconv(.c) c_int {
    const int_max = std.math.maxInt(c_int);
    const int_min = std.math.minInt(c_int);
    return if (x > int_max) int_max else if (x < int_min) int_min else @as(c_int, @intCast(x));
}

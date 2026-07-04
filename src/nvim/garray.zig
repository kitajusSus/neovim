const std = @import("std");
const c = @import("c");

export fn ga_clear(gap: ?*c.garray_T) callconv(.c) void {
    const g = gap orelse return;
    c.xfree(g.ga_data);
    g.ga_data = null;
    g.ga_maxlen = 0;
    g.ga_len = 0;
}

export fn ga_clear_strings(gap: ?*c.garray_T) callconv(.c) void {
    const g = gap orelse return;
    if (g.ga_data) |data| {
        const fnames = @as([*]?*anyopaque, @ptrCast(@alignCast(data)));
        var i: usize = 0;
        const len = @as(usize, @intCast(g.ga_len));
        while (i < len) : (i += 1) {
            c.xfree(fnames[i]);
        }
    }
    ga_clear(g);
}

export fn ga_init(gap: ?*c.garray_T, itemsize: c_int, growsize: c_int) callconv(.c) void {
    const g = gap orelse return;
    g.ga_data = null;
    g.ga_maxlen = 0;
    g.ga_len = 0;
    g.ga_itemsize = itemsize;
    ga_set_growsize(g, growsize);
}

export fn ga_set_growsize(gap: ?*c.garray_T, growsize: c_int) callconv(.c) void {
    const g = gap orelse return;
    if (growsize < 1) {
        _ = c.logmsg(c.LOGLVL_WRN, null, "ga_set_growsize", @src().line, true, "trying to set an invalid ga_growsize: %d", growsize);
        g.ga_growsize = 1;
    } else {
        g.ga_growsize = growsize;
    }
}

export fn ga_grow(gap: ?*c.garray_T, n_in: c_int) callconv(.c) void {
    const g = gap orelse return;
    var n = n_in;
    if (g.ga_maxlen - g.ga_len >= n) {
        return;
    }

    if (g.ga_growsize < 1) {
        _ = c.logmsg(c.LOGLVL_WRN, null, "ga_grow", @src().line, true, "ga_growsize(%d) is less than 1", g.ga_growsize);
    }

    if (n < g.ga_growsize) {
        n = g.ga_growsize;
    }

    const half_len = @divTrunc(g.ga_len, 2);
    if (n < half_len) {
        n = half_len;
    }

    const new_maxlen = g.ga_len + n;

    const new_size = @as(usize, @intCast(g.ga_itemsize)) * @as(usize, @intCast(new_maxlen));
    const old_size = @as(usize, @intCast(g.ga_itemsize)) * @as(usize, @intCast(g.ga_maxlen));

    const pp = c.xrealloc(g.ga_data, new_size);
    const pp_char = @as([*]u8, @ptrCast(pp));
    @memset(pp_char[old_size..new_size], 0);

    g.ga_maxlen = new_maxlen;
    g.ga_data = @ptrCast(pp);
}

export fn ga_remove_duplicate_strings(gap: ?*c.garray_T) callconv(.c) void {
    const g = gap orelse return;
    if (g.ga_data == null or g.ga_len <= 1) return;
    const fnames = @as([*c][*c]u8, @ptrCast(@alignCast(g.ga_data)));

    c.sort_strings(fnames, g.ga_len);

    var i = g.ga_len - 1;
    while (i > 0) {
        const idx = @as(usize, @intCast(i));
        if (c.path_fnamecmp(@ptrCast(fnames[idx - 1]), @ptrCast(fnames[idx])) == 0) {
            c.xfree(fnames[idx]);

            var j = idx + 1;
            const len = @as(usize, @intCast(g.ga_len));
            while (j < len) : (j += 1) {
                fnames[j - 1] = fnames[j];
            }
            g.ga_len -= 1;
        }
        i -= 1;
    }
}

export fn ga_concat_strings(gap: ?*const c.garray_T, sep: [*c]const c_char) callconv(.c) [*c]c_char {
    const g = gap orelse return null;
    const nelem = @as(usize, @intCast(g.ga_len));
    if (nelem == 0) {
        return @ptrCast(c.xstrdup(""));
    }
    const strings = @as([*c]const [*c]const u8, @ptrCast(@alignCast(g.ga_data)));

    var len: usize = 0;
    var i: usize = 0;
    while (i < nelem) : (i += 1) {
        len += c.strlen(strings[i]);
    }

    const sep_ptr: [*c]const u8 = @ptrCast(sep);
    const sep_len = c.strlen(sep_ptr);
    len += (nelem - 1) * sep_len;

    const ret = c.xmallocz(len);
    var s = @as([*c]u8, @ptrCast(ret));

    i = 0;
    while (i < nelem - 1) : (i += 1) {
        s = c.xstpcpy(s, strings[i]);
        s = c.xstpcpy(s, sep_ptr);
    }
    _ = c.strcpy(s, strings[nelem - 1]);

    return @ptrCast(ret);
}

export fn ga_concat(gap: ?*c.garray_T, s: [*c]const c_char) callconv(.c) void {
    if (s == null) return;
    ga_concat_len(gap, s, c.strlen(@ptrCast(s)));
}

export fn ga_concat_len(gap: ?*c.garray_T, s: [*c]const c_char, len: usize) callconv(.c) void {
    const g = gap orelse return;
    if (len == 0) return;
    ga_grow(g, @as(c_int, @intCast(len)));
    const data = @as([*]u8, @ptrCast(g.ga_data));
    const src = @as([*]const u8, @ptrCast(s));
    @memcpy(data[@intCast(g.ga_len)..][0..len], src[0..len]);
    g.ga_len += @as(c_int, @intCast(len));
}

export fn ga_append(gap: ?*c.garray_T, ch: u8) callconv(.c) void {
    const g = gap orelse return;
    ga_grow(g, 1);
    const data = @as([*]u8, @ptrCast(g.ga_data));
    data[@as(usize, @intCast(g.ga_len))] = ch;
    g.ga_len += 1;
}

export fn ga_append_via_ptr(gap: ?*c.garray_T, item_size: usize) callconv(.c) ?*anyopaque {
    const g = gap orelse return null;
    if (@as(c_int, @intCast(item_size)) != g.ga_itemsize) {
        _ = c.logmsg(c.LOGLVL_WRN, null, "ga_append_via_ptr", @src().line, true, "wrong item size (%zu), should be %d", item_size, g.ga_itemsize);
    }
    ga_grow(g, 1);
    const data = @as([*]u8, @ptrCast(g.ga_data));
    const offset = item_size * @as(usize, @intCast(g.ga_len));
    g.ga_len += 1;
    return @ptrCast(&data[offset]);
}

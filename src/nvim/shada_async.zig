const std = @import("std");
const c = @import("c");

extern fn open(pathname: [*c]const u8, flags: c_int) c_int;
extern fn close(fd: c_int) c_int;
extern fn read(fd: c_int, buf: ?*anyopaque, count: usize) isize;
extern fn lseek(fd: c_int, offset: c_long, whence: c_int) c_long;

const O_RDONLY = 0;
const SEEK_END = 2;
const SEEK_SET = 0;

var preload_thread: ?std.Thread = null;
var preload_buffer: ?[]u8 = null;
var preload_filename: ?[:0]const u8 = null;
var preload_err: anyerror!void = {};

fn readThread() void {
    const filename = preload_filename orelse return;

    const fd = open(@ptrCast(filename.ptr), O_RDONLY);
    if (fd < 0) {
        preload_err = error.OpenFailed;
        return;
    }
    defer _ = close(fd);

    const size = lseek(fd, 0, SEEK_END);
    if (size < 0) {
        preload_err = error.SeekFailed;
        return;
    }
    _ = lseek(fd, 0, SEEK_SET);

    const allocator = std.heap.page_allocator;
    const buf = allocator.alloc(u8, @intCast(size)) catch |err| {
        preload_err = err;
        return;
    };

    const bytes_read = read(fd, buf.ptr, buf.len);
    if (bytes_read != buf.len) {
        allocator.free(buf);
        preload_err = error.ShortRead;
        return;
    }

    preload_buffer = buf;
    preload_err = {};
}

export fn shada_async_init() callconv(.c) void {
    const fname_c = c.shada_filename(null);
    if (fname_c == null) return;
    defer c.xfree(fname_c);

    const len = std.mem.len(fname_c);
    const allocator = std.heap.page_allocator;
    const fname = allocator.allocSentinel(u8, len, 0) catch return;
    @memcpy(fname, fname_c[0..len]);
    preload_filename = fname;

    preload_thread = std.Thread.spawn(.{}, readThread, .{}) catch {
        allocator.free(fname);
        preload_filename = null;
        return;
    };
}

export fn shada_async_get_preloaded(requested_file: [*c]const u8, len_out: *usize) callconv(.c) ?*anyopaque {
    const req_fname_c = c.shada_filename(requested_file);
    if (req_fname_c == null) return null;
    defer c.xfree(req_fname_c);

    const req_len = std.mem.len(req_fname_c);
    const req_slice = req_fname_c[0..req_len];

    if (preload_thread) |thread| {
        thread.join();
        preload_thread = null;
    }

    defer {
        if (preload_filename) |fname| {
            std.heap.page_allocator.free(fname);
            preload_filename = null;
        }
    }

    if (preload_filename) |pre_fname| {
        if (std.mem.eql(u8, pre_fname, req_slice)) {
            preload_err catch {
                return null;
            };
            if (preload_buffer) |buf| {
                len_out.* = buf.len;
                return @ptrCast(buf.ptr);
            }
        }
    }

    return null;
}

export fn shada_async_free() callconv(.c) void {
    if (preload_buffer) |buf| {
        std.heap.page_allocator.free(buf);
        preload_buffer = null;
    }
}

var write_thread: ?std.Thread = null;

fn writeThread() void {
    _ = c.shada_write_file(null, false);
}

export fn shada_async_write_start() callconv(.c) void {
    write_thread = std.Thread.spawn(.{}, writeThread, .{}) catch {
        _ = c.shada_write_file(null, false);
        return;
    };
}

export fn shada_async_write_join() callconv(.c) void {
    if (write_thread) |thread| {
        thread.join();
        write_thread = null;
    }
}

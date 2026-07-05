const std = @import("std");
const c = @import("c");

extern fn time(arg: ?*c_long) c_long;
extern fn os_realpath_nocache(name: [*c]const u8, buf: [*c]u8, len: usize) [*c]u8;

const CacheEntry = struct {
    resolved: []const u8,
    timestamp_s: c_long,
};

const SpinLock = struct {
    impl: std.atomic.Mutex = .unlocked,

    pub fn lock(self: *SpinLock) void {
        while (!self.impl.tryLock()) {
            std.Thread.yield() catch {};
        }
    }

    pub fn unlock(self: *SpinLock) void {
        self.impl.unlock();
    }
};

var cache_lock = SpinLock{};
var path_cache: ?std.StringHashMap(CacheEntry) = null;
var cache_allocator: ?std.mem.Allocator = null;

const CACHE_TTL_S = 5;
const CACHE_MAX_SIZE = 1024;

fn getCache() *std.StringHashMap(CacheEntry) {
    if (path_cache == null) {
        cache_allocator = std.heap.c_allocator;
        path_cache = std.StringHashMap(CacheEntry).init(cache_allocator.?);
    }
    return &path_cache.?;
}

export fn path_cache_clear() callconv(.c) void {
    cache_lock.lock();
    defer cache_lock.unlock();
    if (path_cache) |*cache| {
        const alloc = cache_allocator.?;
        var it = cache.iterator();
        while (it.next()) |kv| {
            alloc.free(kv.key_ptr.*);
            alloc.free(kv.value_ptr.resolved);
        }
        cache.clearRetainingCapacity();
    }
}

export fn os_realpath(name: [*c]const u8, buf: [*c]u8, len: usize) callconv(.c) [*c]u8 {
    const name_len = std.mem.len(name);
    const name_slice = name[0..name_len];

    const now = time(null);

    cache_lock.lock();
    defer cache_lock.unlock();

    const cache = getCache();
    const alloc = cache_allocator.?;

    if (cache.get(name_slice)) |entry| {
        if (now - entry.timestamp_s < CACHE_TTL_S) {
            var out_buf = buf;
            if (out_buf == null) {
                out_buf = @ptrCast(c.xmalloc(len));
            }
            const copy_len = @min(len - 1, entry.resolved.len);
            @memcpy(out_buf[0..copy_len], entry.resolved[0..copy_len]);
            out_buf[copy_len] = 0;
            return out_buf;
        } else {
            if (cache.fetchRemove(name_slice)) |kv| {
                alloc.free(kv.key);
                alloc.free(kv.value.resolved);
            }
        }
    }

    const res = os_realpath_nocache(name, null, len);
    if (res == null) return null;
    defer c.xfree(res);

    const resolved_len = std.mem.len(res);
    const resolved_slice = res[0..resolved_len];

    if (cache.count() >= CACHE_MAX_SIZE) {
        var it = cache.iterator();
        while (it.next()) |kv| {
            alloc.free(kv.key_ptr.*);
            alloc.free(kv.value_ptr.resolved);
        }
        cache.clearRetainingCapacity();
    }

    const name_dup = alloc.dupe(u8, name_slice) catch return null;
    const resolved_dup = alloc.dupe(u8, resolved_slice) catch {
        alloc.free(name_dup);
        return null;
    };

    cache.put(name_dup, .{
        .resolved = resolved_dup,
        .timestamp_s = now,
    }) catch {
        alloc.free(name_dup);
        alloc.free(resolved_dup);
    };

    var out_buf = buf;
    if (out_buf == null) {
        out_buf = @ptrCast(c.xmalloc(len));
    }
    const copy_len = @min(len - 1, resolved_slice.len);
    @memcpy(out_buf[0..copy_len], resolved_slice[0..copy_len]);
    out_buf[copy_len] = 0;
    return out_buf;
}

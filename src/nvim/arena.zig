const std = @import("std");
const c = @import("c");

const ARENA_BLOCK_SIZE = 4096;
const REUSE_MAX = 4;

const consumed_blk = extern struct {
    prev: ?*consumed_blk,
};

var arena_reuse_blk: ?*consumed_blk = null;
var arena_reuse_blk_count: usize = 0;

export fn arena_free_reuse_blks() callconv(.c) void {
    while (arena_reuse_blk_count > 0) {
        if (arena_reuse_blk) |blk| {
            arena_reuse_blk = blk.prev;
            c.xfree(@ptrCast(blk));
            arena_reuse_blk_count -= 1;
        }
    }
}

export fn arena_finish(arena: ?*c.Arena) callconv(.c) ?*anyopaque {
    const a = arena orelse return null;
    const res = a.cur_blk;
    a.cur_blk = null;
    a.pos = 0;
    a.size = 0;
    return res;
}

export fn alloc_block() callconv(.c) ?*anyopaque {
    if (arena_reuse_blk_count > 0) {
        const blk = arena_reuse_blk.?;
        arena_reuse_blk = blk.prev;
        arena_reuse_blk_count -= 1;
        return @ptrCast(blk);
    } else {
        c.arena_alloc_count += 1;
        return @ptrCast(c.xmalloc(ARENA_BLOCK_SIZE));
    }
}

export fn free_block(block: ?*anyopaque) callconv(.c) void {
    const b = @as(?*consumed_blk, @ptrCast(@alignCast(block))) orelse return;
    if (arena_reuse_blk_count < REUSE_MAX) {
        b.prev = arena_reuse_blk;
        arena_reuse_blk = b;
        arena_reuse_blk_count += 1;
    } else {
        c.xfree(@ptrCast(b));
    }
}

export fn arena_alloc_block(arena: ?*c.Arena) callconv(.c) void {
    const a = arena orelse return;
    const prev_blk = @as(?*consumed_blk, @ptrCast(@alignCast(a.cur_blk)));

    const new_blk = alloc_block();
    a.cur_blk = @ptrCast(new_blk);
    a.pos = 0;
    a.size = ARENA_BLOCK_SIZE;

    const blk = @as(*consumed_blk, @ptrCast(@alignCast(arena_alloc(a, @sizeOf(consumed_blk), true))));
    blk.prev = prev_blk;
}

inline fn arena_align_offset(off: usize) usize {
    const align_val = @max(@sizeOf(?*anyopaque), @sizeOf(f64));
    return (off + (align_val - 1)) & ~@as(usize, align_val - 1);
}

export fn arena_alloc(arena: ?*c.Arena, size: usize, align_addr: bool) callconv(.c) ?*anyopaque {
    const a = arena orelse {
        return c.xmalloc(size);
    };
    if (a.cur_blk == null) {
        arena_alloc_block(a);
    }

    var alloc_pos = if (align_addr) arena_align_offset(a.pos) else a.pos;
    if (alloc_pos + size > a.size) {
        const consumed_hdr_size = @sizeOf(consumed_blk);
        if (size > (ARENA_BLOCK_SIZE - consumed_hdr_size) >> 1) {
            c.arena_alloc_count += 1;
            const aligned_hdr_size = if (align_addr) arena_align_offset(consumed_hdr_size) else consumed_hdr_size;
            const alloc = @as([*]u8, @ptrCast(c.xmalloc(size + aligned_hdr_size)));

            const cur_blk = @as(*consumed_blk, @ptrCast(@alignCast(a.cur_blk.?)));
            const fix_blk = @as(*consumed_blk, @ptrCast(@alignCast(alloc)));
            fix_blk.prev = cur_blk.prev;
            cur_blk.prev = fix_blk;
            return alloc + aligned_hdr_size;
        } else {
            arena_alloc_block(a);
            alloc_pos = if (align_addr) arena_align_offset(a.pos) else a.pos;
        }
    }

    const mem = a.cur_blk.? + alloc_pos;
    a.pos = alloc_pos + size;
    return mem;
}

export fn arena_mem_free(mem: ?*anyopaque) callconv(.c) void {
    var b = @as(?*consumed_blk, @ptrCast(@alignCast(mem)));
    if (b) |first| {
        b = first.prev;
        free_block(first);
    }
    while (b) |blk| {
        const prev = blk.prev;
        c.xfree(@ptrCast(blk));
        b = prev;
    }
}

export fn arena_allocz(arena: ?*c.Arena, size: usize) callconv(.c) ?*anyopaque {
    const mem = @as([*]u8, @ptrCast(arena_alloc(arena, size + 1, false)));
    mem[size] = 0;
    return mem;
}

export fn arena_memdupz(arena: ?*c.Arena, buf: ?*const anyopaque, size: usize) callconv(.c) ?*anyopaque {
    const mem = arena_allocz(arena, size);
    if (mem) |m| {
        if (buf) |b| {
            @memcpy(@as([*]u8, @ptrCast(m))[0..size], @as([*]const u8, @ptrCast(b))[0..size]);
        }
    }
    return mem;
}

export fn arena_strdup(arena: ?*c.Arena, str: [*c]const u8) callconv(.c) [*c]u8 {
    const len = std.mem.len(str);
    return @ptrCast(arena_memdupz(arena, str, len));
}

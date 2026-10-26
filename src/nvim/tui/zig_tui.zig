const std = @import("std");

const Cell = extern struct {
    ch: [4]u8,
    attr: u32,
};

export fn diff_cells_zig_simd(old_cells: [*]const Cell, new_cells: [*]const Cell, len: usize) usize {
    var diffs: usize = 0;
    const Chunk = @Vector(4, u64); 
    const chunk_size = 4;
    var i: usize = 0;
    while (i + chunk_size <= len) : (i += chunk_size) {
        const old_ptr: *const [4]u64 = @ptrCast(@alignCast(&old_cells[i]));
        const new_ptr: *const [4]u64 = @ptrCast(@alignCast(&new_cells[i]));
        const old_vec: Chunk = old_ptr.*;
        const new_vec: Chunk = new_ptr.*;
        const mask = old_vec != new_vec;
        diffs += @popCount(@as(u4, @bitCast(mask)));
    }
    while (i < len) : (i += 1) {
        const o_ptr: *const u64 = @ptrCast(@alignCast(&old_cells[i]));
        const n_ptr: *const u64 = @ptrCast(@alignCast(&new_cells[i]));
        if (o_ptr.* != n_ptr.*) diffs += 1;
    }
    return diffs;
}

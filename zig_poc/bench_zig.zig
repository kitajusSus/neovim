const std = @import("std");

const Cell = extern struct {
    ch: [4]u8,
    attr: u32,
};

fn diff_cells_zig_simd(old_cells: []const Cell, new_cells: []const Cell) usize {
    var diffs: usize = 0;
    const Chunk = @Vector(4, u64); 
    const chunk_size = 4;
    var i: usize = 0;
    while (i + chunk_size <= old_cells.len) : (i += chunk_size) {
        const old_ptr: *const [4]u64 = @ptrCast(@alignCast(&old_cells[i]));
        const new_ptr: *const [4]u64 = @ptrCast(@alignCast(&new_cells[i]));
        const old_vec: Chunk = old_ptr.*;
        const new_vec: Chunk = new_ptr.*;
        const mask = old_vec != new_vec;
        diffs += @popCount(@as(u4, @bitCast(mask)));
    }
    while (i < old_cells.len) : (i += 1) {
        const o_ptr: *const u64 = @ptrCast(@alignCast(&old_cells[i]));
        const n_ptr: *const u64 = @ptrCast(@alignCast(&new_cells[i]));
        if (o_ptr.* != n_ptr.*) diffs += 1;
    }
    return diffs;
}

pub fn main() !void {
    const count = 10_000_000;
    const allocator = std.heap.c_allocator;
    const old_cells = try allocator.alloc(Cell, count);
    const new_cells = try allocator.alloc(Cell, count);
    
    for (old_cells, 0..) |*c, idx| {
        c.ch = [4]u8{ 'A', 0, 0, 0 };
        c.attr = @as(u32, @intCast(idx % 256));
    }
    @memcpy(new_cells, old_cells);
    
    var i: usize = 0;
    while (i < count) : (i += 7) {
        new_cells[i].attr = 999;
    }
    
    var sum: usize = 0;
    var j: usize = 0;
    while (j < 100) : (j += 1) {
        sum += diff_cells_zig_simd(old_cells, new_cells);
    }
    
    std.debug.print("{d}\n", .{sum});
}

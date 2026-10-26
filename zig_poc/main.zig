const std = @import("std");

const Cell = extern struct {
    ch: [4]u8,
    attr: u32,
};

extern fn diff_cells_c(old_cells: [*]const Cell, new_cells: [*]const Cell, count: usize) usize;

fn diff_cells_zig_simd(old_cells: []const Cell, new_cells: []const Cell) usize {
    var diffs: usize = 0;
    
    // Process in chunks of 4 cells (32 bytes)
    const Chunk = @Vector(4, u64); 
    const chunk_size = 4;
    
    var i: usize = 0;
    while (i + chunk_size <= old_cells.len) : (i += chunk_size) {
        const old_ptr: *const [4]u64 = @ptrCast(@alignCast(&old_cells[i]));
        const new_ptr: *const [4]u64 = @ptrCast(@alignCast(&new_cells[i]));
        
        const old_vec: Chunk = old_ptr.*;
        const new_vec: Chunk = new_ptr.*;
        
        const mask = old_vec != new_vec;
        const diff_count = @popCount(@as(u4, @bitCast(mask)));
        diffs += diff_count;
    }
    
    // Tail
    while (i < old_cells.len) : (i += 1) {
        const o_u64: u64 = @bitCast(old_cells[i]);
        const n_u64: u64 = @bitCast(new_cells[i]);
        if (o_u64 != n_u64) diffs += 1;
    }
    return diffs;
}

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    const count = 10_000_000;
    const old_cells = try allocator.alloc(Cell, count);
    defer allocator.free(old_cells);
    const new_cells = try allocator.alloc(Cell, count);
    defer allocator.free(new_cells);

    for (old_cells, 0..) |*c, i| {
        c.ch = [4]u8{ 'A', 0, 0, 0 };
        c.attr = @as(u32, @intCast(i % 256));
    }
    @memcpy(new_cells, old_cells);
    
    var i: usize = 0;
    while (i < count) : (i += 7) {
        new_cells[i].attr = 999;
    }

    const iters = 100;
    
    // Determine which mode we are in based on args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const mode = if (args.len > 1) args[1] else "c";
    
    var sum: usize = 0;
    if (std.mem.eql(u8, mode, "c")) {
        var j: usize = 0;
        while (j < iters) : (j += 1) {
            sum += diff_cells_c(old_cells.ptr, new_cells.ptr, count);
        }
    } else {
        var j: usize = 0;
        while (j < iters) : (j += 1) {
            sum += diff_cells_zig_simd(old_cells, new_cells);
        }
    }
    
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{}\n", .{sum});
}

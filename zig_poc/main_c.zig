const std = @import("std");

const Cell = extern struct {
    ch: [4]u8,
    attr: u32,
};

extern fn diff_cells_c(old_cells: [*]const Cell, new_cells: [*]const Cell, count: usize) usize;

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
    var sum: usize = 0;
    
    var j: usize = 0;
    while (j < iters) : (j += 1) {
        sum += diff_cells_c(old_cells.ptr, new_cells.ptr, count);
    }
    
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{d}\n", .{sum});
}

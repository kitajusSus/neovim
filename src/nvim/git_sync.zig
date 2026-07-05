const std = @import("std");
const c = @import("c");

extern fn fopen(filename: [*c]const u8, modes: [*c]const u8) ?*anyopaque;
extern fn fclose(stream: ?*anyopaque) c_int;
extern fn fread(ptr: ?*anyopaque, size: usize, n: usize, stream: ?*anyopaque) usize;
extern fn fseek(stream: ?*anyopaque, offset: c_long, whence: c_int) c_int;
extern fn ftell(stream: ?*anyopaque) c_long;

pub const GroupedDiff = extern struct {
    line_num: u32,  // 1-based line number in the current buffer
    diff_type: u8,  // 1: added, 2: deleted, 3: modified
    count: u32,     // number of lines
};

pub const GitDiffResult = extern struct {
    diffs: [*c]GroupedDiff,
    count: usize,
};

const DiffOp = enum {
    equal,
    added,
    deleted,
};

const DiffResult = struct {
    op: DiffOp,
    line_idx: usize,
};

fn readFileAlloc(path: []const u8, allocator: std.mem.Allocator) !?[]u8 {
    var path_buf: [1024]u8 = undefined;
    if (path.len >= path_buf.len) return null;
    @memcpy(path_buf[0..path.len], path);
    path_buf[path.len] = 0;

    const f = fopen(&path_buf, "rb") orelse return null;
    defer _ = fclose(f);

    _ = fseek(f, 0, 2);
    const size = ftell(f);
    _ = fseek(f, 0, 0);

    if (size < 0) return null;

    const buf = try allocator.alloc(u8, @intCast(size));
    errdefer allocator.free(buf);

    const read_bytes = fread(buf.ptr, 1, @intCast(size), f);
    return buf[0..read_bytes];
}

fn findGitDir(file_path: []const u8, allocator: std.mem.Allocator) !?struct { git_dir: []const u8, rel_path: []const u8 } {
    const dir_path = std.fs.path.dirname(file_path) orelse return null;
    const filename = std.fs.path.basename(file_path);

    var path_buf = std.ArrayList(u8).empty;
    errdefer path_buf.deinit(allocator);
    try path_buf.appendSlice(allocator, filename);

    var current_dir_path = try allocator.dupe(u8, dir_path);
    defer allocator.free(current_dir_path);

    while (true) {
        const index_check_path = try std.fs.path.join(allocator, &[_][]const u8{ current_dir_path, ".git", "index" });
        defer allocator.free(index_check_path);

        var path_c: [1024]u8 = undefined;
        if (index_check_path.len < path_c.len) {
            @memcpy(path_c[0..index_check_path.len], index_check_path);
            path_c[index_check_path.len] = 0;
            if (fopen(&path_c, "rb")) |f| {
                _ = fclose(f);
                const git_dir = try std.fs.path.join(allocator, &[_][]const u8{ current_dir_path, ".git" });
                const rel_path = try allocator.dupe(u8, path_buf.items);
                return .{
                    .git_dir = git_dir,
                    .rel_path = rel_path,
                };
            }
        }

        const parent_dir_path = std.fs.path.dirname(current_dir_path) orelse return null;
        if (std.mem.eql(u8, parent_dir_path, current_dir_path)) return null;

        const base = std.fs.path.basename(current_dir_path);
        try path_buf.insertSlice(allocator, 0, "/");
        try path_buf.insertSlice(allocator, 0, base);

        allocator.free(current_dir_path);
        current_dir_path = try allocator.dupe(u8, parent_dir_path);
    }
}

fn findBlobSha(git_dir_path: []const u8, rel_path: []const u8, allocator: std.mem.Allocator) !?[20]u8 {
    const index_path = try std.fs.path.join(allocator, &[_][]const u8{ git_dir_path, "index" });
    defer allocator.free(index_path);

    const index_data = try readFileAlloc(index_path, allocator) orelse return null;
    defer allocator.free(index_data);

    if (index_data.len < 12) return null;
    if (!std.mem.eql(u8, index_data[0..4], "DIRC")) return null;

    const version = std.mem.readInt(u32, index_data[4..8][0..4], .big);
    if (version < 2 or version > 4) return null;

    const num_entries = std.mem.readInt(u32, index_data[8..12][0..4], .big);

    var offset: usize = 12;
    var entry_idx: u32 = 0;
    while (entry_idx < num_entries and offset + 62 <= index_data.len) : (entry_idx += 1) {
        const meta = index_data[offset .. offset + 62];
        const sha1 = meta[40..60].*;
        const flags = std.mem.readInt(u16, meta[60..62][0..2], .big);
        const path_len = flags & 0x0FFF;
        _ = path_len;

        var path_end: usize = offset + 62;
        while (path_end < index_data.len and index_data[path_end] != 0) : (path_end += 1) {}
        if (path_end >= index_data.len) return null;

        const path = index_data[offset + 62 .. path_end];

        const entry_total_len = 62 + path.len + 1;
        const align_rem = entry_total_len % 8;
        const pad_len = if (align_rem != 0) 8 - align_rem else 0;

        offset += entry_total_len + pad_len;

        if (std.mem.eql(u8, path, rel_path)) {
            return sha1;
        }
    }

    return null;
}

fn readBlobContent(git_dir_path: []const u8, sha1: [20]u8, allocator: std.mem.Allocator) !?[]const u8 {
    const hex_chars = "0123456789abcdef";
    var hex_buf: [40]u8 = undefined;
    for (sha1, 0..) |byte, idx| {
        hex_buf[idx * 2] = hex_chars[byte >> 4];
        hex_buf[idx * 2 + 1] = hex_chars[byte & 0x0f];
    }

    const dir_name = hex_buf[0..2];
    const file_name = hex_buf[2..40];

    const obj_path = try std.fs.path.join(allocator, &[_][]const u8{ git_dir_path, "objects", dir_name, file_name });
    defer allocator.free(obj_path);

    const compressed_data = try readFileAlloc(obj_path, allocator) orelse return null;
    defer allocator.free(compressed_data);

    var input_reader = std.Io.Reader.fixed(compressed_data);

    const decompress_buf = try allocator.alloc(u8, std.compress.flate.max_window_len);
    defer allocator.free(decompress_buf);

    var decompressor = std.compress.flate.Decompress.init(&input_reader, .zlib, decompress_buf);

    const decompressed = decompressor.reader.allocRemaining(allocator, @enumFromInt(@as(usize, 10 * 1024 * 1024))) catch return null;
    defer allocator.free(decompressed);

    if (std.mem.indexOfScalar(u8, decompressed, 0)) |null_idx| {
        const content = decompressed[null_idx + 1 ..];
        return try allocator.dupe(u8, content);
    }

    return null;
}

fn splitLines(text: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    var lines = std.ArrayList([]const u8).empty;
    errdefer lines.deinit(allocator);

    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| {
        const clean_line = if (line.len > 0 and line[line.len - 1] == '\r') line[0 .. line.len - 1] else line;
        try lines.append(allocator, clean_line);
    }

    return lines.toOwnedSlice(allocator);
}

fn myersDiff(allocator: std.mem.Allocator, src: [][]const u8, dest: [][]const u8) ![]DiffResult {
    const N = src.len;
    const M = dest.len;
    const MAX = N + M;

    var v = try allocator.alloc(isize, 2 * MAX + 1);
    defer allocator.free(v);

    var trace = std.ArrayList([]isize).empty;
    defer {
        for (trace.items) |t| allocator.free(t);
        trace.deinit(allocator);
    }

    v[MAX + 1] = 0;

    var x: isize = 0;
    var y: isize = 0;

    const MAX_D = @min(MAX, 500);

    var d: usize = 0;
    var reached = false;
    outer: while (d <= MAX_D) : (d += 1) {
        const t = try allocator.alloc(isize, 2 * MAX + 1);
        @memcpy(t, v);
        try trace.append(allocator, t);

        var k: isize = -@as(isize, @intCast(d));
        while (k <= @as(isize, @intCast(d))) : (k += 2) {
            const idx = @as(usize, @intCast(k + @as(isize, @intCast(MAX))));
            if (k == -@as(isize, @intCast(d)) or (k != @as(isize, @intCast(d)) and v[idx - 1] < v[idx + 1])) {
                x = v[idx + 1];
            } else {
                x = v[idx - 1] + 1;
            }
            y = x - k;

            while (x < N and y < M and std.mem.eql(u8, src[@as(usize, @intCast(x))], dest[@as(usize, @intCast(y))])) {
                x += 1;
                y += 1;
            }

            v[idx] = x;

            if (x >= N and y >= M) {
                reached = true;
                break :outer;
            }
        }
    }

    if (!reached) {
        return &[_]DiffResult{};
    }

    var path = std.ArrayList(DiffResult).empty;
    errdefer path.deinit(allocator);

    var curr_x = @as(isize, @intCast(N));
    var curr_y = @as(isize, @intCast(M));

    var d_idx = trace.items.len - 1;
    while (curr_x > 0 or curr_y > 0) {
        const k = curr_x - curr_y;
        const t = trace.items[d_idx];
        const idx = @as(usize, @intCast(k + @as(isize, @intCast(MAX))));

        const prev_k = if (k == -@as(isize, @intCast(d_idx)) or (k != @as(isize, @intCast(d_idx)) and t[idx - 1] < t[idx + 1]))
            k + 1
        else
            k - 1;

        const prev_idx = @as(usize, @intCast(prev_k + @as(isize, @intCast(MAX))));
        const prev_x = t[prev_idx];
        const prev_y = prev_x - prev_k;

        while (curr_x > prev_x and curr_y > prev_y) {
            try path.append(allocator, .{ .op = .equal, .line_idx = @intCast(curr_x - 1) });
            curr_x -= 1;
            curr_y -= 1;
        }

        if (curr_x > prev_x) {
            try path.append(allocator, .{ .op = .deleted, .line_idx = @intCast(curr_x - 1) });
            curr_x -= 1;
        } else if (curr_y > prev_y) {
            try path.append(allocator, .{ .op = .added, .line_idx = @intCast(curr_y - 1) });
            curr_y -= 1;
        }

        if (d_idx == 0) break;
        d_idx -= 1;
    }

    std.mem.reverse(DiffResult, path.items);
    return path.toOwnedSlice(allocator);
}

export fn nvim_git_diff(
    file_path_c: [*c]const u8,
    buffer_text_c: [*c]const u8,
    buffer_len: usize,
) callconv(.c) GitDiffResult {
    if (file_path_c == null or buffer_text_c == null) {
        return .{ .diffs = null, .count = 0 };
    }

    const allocator = std.heap.c_allocator;

    const file_path = std.mem.span(file_path_c);
    const buffer_text = buffer_text_c[0..buffer_len];

    const git_info_opt = findGitDir(file_path, allocator) catch return .{ .diffs = null, .count = 0 };
    const git_info = git_info_opt orelse return .{ .diffs = null, .count = 0 };
    defer allocator.free(git_info.git_dir);
    defer allocator.free(git_info.rel_path);

    const sha1_opt = findBlobSha(git_info.git_dir, git_info.rel_path, allocator) catch return .{ .diffs = null, .count = 0 };
    const sha1 = sha1_opt orelse return .{ .diffs = null, .count = 0 };

    const index_content_opt = readBlobContent(git_info.git_dir, sha1, allocator) catch return .{ .diffs = null, .count = 0 };
    const index_content = index_content_opt orelse return .{ .diffs = null, .count = 0 };
    defer allocator.free(index_content);

    const src_lines = splitLines(index_content, allocator) catch return .{ .diffs = null, .count = 0 };
    defer allocator.free(src_lines);

    const dest_lines = splitLines(buffer_text, allocator) catch return .{ .diffs = null, .count = 0 };
    defer allocator.free(dest_lines);

    const path = myersDiff(allocator, src_lines, dest_lines) catch return .{ .diffs = null, .count = 0 };
    defer allocator.free(path);

    if (path.len == 0) {
        return .{ .diffs = null, .count = 0 };
    }

    var grouped = std.ArrayList(GroupedDiff).empty;
    errdefer grouped.deinit(allocator);

    var i: usize = 0;
    var current_buffer_line: u32 = 1;

    while (i < path.len) {
        if (path[i].op == .equal) {
            current_buffer_line += 1;
            i += 1;
        } else if (path[i].op == .added) {
            var add_count: u32 = 0;
            while (i + add_count < path.len and path[i + add_count].op == .added) : (add_count += 1) {}

            grouped.append(allocator, .{
                .line_num = current_buffer_line,
                .diff_type = 1,
                .count = add_count,
            }) catch return .{ .diffs = null, .count = 0 };
            current_buffer_line += add_count;
            i += add_count;
        } else if (path[i].op == .deleted) {
            var del_count: u32 = 0;
            while (i + del_count < path.len and path[i + del_count].op == .deleted) : (del_count += 1) {}

            var add_count: u32 = 0;
            const next_i = i + del_count;
            while (next_i + add_count < path.len and path[next_i + add_count].op == .added) : (add_count += 1) {}

            if (add_count > 0) {
                const common = @min(del_count, add_count);
                grouped.append(allocator, .{
                    .line_num = current_buffer_line,
                    .diff_type = 3,
                    .count = common,
                }) catch return .{ .diffs = null, .count = 0 };

                if (add_count > del_count) {
                    grouped.append(allocator, .{
                        .line_num = current_buffer_line + common,
                        .diff_type = 1,
                        .count = add_count - del_count,
                    }) catch return .{ .diffs = null, .count = 0 };
                } else if (del_count > add_count) {
                    grouped.append(allocator, .{
                        .line_num = current_buffer_line + common,
                        .diff_type = 2,
                        .count = del_count - add_count,
                    }) catch return .{ .diffs = null, .count = 0 };
                }

                current_buffer_line += add_count;
                i += del_count + add_count;
            } else {
                grouped.append(allocator, .{
                    .line_num = current_buffer_line,
                    .diff_type = 2,
                    .count = del_count,
                }) catch return .{ .diffs = null, .count = 0 };
                i += del_count;
            }
        }
    }

    const count = grouped.items.len;
    if (count == 0) {
        grouped.deinit(allocator);
        return .{ .diffs = null, .count = 0 };
    }

    const merged_ptr = grouped.toOwnedSlice(allocator) catch return .{ .diffs = null, .count = 0 };
    return .{ .diffs = merged_ptr.ptr, .count = count };
}

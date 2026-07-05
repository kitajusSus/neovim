const std = @import("std");

pub const Match = extern struct {
    line_idx: u32,
    col_idx: u32,
};

pub const SearchResult = extern struct {
    matches: [*c]Match,
    count: usize,
};

const SearchContext = struct {
    lines: []const [*c]const u8,
    line_start_idx: usize,
    query: []const u8,
    case_insensitive: bool,
    allocator: std.mem.Allocator,
    matches: std.ArrayList(Match),
};

fn searchWorker(ctx: *SearchContext) void {
    for (ctx.lines, 0..) |line_c, i| {
        const line_idx = ctx.line_start_idx + i;
        if (line_c == null) continue;
        const line_len = std.mem.len(line_c);
        const line = line_c[0..line_len];

        var start: usize = 0;
        while (start < line.len) {
            const index = if (ctx.case_insensitive)
                indexOfIgnoreCase(line[start..], ctx.query)
            else
                std.mem.indexOf(u8, line[start..], ctx.query);

            if (index) |pos| {
                ctx.matches.append(ctx.allocator, .{
                    .line_idx = @intCast(line_idx),
                    .col_idx = @intCast(start + pos),
                }) catch {};
                start += pos + @max(1, ctx.query.len);
            } else {
                break;
            }
        }
    }
}

fn indexOfIgnoreCase(haystack: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return 0;
    if (haystack.len < needle.len) return null;

    var i: usize = 0;
    const limit = haystack.len - needle.len;
    while (i <= limit) : (i += 1) {
        var match = true;
        for (needle, 0..) |n_char, j| {
            const h_char = haystack[i + j];
            if (std.ascii.toLower(h_char) != std.ascii.toLower(n_char)) {
                match = false;
                break;
            }
        }
        if (match) return i;
    }
    return null;
}

export fn nvim_multithreaded_search(
    lines_c: [*c]const [*c]const u8,
    num_lines: usize,
    query_c: [*c]const u8,
    case_insensitive: bool,
) callconv(.c) SearchResult {
    if (num_lines == 0 or query_c == null) {
        return .{ .matches = null, .count = 0 };
    }

    const query_len = std.mem.len(query_c);
    if (query_len == 0) {
        return .{ .matches = null, .count = 0 };
    }
    const query = query_c[0..query_len];

    const lines = lines_c[0..num_lines];

    const thread_count = @max(1, std.Thread.getCpuCount() catch 4);

    const allocator = std.heap.c_allocator;

    if (num_lines < 1000 or thread_count == 1) {
        var ctx = SearchContext{
            .lines = lines,
            .line_start_idx = 0,
            .query = query,
            .case_insensitive = case_insensitive,
            .allocator = allocator,
            .matches = std.ArrayList(Match).empty,
        };
        searchWorker(&ctx);
        const count = ctx.matches.items.len;
        if (count == 0) {
            ctx.matches.deinit(allocator);
            return .{ .matches = null, .count = 0 };
        }
        const matches_ptr = ctx.matches.toOwnedSlice(allocator) catch return .{ .matches = null, .count = 0 };
        return .{ .matches = matches_ptr.ptr, .count = count };
    }

    const contexts = allocator.alloc(SearchContext, thread_count) catch {
        return .{ .matches = null, .count = 0 };
    };
    defer allocator.free(contexts);

    const threads = allocator.alloc(std.Thread, thread_count) catch {
        return .{ .matches = null, .count = 0 };
    };
    defer allocator.free(threads);

    const chunk_size = (num_lines + thread_count - 1) / thread_count;

    var spawned: usize = 0;
    defer {
        for (0..spawned) |j| {
            threads[j].join();
        }
        for (0..spawned) |j| {
            contexts[j].matches.deinit(allocator);
        }
    }

    for (0..thread_count) |t| {
        const start = t * chunk_size;
        const end = @min(num_lines, (t + 1) * chunk_size);
        if (start >= end) break;

        contexts[t] = .{
            .lines = lines[start..end],
            .line_start_idx = start,
            .query = query,
            .case_insensitive = case_insensitive,
            .allocator = allocator,
            .matches = std.ArrayList(Match).empty,
        };

        threads[t] = std.Thread.spawn(.{}, searchWorker, .{&contexts[t]}) catch {
            searchWorker(&contexts[t]);
            continue;
        };
        spawned += 1;
    }

    for (0..spawned) |j| {
        threads[j].join();
    }
    const total_spawned = spawned;
    spawned = 0;
    _ = total_spawned;

    var total_matches = std.ArrayList(Match).empty;
    defer total_matches.deinit(allocator);

    for (0..thread_count) |t| {
        const start = t * chunk_size;
        if (start >= num_lines) break;
        total_matches.appendSlice(allocator, contexts[t].matches.items) catch {};
        contexts[t].matches.deinit(allocator);
    }

    const count = total_matches.items.len;
    if (count == 0) {
        return .{ .matches = null, .count = 0 };
    }

    const merged_ptr = total_matches.toOwnedSlice(allocator) catch return .{ .matches = null, .count = 0 };
    return .{ .matches = merged_ptr.ptr, .count = count };
}

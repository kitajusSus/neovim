const std = @import("std");
const c = @import("c");

extern fn shm_open(name: [*c]const u8, oflag: c_int, mode: c_uint) c_int;
extern fn shm_unlink(name: [*c]const u8) c_int;
extern fn ftruncate(fd: c_int, length: c_long) c_int;
extern fn mmap(addr: ?*anyopaque, length: usize, prot: c_int, flags: c_int, fd: c_int, offset: c_long) ?*anyopaque;
extern fn munmap(addr: ?*anyopaque, length: usize) c_int;

extern fn sem_open(name: [*c]const u8, oflag: c_int, mode: c_uint, value: c_uint) ?*anyopaque;
extern fn sem_close(sem: ?*anyopaque) c_int;
extern fn sem_unlink(name: [*c]const u8) c_int;
extern fn sem_wait(sem: ?*anyopaque) c_int;
extern fn sem_post(sem: ?*anyopaque) c_int;

extern fn getpid() c_int;
extern fn usleep(useconds: c_uint) c_int;

const O_RDWR = 2;
const O_CREAT = 64;
const PROT_READ = 1;
const PROT_WRITE = 2;
const MAP_SHARED = 1;
const MAP_FAILED = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));
const SEM_FAILED = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));

const ShmHeader = extern struct {
    magic: u32,
    version: u32,
    length: u32,
    writer_pid: u32,
};

const SHM_SIZE = 1024 * 1024; // 1 MB buffer limit

var shm_ptr: ?*anyopaque = null;
var shm_fd: c_int = -1;
var shm_name_buf: [128]u8 = undefined;

var sem_ptr: ?*anyopaque = null;
var sem_name_buf: [128]u8 = undefined;

var monitor_thread: ?std.Thread = null;
var monitor_running: bool = false;

var async_handle: c.uv_async_t = undefined;

extern fn lua_rawgeti(L: ?*anyopaque, idx: c_int, n: c_int) void;
extern fn lua_pcall(L: ?*anyopaque, nargs: c_int, nresults: c_int, errfunc: c_int) c_int;
extern fn lua_tolstring(L: ?*anyopaque, idx: c_int, len: ?*usize) [*c]const u8;
extern fn lua_settop(L: ?*anyopaque, idx: c_int) void;
extern fn luaL_unref(L: ?*anyopaque, t: c_int, ref: c_int) void;

const LUA_REGISTRYINDEX = -10000;

inline fn lua_pop(L: ?*anyopaque, n: c_int) void {
    lua_settop(L, -n - 1);
}

var last_seen_version: u32 = 0;
var lua_callback_ref: c_int = -1;
var lua_state_ptr: ?*anyopaque = null;

fn asyncCallback(handle: ?*c.uv_async_t) callconv(.c) void {
    _ = handle;
    const lstate = lua_state_ptr orelse return;

    if (lua_callback_ref != -1) {
        lua_rawgeti(lstate, LUA_REGISTRYINDEX, lua_callback_ref);
        if (lua_pcall(lstate, 0, 0, 0) != 0) {
            const err_msg = lua_tolstring(lstate, -1, null);
            std.log.err("SHM Sync Callback Error: {s}", .{err_msg});
            lua_pop(lstate, 1);
        }
    }
}

fn monitorThread() void {
    const header = @as(*ShmHeader, @ptrCast(@alignCast(shm_ptr.?)));
    while (monitor_running) {
        if (sem_ptr) |sem| {
            _ = sem_wait(sem);
        } else {
            _ = usleep(100 * 1000);
            continue;
        }

        if (!monitor_running) break;

        const current_pid = @as(u32, @intCast(getpid()));
        if (header.version > last_seen_version and header.writer_pid != current_pid) {
            last_seen_version = header.version;
            _ = c.uv_async_send(&async_handle);
        }
    }
}

export fn shm_sync_init(
    session_id: [*c]const u8,
    lstate: ?*anyopaque,
    callback_ref: c_int,
) callconv(.c) c_int {
    if (shm_ptr != null) return 0;

    lua_state_ptr = lstate;
    lua_callback_ref = callback_ref;

    const session_slice = std.mem.span(session_id);

    const shm_name = std.fmt.bufPrint(&shm_name_buf, "/nvim-shm-{s}", .{session_slice}) catch return -1;
    shm_name_buf[shm_name.len] = 0;

    const sem_name = std.fmt.bufPrint(&sem_name_buf, "/nvim-sem-{s}", .{session_slice}) catch return -1;
    sem_name_buf[sem_name.len] = 0;

    shm_fd = shm_open(&shm_name_buf[0], O_CREAT | O_RDWR, 0o666);
    if (shm_fd < 0) return -1;

    _ = ftruncate(shm_fd, SHM_SIZE);

    const map_res = mmap(
        null,
        SHM_SIZE,
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        shm_fd,
        0,
    );
    if (map_res == MAP_FAILED) {
        _ = c.close(shm_fd);
        shm_fd = -1;
        return -1;
    }
    shm_ptr = map_res;

    sem_ptr = sem_open(&sem_name_buf[0], O_CREAT, 0o666, @as(c_uint, 0));
    if (sem_ptr == SEM_FAILED) {
        _ = munmap(shm_ptr.?, SHM_SIZE);
        _ = c.close(shm_fd);
        shm_ptr = null;
        shm_fd = -1;
        return -1;
    }

    const header = @as(*ShmHeader, @ptrCast(@alignCast(shm_ptr.?)));
    if (header.magic != 0x4e53484d) {
        header.magic = 0x4e53484d;
        header.version = 0;
        header.length = 0;
        header.writer_pid = 0;
    }
    last_seen_version = header.version;

    _ = c.uv_async_init(&c.main_loop.uv, &async_handle, asyncCallback);

    monitor_running = true;
    monitor_thread = std.Thread.spawn(.{}, monitorThread, .{}) catch {
        shm_sync_close();
        return -1;
    };

    return 0;
}

export fn shm_sync_write(data: [*c]const u8, len: usize) callconv(.c) void {
    const ptr = shm_ptr orelse return;
    const header = @as(*ShmHeader, @ptrCast(@alignCast(ptr)));

    const write_len = @min(len, SHM_SIZE - @sizeOf(ShmHeader));

    const text_ptr = @as([*]u8, @ptrCast(ptr)) + @sizeOf(ShmHeader);
    @memcpy(text_ptr[0..write_len], data[0..write_len]);

    header.length = @intCast(write_len);
    header.writer_pid = @as(u32, @intCast(getpid()));
    header.version += 1;

    last_seen_version = header.version;

    if (sem_ptr) |sem| {
        _ = sem_post(sem);
    }
}

export fn shm_sync_read(buf: [*c]u8, max_len: usize, len_out: *usize) callconv(.c) c_int {
    const ptr = shm_ptr orelse return -1;
    const header = @as(*ShmHeader, @ptrCast(@alignCast(ptr)));

    const read_len = @min(max_len, header.length);
    const text_ptr = @as([*]const u8, @ptrCast(ptr)) + @sizeOf(ShmHeader);
    @memcpy(buf[0..read_len], text_ptr[0..read_len]);

    len_out.* = read_len;
    last_seen_version = header.version;

    return 0;
}

export fn shm_sync_close() callconv(.c) void {
    monitor_running = false;

    if (sem_ptr) |sem| {
        _ = sem_post(sem);
    }

    if (monitor_thread) |thread| {
        thread.join();
        monitor_thread = null;
    }

    if (sem_ptr) |sem| {
        _ = sem_close(sem);
        sem_ptr = null;
    }

    if (shm_ptr) |ptr| {
        _ = munmap(ptr, SHM_SIZE);
        shm_ptr = null;
    }

    if (shm_fd != -1) {
        _ = c.close(shm_fd);
        shm_fd = -1;
    }

    c.uv_close(@ptrCast(&async_handle), null);

    if (lua_state_ptr) |lstate| {
        if (lua_callback_ref != -1) {
            luaL_unref(lstate, LUA_REGISTRYINDEX, lua_callback_ref);
            lua_callback_ref = -1;
        }
    }
}

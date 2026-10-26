import os
import glob

c_files = []
with open('nvim_c_files.txt', 'r') as f:
    for line in f:
        path = line.strip()
        if path and not any(p in path for p in ['pty_conpty_win', 'os_win_console', 'pty_proc_win']):
            c_files.append(path)

extra_files = [
    "src/nvim/testing.c",
    "src/xdiff/xdiffi.c",
    "src/xdiff/xemit.c",
    "src/xdiff/xhistogram.c",
    "src/xdiff/xpatience.c",
    "src/xdiff/xprepare.c",
    "src/xdiff/xutils.c",
    "src/cjson/lua_cjson.c",
    "src/cjson/fpconv.c",
    "src/cjson/strbuf.c",
    "src/mpack/conv.c",
    "src/mpack/lmpack.c",
    "src/mpack/mpack_core.c",
    "src/mpack/object.c",
    "src/mpack/rpc.c",
]

for f in extra_files:
    if f not in c_files and os.path.exists(f):
        c_files.append(f)

build_zig = """const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{}) orelse .debug;

    const root_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const exe = b.addExecutable(.{
        .name = "nvim",
        .root_module = root_mod,
    });
    exe.rdynamic = true;

    // Translate C headers for Zig modules
    const translate_c = b.addTranslateC(.{
        .root_source_file = .{ .cwd_relative = "src/nvim/garray_c_import.h" },
        .target = target,
        .optimize = optimize,
    });
    translate_c.addIncludePath(.{ .cwd_relative = "src" });
    translate_c.addIncludePath(.{ .cwd_relative = ".deps/usr/include" });
    translate_c.addIncludePath(.{ .cwd_relative = ".deps/usr/include/luajit-2.1" });
    translate_c.addIncludePath(.{ .cwd_relative = "build/include" });
    translate_c.addIncludePath(.{ .cwd_relative = "build/src/nvim/auto" });
    translate_c.addIncludePath(.{ .cwd_relative = "build/cmake.config" });
    translate_c.defineCMacro("ZIG_BUILD", null);
    translate_c.defineCMacro("_GNU_SOURCE", null);
    translate_c.defineCMacro("HAVE_UNIBILIUM", null);

    const c_mod = translate_c.createModule();

    // Add Zig native module
    const zig_lib_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/nvim/main.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    zig_lib_mod.addImport("c", c_mod);

    const zig_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "nvim_zig",
        .root_module = zig_lib_mod,
    });
    root_mod.linkLibrary(zig_lib);

    // Link Neovim dependencies (assuming they are in .deps/usr/lib)
    root_mod.addLibraryPath(.{ .cwd_relative = ".deps/usr/lib" });
    root_mod.addIncludePath(.{ .cwd_relative = ".deps/usr/include" });
    root_mod.addIncludePath(.{ .cwd_relative = ".deps/usr/include/luajit-2.1" });
    root_mod.addIncludePath(.{ .cwd_relative = "src" });
    root_mod.addIncludePath(.{ .cwd_relative = "build/include" });
    root_mod.addIncludePath(.{ .cwd_relative = "build/src/nvim/auto" });
    root_mod.addIncludePath(.{ .cwd_relative = "build/cmake.config" });

    // Link required libs
    root_mod.linkSystemLibrary("m", .{});
    root_mod.linkSystemLibrary("pthread", .{});
    root_mod.linkSystemLibrary("dl", .{});
    root_mod.linkSystemLibrary("rt", .{});

    // Neovim specific static libs
    root_mod.linkSystemLibrary("uv", .{});
    root_mod.linkSystemLibrary("luv", .{});
    root_mod.linkSystemLibrary("luajit-5.1", .{});
    root_mod.linkSystemLibrary("vterm", .{});
    root_mod.linkSystemLibrary("tree-sitter", .{});
    root_mod.linkSystemLibrary("msgpack-c", .{});
    root_mod.linkSystemLibrary("utf8proc", .{});
    root_mod.linkSystemLibrary("lpeg", .{});
    root_mod.linkSystemLibrary("unibilium", .{});

"""

for f in c_files:
    build_zig += f'    root_mod.addCSourceFile(.{{ .file = .{{ .cwd_relative = "{f}" }}, .flags = &.{{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" }} }});\n'

build_zig += """
    b.installArtifact(exe);

    // Run step: zig build run -- [args]
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.setEnvironmentVariable("VIMRUNTIME", "runtime");
    run_cmd.addPassthruArgs();
    const run_step = b.step("run", "Run Neovim (Zig)");
    run_step.dependOn(&run_cmd.step);

    // tee helper executable
    const tee_exe = b.addExecutable(.{
        .name = "tee",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    tee_exe.root_module.addCSourceFile(.{ .file = .{ .cwd_relative = "src/tee/tee.c" } });
    b.installArtifact(tee_exe);

    // xxd helper executable
    const xxd_exe = b.addExecutable(.{
        .name = "xxd",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    xxd_exe.root_module.addCSourceFile(.{ .file = .{ .cwd_relative = "src/xxd/xxd.c" } });
    b.installArtifact(xxd_exe);
}
"""

with open('build.zig', 'w') as f:
    f.write(build_zig)

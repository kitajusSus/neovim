import os

c_files = []
with open('nvim_c_files.txt', 'r') as f:
    for line in f:
        path = line.strip()
        if path:
            c_files.append(path)

build_zig = """const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const exe = b.addExecutable(.{
        .name = "nvim_zig",
        .root_module = root_mod,
    });

    // Add Zig module
    const zig_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/nvim/tui/zig_tui.zig" },
    });
    root_mod.addImport("zig_tui", zig_mod);
    
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
    root_mod.linkSystemLibrary("luajit-5.1", .{});
    root_mod.linkSystemLibrary("vterm", .{});
    root_mod.linkSystemLibrary("tree-sitter", .{});
    root_mod.linkSystemLibrary("msgpack-c", .{});
    root_mod.linkSystemLibrary("utf8proc", .{});
    root_mod.linkSystemLibrary("lpeg", .{});
    root_mod.linkSystemLibrary("unibilium", .{});

"""

for f in c_files:
    build_zig += f'    root_mod.addCSourceFile(.{{ .file = .{{ .cwd_relative = "{f}" }}, .flags = &.{{ "-std=gnu99", "-fstack-protector-strong" }} }});\n'

build_zig += """
    b.installArtifact(exe);
}
"""

with open('build.zig', 'w') as f:
    f.write(build_zig)

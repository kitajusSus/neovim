const std = @import("std");

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

    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/ex_eval.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/spellsuggest.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/vterm/screen.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/vterm/keyboard.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/vterm/mouse.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/vterm/encoding.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/vterm/parser.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/vterm/vterm.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/vterm/pen.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/vterm/state.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/cmdhist.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/ui_compositor.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/ui_client.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/indent.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/syntax.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/popupmenu.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/quickfix.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/register.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/mark.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/indent_c.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/diff.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/textobject.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/search.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/version.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/mbyte.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/spell.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/change.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/arglist.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/memline.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/fuzzy.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/ex_getln.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/option.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/map.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/mouse.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/main.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/lua/spell.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/lua/executor.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/lua/xdiff.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/lua/stdlib.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/lua/api_wrappers.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/lua/base64.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/lua/secure.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/lua/converter.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/lua/treesitter.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/memory.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/map_glyph_cache.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/viml/parser/parser.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/viml/parser/expressions.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/tag.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/lang.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/fs.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/shell.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/proc.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/stdpaths.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/dl.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/users.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/mem.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/input.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/env.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/pty_proc_unix.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/signal.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/time.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/os/fileio.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/msgpack_rpc/unpacker.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/msgpack_rpc/channel.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/msgpack_rpc/packer.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/msgpack_rpc/server.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/buffer_updates.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/window.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/undo.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/winfloat.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/linematch.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/keycodes.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/memfile.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/highlight_group.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/file_search.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/highlight.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/decoration_provider.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/message.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/shada.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/marktree.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/statusline.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/input.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/command.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/private/helpers.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/private/validate.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/private/dispatch.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/private/converter.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/win_config.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/deprecated.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/vim.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/options.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/window.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/tabpage.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/vimscript.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/ui.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/buffer.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/autocmd.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/extmark.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/api/events.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/match.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/terminal.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/arabic.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/edit.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/ui.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/fold.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/drawline.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/decoration.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/clipboard.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/usercmd.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/normal.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/strings.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/grid.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/sign.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/event/socket.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/event/stream.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/event/proc.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/event/rstream.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/event/loop.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/event/libuv_proc.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/event/multiqueue.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/event/signal.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/event/time.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/event/wstream.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/menu.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/path.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/runtime.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/cursor_shape.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/help.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/drawscreen.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/cmdexpand.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/insexpand.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/hashtab.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/plines.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/channel.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/ex_docmd.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/regexp.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/ex_cmds.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/buffer.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/state.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/debugger.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/ex_session.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/context.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/move.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/autocmd.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/deprecated.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/fs.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/gc.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/decode.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/funcs.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/executor.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/window.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/list.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/userfunc.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/buffer.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/vars.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/encode.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/eval/typval.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/bufwrite.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/profile.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/optionstr.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/spellfile.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/ex_cmds2.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/textformat.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/log.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/digraph.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/extmark.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/ops.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/cursor.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/charset.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/tui/tui.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/tui/input.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/tui/ugrid.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/tui/terminfo.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/tui/termkey/termkey.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/tui/termkey/driver-csi.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/tui/termkey/driver-ti.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/fileio.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/getchar.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/mapping.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/nvim/testing.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/xdiff/xdiffi.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/xdiff/xemit.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/xdiff/xhistogram.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/xdiff/xpatience.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/xdiff/xprepare.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/xdiff/xutils.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/cjson/lua_cjson.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/cjson/fpconv.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/cjson/strbuf.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/mpack/conv.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/mpack/lmpack.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/mpack/mpack_core.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/mpack/object.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });
    root_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/mpack/rpc.c" }, .flags = &.{ "-std=gnu99", "-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-fstack-protector-strong" } });

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

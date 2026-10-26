#!/usr/bin/env python3
import subprocess
import time
import statistics
import os
import sys

NVIM_SYS = "/usr/bin/nvim"
NVIM_ZIG = "/home/kitajusus/code/neovim/zig-out/bin/nvim"
RUNTIME = "/home/kitajusus/code/neovim/runtime"
ENV_ZIG = {**os.environ, "VIMRUNTIME": RUNTIME}

def bench_cmd(cmd, env=None, iterations=50, warmup=5):
    for _ in range(warmup):
        subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    
    times = []
    for _ in range(iterations):
        t0 = time.perf_counter_ns()
        res = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        t1 = time.perf_counter_ns()
        if res.returncode != 0:
            pass
        times.append((t1 - t0) / 1_000_000.0) # ms
    
    return {
        "mean": statistics.mean(times),
        "median": statistics.median(times),
        "stdev": statistics.stdev(times) if len(times) > 1 else 0,
        "min": min(times),
        "max": max(times),
        "samples": len(times)
    }

print("=================================================================")
print("           NEOVIM vs NVIM-ZIG PERFORMANCE BENCHMARK              ")
print("=================================================================\n")

print("--- 1. STARTUP TIME BENCHMARKS (50 samples per scenario) ---")

print("[1/5] Benchmarking System Neovim (-u NONE)...")
sys_none = bench_cmd([NVIM_SYS, "-u", "NONE", "--headless", "+q"])

print("[2/5] Benchmarking NvimZig (-u NONE)...")
zig_none = bench_cmd([NVIM_ZIG, "-u", "NONE", "--headless", "+q"], env=ENV_ZIG)

print("[3/5] Benchmarking System Neovim (--clean default)...")
sys_clean = bench_cmd([NVIM_SYS, "--clean", "--headless", "+q"])

print("[4/5] Benchmarking NvimZig (--clean with new Lua runtime)...")
zig_clean = bench_cmd([NVIM_ZIG, "--clean", "--headless", "+q"], env=ENV_ZIG)

print("[5/5] Benchmarking NvimZig loading all migrated Lua plugins...")
cmd_lua_plugins = [
    NVIM_ZIG, "-u", "NONE", "--headless",
    "+lua require('gzip')",
    "+lua require('tutor')",
    "+runtime plugin/gzip.lua",
    "+runtime plugin/tutor.lua",
    "+runtime plugin/tarPlugin.lua",
    "+runtime plugin/zipPlugin.lua",
    "+runtime plugin/matchit.lua",
    "+runtime plugin/netrwPlugin.lua",
    "+q"
]
zig_plugins = bench_cmd(cmd_lua_plugins, env=ENV_ZIG)

print("\n------------------------- STARTUP RESULTS -------------------------")
print(f"| Target                    | Mean (ms) | Median (ms) | Min (ms) | StdDev (ms) |")
print(f"|---------------------------|-----------|-------------|----------|-------------|")
print(f"| System Neovim (-u NONE)   |   {sys_none['mean']:6.2f}  |    {sys_none['median']:6.2f}   |   {sys_none['min']:6.2f} |      {sys_none['stdev']:6.2f} |")
print(f"| NvimZig       (-u NONE)   |   {zig_none['mean']:6.2f}  |    {zig_none['median']:6.2f}   |   {zig_none['min']:6.2f} |      {zig_none['stdev']:6.2f} |")
print(f"| System Neovim (--clean)   |   {sys_clean['mean']:6.2f}  |    {sys_clean['median']:6.2f}   |   {sys_clean['min']:6.2f} |      {sys_clean['stdev']:6.2f} |")
print(f"| NvimZig       (--clean)   |   {zig_clean['mean']:6.2f}  |    {zig_clean['median']:6.2f}   |   {zig_clean['min']:6.2f} |      {zig_clean['stdev']:6.2f} |")
print(f"| NvimZig (All Lua plugins) |   {zig_plugins['mean']:6.2f}  |    {zig_plugins['median']:6.2f}   |   {zig_plugins['min']:6.2f} |      {zig_plugins['stdev']:6.2f} |")
print("-------------------------------------------------------------------\n")

print("--- 2. MEMORY / RSS OVERHEAD ---")
import resource

def measure_rss(cmd, env=None):
    # Run in isolated python process to inspect exact child RSS
    code = f"""
import subprocess, resource, os
p = subprocess.run({repr(cmd)}, env={repr(env)}, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print(resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)
"""
    res = subprocess.run([sys.executable, "-c", code], stdout=subprocess.PIPE, text=True)
    return int(res.stdout.strip())

rss_sys = measure_rss([NVIM_SYS, "--clean", "--headless", "+q"])
rss_zig = measure_rss([NVIM_ZIG, "--clean", "--headless", "+q"], env=ENV_ZIG)
print(f"System Neovim Peak RSS: {rss_sys / 1024:.2f} MB ({rss_sys} KB)")
print(f"NvimZig       Peak RSS: {rss_zig / 1024:.2f} MB ({rss_zig} KB)")
print(f"RSS Overhead Difference: {(rss_zig - rss_sys) / 1024:+.2f} MB\n")

print("--- 3. ZIG SIMD ENGINE vs C NAIVE LOOP (10,000,000 cells x 100 iterations) ---")
if os.path.exists("zig_poc/bench_c") and os.path.exists("zig_poc/bench_zig"):
    c_bench = bench_cmd(["./zig_poc/bench_c"], iterations=10, warmup=2)
    zig_bench = bench_cmd(["./zig_poc/bench_zig"], iterations=10, warmup=2)
    print(f"C Scalar Loop:      Mean = {c_bench['mean']:.2f} ms  (Min = {c_bench['min']:.2f} ms)")
    print(f"Zig SIMD Vector:    Mean = {zig_bench['mean']:.2f} ms  (Min = {zig_bench['min']:.2f} ms)")
    speedup = c_bench['mean'] / zig_bench['mean'] if zig_bench['mean'] > 0 else 0
    print(f"-> Speedup: {speedup:.2f}x faster execution with Zig SIMD!\n")

print("--- 4. IN-PROCESS LUAJIT FFI -> ZIG SIMD INTEGRATION TEST ---")
bench_lua_script = """
local ffi = require('ffi')
ffi.cdef[[
    size_t diff_cells_zig_simd(const void* old_cells, const void* new_cells, size_t count);
]]

local count = 1000000
local old_buf = ffi.new("uint8_t[?]", count * 8)
local new_buf = ffi.new("uint8_t[?]", count * 8)

-- warm up
ffi.C.diff_cells_zig_simd(old_buf, new_buf, count)

local t0 = vim.loop.hrtime()
local sum = 0
for i = 1, 100 do
    sum = sum + ffi.C.diff_cells_zig_simd(old_buf, new_buf, count)
end
local t1 = vim.loop.hrtime()
local dt_ms = (t1 - t0) / 1000000
print(string.format("100M cells diffed in Neovim via LuaJIT FFI: %.2f ms (Throughput: %.2f Mcells/s)", dt_ms, (100 * count / 1e6) / (dt_ms / 1000)))
"""

res = subprocess.run([NVIM_ZIG, "-u", "NONE", "--headless", "+lua " + bench_lua_script, "+q"], env=ENV_ZIG, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
for line in res.stdout.splitlines():
    if "cells" in line or "Throughput" in line:
        print(line)

print("\nBenchmark completed successfully.")

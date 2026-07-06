#!/usr/bin/env bash
# High-performance Neovim + Zig builder and packager
# This script compiles Neovim using the native Zig compiler in ReleaseFast mode,
# stages the binary, runtime files, and treesitter parsers, and archives them
# into a fully relocatable and self-contained tarball.

set -e

echo "==============================================="
echo "Building Neovim with Zig in ReleaseFast mode..."
echo "==============================================="

# Build the project
zig build -Doptimize=ReleaseFast "$@"

echo "==============================================="
echo "Staging files for packaging..."
echo "==============================================="

# Clean staging directory
STAGING_DIR="nvim-linux-x64-zig"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/bin"
mkdir -p "$STAGING_DIR/lib"
mkdir -p "$STAGING_DIR/share/nvim"

# Copy binaries
cp zig-out/bin/nvim "$STAGING_DIR/bin/"
cp zig-out/bin/xxd "$STAGING_DIR/bin/"
cp zig-out/bin/tee "$STAGING_DIR/bin/"

# Copy parsers/libraries
if [ -d "zig-out/lib" ]; then
    cp -r zig-out/lib/* "$STAGING_DIR/lib/"
fi

# Copy runtime files
cp -r runtime "$STAGING_DIR/share/nvim/runtime"

# Merge generated runtime files (docs, syntax updates) from zig-out
if [ -d "zig-out/runtime" ]; then
    cp -r zig-out/runtime/* "$STAGING_DIR/share/nvim/runtime/"
fi

echo "==============================================="
echo "Creating relocatable archive..."
echo "==============================================="

# Package the staging directory
PACKAGE_NAME="nvim-linux-x64-zig.tar.gz"
rm -f "$PACKAGE_NAME"
tar -czf "$PACKAGE_NAME" "$STAGING_DIR"

# Clean up staging directory
rm -rf "$STAGING_DIR"

echo "==============================================="
echo "Package created successfully: $PACKAGE_NAME"
echo "==============================================="
echo "To run Neovim from the package:"
echo "  tar -xzf $PACKAGE_NAME"
echo "  ./$STAGING_DIR/bin/nvim"
echo "==============================================="

#!/bin/bash
# ABOUTME: Local cross-compile build script for ARM64 Windows using dockcross
# ABOUTME: Mirrors the GH Actions build but runs locally for fast iteration

set -e

MINTTY_LOCAL="/home/achen/git/gh/mintty"

# Run the build inside dockcross/windows-arm64 using the local mintty source
# --user 1000:1000 preserves file ownership (avoids root-owned output files)
docker run --rm \
  --user 1000:1000 \
  -v "$PWD:/work" \
  -v "$MINTTY_LOCAL:/mintty" \
  -w /work \
  dockcross/windows-arm64 \
  bash -c "cd /mintty/src && make -j\$(nproc) TARGET=Msys-aarch64 CC=aarch64-w64-mingw32-clang RC=aarch64-w64-mingw32-windres 2>&1"

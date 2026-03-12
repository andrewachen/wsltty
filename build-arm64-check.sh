#!/bin/bash
# ABOUTME: Build ARM64 locally and show filtered errors/warnings for fast iteration
# ABOUTME: Run with: bash build-arm64-check.sh

set -e
bash "$(dirname "$0")/build-arm64-local.sh" 2>&1 | \
  grep -E "error:|fatal error:" | \
  grep -v "^make" | \
  sort -u

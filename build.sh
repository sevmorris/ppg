#!/usr/bin/env bash
set -euo pipefail

# Build PasswordGen as a release binary
swift build -c release

echo ""
echo "Build complete."
echo "Run with: swift run"
echo "Binary: .build/release/PasswordGen"

#!/usr/bin/env bash
set -euo pipefail

# Check if swift-format is installed
if ! command -v swift-format >/dev/null 2>&1; then
  echo "❌ swift-format not found."
  echo "Install via Homebrew: brew install swift-format"
  echo "Or download from: https://github.com/apple/swift-format"
  exit 1
fi

echo "🔧 Formatting Swift code..."

# Format all Swift files in the project
swift-format format --in-place --recursive \
  MineOpsCompanion \
  MineOpsCompanionPackage/Sources \
  MineOpsCompanionPackage/Tests \
  MineOpsCompanionUITests

echo "✅ Code formatting complete!"

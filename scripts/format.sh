#!/bin/bash
set -e

# Script to format Swift code using swift-format
# Usage: ./scripts/format.sh [--check]

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Check if swift-format is available
if ! command -v swift-format &> /dev/null; then
    echo "❌ swift-format is not installed."
    echo "Install it with: brew install swift-format"
    echo "Or visit: https://github.com/apple/swift-format"
    exit 1
fi

# Determine mode (check or format)
MODE="format"
if [[ "$1" == "--check" ]]; then
    MODE="check"
fi

echo "🔍 Running swift-format in $MODE mode..."

# Find all Swift files in the package
SWIFT_FILES=$(find "$PROJECT_ROOT/MineOpsCompanionPackage" -name "*.swift" -not -path "*/.*")

if [[ "$MODE" == "check" ]]; then
    # Check mode: lint without modifying files
    swift-format lint --strict --parallel --recursive "$PROJECT_ROOT/MineOpsCompanionPackage"
    echo "✅ All Swift files are properly formatted"
else
    # Format mode: modify files in place
    for file in $SWIFT_FILES; do
        swift-format format --in-place "$file"
    done
    echo "✅ Formatted $(echo "$SWIFT_FILES" | wc -l | xargs) Swift files"
fi

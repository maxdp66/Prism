#!/bin/bash

# Script to regenerate content blocking rules from filter lists
# Usage: ./generate_rules.sh [options]
#
# Options:
#   --download    Download default filter lists (EasyList, EasyPrivacy, etc.)
#   --input FILE  Use local filter list file (can be specified multiple times)
#   --output FILE Output JSON file (default: ../Prism/Resources/blockerRules.json)
#   --max-rules N Maximum number of rules (default: unlimited)
#   --no-cosmetic Exclude cosmetic (CSS hide) rules

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ADBLOCK_GEN="$SCRIPT_DIR/target/release/adblock-generator"
OUTPUT_FILE="$SCRIPT_DIR/../Prism/Resources/blockerRules.json"

# Source cargo env if needed
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

# Check if binary exists
if [ ! -f "$ADBLOCK_GEN" ]; then
    echo "Building adblock-generator..."
    cd "$SCRIPT_DIR"
    cargo build --release
fi

# Build command
CMD="$ADBLOCK_GEN --output $OUTPUT_FILE"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --download)
            CMD="$CMD --download-defaults"
            shift
            ;;
        --input)
            CMD="$CMD --input $2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            CMD="$CMD --output $OUTPUT_FILE"
            shift 2
            ;;
        --max-rules)
            CMD="$CMD --max-rules $2"
            shift 2
            ;;
        --no-cosmetic)
            CMD="$CMD --include-cosmetic false"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Generating content blocking rules..."
echo "Output: $OUTPUT_FILE"

# Run the command
eval $CMD

echo "Done!"
echo ""
echo "To use these rules in Prism:"
echo "1. Add blockerRules.json to your Xcode project (Resources folder)"
echo "2. Ensure it's copied to the app bundle"
echo "3. Rebuild Prism"
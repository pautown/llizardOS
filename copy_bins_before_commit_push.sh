#!/bin/bash
#
# copy_bins_before_commit_push.sh
#
# Copies the latest ARM binaries and plugin data from the llizardgui-host
# build directory to the llizardOS resources folder.
#
# Run this script before committing/pushing to ensure llizardOS has
# the most up-to-date binaries.
#
# Usage: ./copy_bins_before_commit_push.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLIZARDGUI_HOST_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARM_BUILD_DIR="$LLIZARDGUI_HOST_ROOT/build-armv7-drm"
GOLANG_BLE_DIR="$LLIZARDGUI_HOST_ROOT/supporting_projects/golang_ble_client"
SALAMANDERS_DIR="$LLIZARDGUI_HOST_ROOT/supporting_projects/salamanders"

# Destination directories
BINS_DIR="$SCRIPT_DIR/resources/llizardgui/bins"
PLUGINS_DIR="$BINS_DIR/plugins"
DATA_DIR="$SCRIPT_DIR/resources/llizardgui/data"

echo "=============================================="
echo "LlizardOS Binary Copy Script"
echo "=============================================="
echo ""
echo "Source directories:"
echo "  ARM build:    $ARM_BUILD_DIR"
echo "  Golang BLE:   $GOLANG_BLE_DIR"
echo "  Plugin data:  $SALAMANDERS_DIR"
echo ""
echo "Destination:"
echo "  Binaries:     $BINS_DIR"
echo "  Plugins:      $PLUGINS_DIR"
echo "  Data:         $DATA_DIR"
echo ""

# Check if ARM build directory exists
if [ ! -d "$ARM_BUILD_DIR" ]; then
    echo "ERROR: ARM build directory not found: $ARM_BUILD_DIR"
    echo ""
    echo "Please build the ARM version first:"
    echo "  cd $LLIZARDGUI_HOST_ROOT"
    echo "  mkdir -p build-armv7-drm && cd build-armv7-drm"
    echo "  cmake -DCMAKE_TOOLCHAIN_FILE=../toolchain-armv7.cmake -DPLATFORM=DRM .."
    echo "  make -j\$(nproc)"
    exit 1
fi

# Check if llizardgui-host binary exists
if [ ! -f "$ARM_BUILD_DIR/llizardgui-host" ]; then
    echo "ERROR: llizardgui-host binary not found in ARM build directory"
    exit 1
fi

# Create directories if they don't exist
mkdir -p "$PLUGINS_DIR"
mkdir -p "$DATA_DIR/flashcards/questions"
mkdir -p "$DATA_DIR/millionaire/questions"

# ============================================
# Copy llizardGUI (main host application)
# ============================================
echo "Copying llizardGUI..."
cp "$ARM_BUILD_DIR/llizardgui-host" "$BINS_DIR/llizardGUI"
echo "  -> llizardGUI ($(du -h "$BINS_DIR/llizardGUI" | cut -f1))"

# ============================================
# Copy Mercury (BLE service)
# ============================================
MERCURY_BIN="$GOLANG_BLE_DIR/bin/mediadash-client"
if [ -f "$MERCURY_BIN" ]; then
    echo "Copying mercury (BLE service)..."
    cp "$MERCURY_BIN" "$BINS_DIR/mercury"
    echo "  -> mercury ($(du -h "$BINS_DIR/mercury" | cut -f1))"
else
    echo "WARNING: mediadash-client not found at $MERCURY_BIN"
    echo "  Mercury binary was not updated."
fi

# ============================================
# Copy Plugin Binaries (.so files)
# ============================================
echo ""
echo "Copying plugin binaries..."
PLUGIN_COUNT=0
for so_file in "$ARM_BUILD_DIR"/*.so; do
    if [ -f "$so_file" ]; then
        plugin_name=$(basename "$so_file")
        cp "$so_file" "$PLUGINS_DIR/$plugin_name"
        echo "  -> $plugin_name"
        PLUGIN_COUNT=$((PLUGIN_COUNT + 1))
    fi
done
echo "Copied $PLUGIN_COUNT plugins."

# ============================================
# Copy Plugin Data (questions, etc.)
# ============================================
echo ""
echo "Copying plugin data..."

# Flashcards questions
if [ -d "$SALAMANDERS_DIR/flashcards/questions" ]; then
    echo "  Flashcards questions..."
    rm -rf "$DATA_DIR/flashcards/questions"
    cp -r "$SALAMANDERS_DIR/flashcards/questions" "$DATA_DIR/flashcards/"
    FC_COUNT=$(find "$DATA_DIR/flashcards/questions" -type f | wc -l)
    echo "    -> $FC_COUNT files"
fi

# Millionaire questions
if [ -d "$SALAMANDERS_DIR/millionaire/questions" ]; then
    echo "  Millionaire questions..."
    rm -rf "$DATA_DIR/millionaire/questions"
    cp -r "$SALAMANDERS_DIR/millionaire/questions" "$DATA_DIR/millionaire/"
    ML_COUNT=$(find "$DATA_DIR/millionaire/questions" -type f | wc -l)
    echo "    -> $ML_COUNT files"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=============================================="
echo "Copy complete!"
echo "=============================================="
echo ""
echo "Files updated:"
echo "  - llizardGUI (host application)"
if [ -f "$MERCURY_BIN" ]; then
    echo "  - mercury (BLE service)"
fi
echo "  - $PLUGIN_COUNT plugin binaries"
echo "  - Plugin data (flashcards, millionaire)"
echo ""
echo "Next steps:"
echo "  git add resources/llizardgui/"
echo "  git commit -m \"Update binaries and plugin data\""
echo "  git push"
echo ""

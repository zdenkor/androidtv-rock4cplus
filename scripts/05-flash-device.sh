#!/bin/bash
# =============================================================================
# 05-flash-device.sh
# Flashes Android TV to Radxa ROCK 4C+ (RK3399-T)
# Supports: Android 9/11/12 BSPs
# =============================================================================

set -e

# Load build config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.build-config"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: No .build-config found. Run 02-download-source.sh first!"
    exit 1
fi

echo "============================================"
echo " Flashing Android TV to ROCK 4C+"
echo "============================================"
echo ""

# Search for build output in common locations
OUT_DIR=""
for d in "$WORK_DIR/rockdev/Image-rk3399" "$WORK_DIR/rockdev/Image" \
         "$WORK_DIR/out/target/product/rk3399" "$WORK_DIR/out/target/product/rk3399_box"; do
    if [ -d "$d" ]; then
        OUT_DIR="$d"
        break
    fi
done

if [ -z "$OUT_DIR" ]; then
    echo "ERROR: No build output found. Run 04-build-android.sh first."
    echo "Searched: rockdev/Image-rk3399, rockdev/Image, out/target/product/rk3399"
    exit 1
fi

# ---------------------------------------------------------------------------
# 1. Check for output files
# ---------------------------------------------------------------------------
echo "[1/4] Checking for built images..."
if [ ! -d "$OUT_DIR" ]; then
    echo "ERROR: Build output not found at $OUT_DIR"
    echo "Run 04-build-android.sh first."
    exit 1
fi

echo "Found build output at: $OUT_DIR"

# ---------------------------------------------------------------------------
# 2. Prepare device for flashing
# ---------------------------------------------------------------------------
echo "[2/4] Preparing device..."
echo ""
echo "IMPORTANT: Put your ROCK 4C+ into MaskROM/Loader mode:"
echo ""
echo "  Method 1 (MaskROM):"
echo "    1. Remove power and SD card"
echo "    2. Short the eMMC clock pin to GND"
echo "    3. Connect USB-C to your PC"
echo "    4. Remove the short"
echo ""
echo "  Method 2 (Loader mode):"
echo "    1. Hold the MASKROM button"
echo "    2. Connect USB-C to your PC"
echo "    3. Release the button"
echo ""
echo "  Method 3 (If Android is already running):"
echo "    adb reboot bootloader"
echo ""
read -rp "Press Enter when device is in Loader/MaskROM mode..."

# ---------------------------------------------------------------------------
# 3. Flash using Rockchip upgrade tool
# ---------------------------------------------------------------------------
echo "[3/4] Flashing firmware..."

# Check for Rockchip tools
RK_TOOLS="$WORK_DIR/tools/rkbin"
UPGRADE_TOOL="$RK_TOOLS/upgrade_tool"

if [ ! -f "$UPGRADE_TOOL" ]; then
    echo "Downloading Rockchip upgrade tool..."
    git clone --depth=1 https://github.com/rockchip-linux/tools.git /tmp/rk-tools
    UPGRADE_TOOL="/tmp/rk-tools/upgrade_tool"
fi

# Check if device is detected
echo "Checking for device..."
sudo "$UPGRADE_TOOL" LD

# Flash the update image
UPDATE_IMG="$WORK_DIR/rockdev/update.img"

if [ -f "$UPDATE_IMG" ]; then
    echo "Flashing update.img..."
    sudo "$UPGRADE_TOOL" UF "$UPDATE_IMG"
    sudo "$UPGRADE_TOOL" RD
    echo "Flash complete! Device will reboot."
else
    echo "update.img not found. Flashing individual images..."
    
    # Flash individual images
    IMAGES=(
        "MiniLoaderAll.bin"
        "parameter.txt"
        "uboot.img"
        "trust.img"
        "misc.img"
        "boot.img"
        "resource.img"
        "kernel.img"
        "dtbo.img"
        "vbmeta.img"
        "system.img"
        "vendor.img"
        "oem.img"
    )
    
    for img in "${IMAGES[@]}"; do
        if [ -f "$OUT_DIR/$img" ]; then
            echo "Flashing $img..."
            sudo "$UPGRADE_TOOL" DI "$img" "$OUT_DIR/$img"
        fi
    done
    
    echo "Flash complete!"
    sudo "$UPGRADE_TOOL" RD
fi

# ---------------------------------------------------------------------------
# 4. Alternative: Flash via SD card
# ---------------------------------------------------------------------------
echo "[4/4] Alternative flashing method (SD card)..."
echo ""
echo "If USB flashing doesn't work, you can use an SD card:"
echo ""
echo "  1. Insert a microSD card (8GB+) into your PC"
echo "  2. Identify the device: lsblk"
echo "  3. Flash using dd:"
echo "     sudo dd if=$UPDATE_IMG of=/dev/sdX bs=4M status=progress"
echo "     (Replace /dev/sdX with your SD card device)"
echo "  4. Insert SD card into ROCK 4C+ and power on"
echo ""

echo "============================================"
echo " Flashing complete!"
echo "============================================"
echo ""
echo "First boot may take 5-10 minutes."
echo "Connect HDMI and power on the device."
echo ""

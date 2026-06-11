#!/bin/bash
# =============================================================================
# 05-flash-device.sh
# Flashes Android TV to ROCK 4C+ (RK3399-T)
# Supports: USB (Rockchip upgrade tool) and SD card (dd)
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
         "$WORK_DIR/out/target/product/rk3399_ROCKPI4C_Plus_Android11" \
         "$WORK_DIR/out/target/product/rk3399_ROCKPI4C_Android11" \
         "$WORK_DIR/out/target/product/rk3399_ROCKPI4B_Android11" \
         "$WORK_DIR/out/target/product/rk3399_Android11" \
         "$WORK_DIR/out/target/product/rk3399_box" \
         "$WORK_DIR/out/target/product/rk3399"; do
    if [ -d "$d" ]; then
        OUT_DIR="$d"
        break
    fi
done

if [ -z "$OUT_DIR" ]; then
    echo "ERROR: No build output found. Run 04-build-android.sh first."
    echo "Searched: rockdev/Image-rk3399, rockdev/Image, out/target/product/rk3399*"
    exit 1
fi

echo "Found build output at: $OUT_DIR"

# ---------------------------------------------------------------------------
# 1. Check for output files
# ---------------------------------------------------------------------------
echo "[1/4] Checking for built images..."
if [ ! -d "$OUT_DIR" ]; then
    echo "ERROR: Build output not found at $OUT_DIR"
    echo "Run 04-build-android.sh first."
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Parse parameter.txt for partition offsets
# ---------------------------------------------------------------------------
PARAM_FILE="$OUT_DIR/parameter.txt"
if [ ! -f "$PARAM_FILE" ]; then
    echo "ERROR: parameter.txt not found at $PARAM_FILE"
    exit 1
fi

echo "Parsing partition layout from parameter.txt..."

# Parse partition offsets from CMDLINE in parameter.txt
# Format: name@offset(size),name@offset(size),...
# Sector size is 512 bytes
parse_partitions() {
    local cmdline="$1"
    local result=""
    # Extract mtdparts from cmdline
    local mtdparts="${cmdline#*mtdparts=}"
    if [ "$mtdparts" = "$cmdline" ]; then
        echo "ERROR: No mtdparts found in CMDLINE"
        return 1
    fi
    # mtdparts=rk29xxnand:partitions
    local partitions="${mtdparts#*:}"
    # Split by comma
    IFS=',' read -ra PARTS <<< "$partitions"
    for part in "${PARTS[@]}"; do
        # Format: size@offset(name) or -@offset(name:grow)
        if [[ "$part" =~ ^0x[0-9a-fA-F]+@0x[0-9a-fA-F]+\([^-]+\) ]]; then
            local size="${part%%@*}"     # hex size in sectors
            local rest="${part#*@}"      # offset(name)
            local offset="${rest%%(*}"    # hex offset
            local name="${rest#*(}"       # name)
            name="${name%)}"             # remove trailing )
            # Convert hex to decimal for dd seek=
            local seek=$((offset))
            echo "${name}:${seek}"
        fi
    done
}

# Map partition names to image files
declare -A PART_MAP=(
    ["boot"]="boot.img"
    ["recovery"]="recovery.img"
    ["dtbo"]="dtbo.img"
    ["vbmeta"]="vbmeta.img"
    ["super"]="super.img"
    ["system"]="system.img"
    ["vendor"]="vendor.img"
    ["odm"]="odm.img"
    ["product"]="product.img"
    ["cache"]="cache.img"
    ["userdata"]="userdata.img"
)

# Parse partitions
PARTITIONS=""
CMDLINE=$(grep '^CMDLINE:' "$PARAM_FILE" | head -1)
if [ -n "$CMDLINE" ]; then
    PARTITIONS=$(parse_partitions "$CMDLINE")
fi

# ---------------------------------------------------------------------------
# 3. Choose flashing method
# ---------------------------------------------------------------------------
echo ""
echo "Choose flashing method:"
echo ""
echo "  1) USB (Rockchip upgrade tool) - requires USB-C connection"
echo "  2) SD Card (dd) - write images directly to SD card"
echo ""
read -rp "Enter choice [1-2]: " FLASH_CHOICE

if [ "$FLASH_CHOICE" != "1" ] && [ "$FLASH_CHOICE" != "2" ]; then
    echo "Invalid choice. Exiting."
    exit 1
fi

# ---------------------------------------------------------------------------
# 4a. USB Flashing
# ---------------------------------------------------------------------------
if [ "$FLASH_CHOICE" = "1" ]; then
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

    echo "[3/4] Flashing firmware via USB..."

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
# 4b. SD Card Flashing
# ---------------------------------------------------------------------------
else
    echo ""
    echo "[3/4] SD Card flashing..."
    echo ""
    echo "Available partitions from parameter.txt:"
    echo "$PARTITIONS" | tr ':' '\n' | column -t || true
    echo ""

    # List available block devices
    echo "Available SD card devices:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E 'disk|sd'
    echo ""

    read -rp "Enter SD card device (e.g., sdb): " SD_DEV
    SDCARD="/dev/$SD_DEV"

    if [ ! -b "$SDCARD" ]; then
        echo "ERROR: $SDCARD is not a block device"
        exit 1
    fi

    echo ""
    echo "WARNING: This will ERASE all data on $SDCARD"
    read -rp "Are you sure? Type 'yes': " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi

    # Unmount all partitions
    echo "Unmounting $SDCARD..."
    sudo umount ${SDCARD}* 2>/dev/null || true

    # =========================================================================
    # STEP 1: Write Rockchip bootloader chain (CRITICAL for boot!)
    # =========================================================================
    # RK3399 BootROM loads idbloader.img from sector 64.
    # idbloader then loads uboot.img from sector 0x4000 and trust.img from 0x6000.
    # Without these, the CPU never starts — no blue LED, nothing on screen.
    echo ""
    echo "=== Step 1/2: Writing bootloader chain ==="

    # Search for bootloader files. Search order:
    #   1) prebuilt/  (known-good Radxa reference, in this repo) -- preferred
    #   2) build output dirs (your own U-Boot build)
    #   3) rkbin prebuilts assembled by the fallback block below
    # To force using your own U-Boot build, rename or move prebuilt/ aside.
    PREBUILT_DIR="$SCRIPT_DIR/../prebuilt"
    IDBLOADER=""
    UBOOT_IMG=""
    TRUST_IMG=""

    for search_dir in \
        "$PREBUILT_DIR" \
        "$OUT_DIR" \
        "$WORK_DIR/u-boot" \
        "$WORK_DIR/rockdev" \
        "$WORK_DIR/rockdev/Image-rk3399" \
        "$WORK_DIR/rockdev/Image"; do
        [ -f "$search_dir/idbloader.img" ] && IDBLOADER="$search_dir/idbloader.img" && break
    done

    for search_dir in \
        "$PREBUILT_DIR" \
        "$OUT_DIR" \
        "$WORK_DIR/u-boot" \
        "$WORK_DIR/rockdev" \
        "$WORK_DIR/rockdev/Image-rk3399" \
        "$WORK_DIR/rockdev/Image"; do
        [ -f "$search_dir/uboot.img" ] && UBOOT_IMG="$search_dir/uboot.img" && break
    done

    for search_dir in \
        "$PREBUILT_DIR" \
        "$OUT_DIR" \
        "$WORK_DIR/u-boot" \
        "$WORK_DIR/rockdev" \
        "$WORK_DIR/rockdev/Image-rk3399" \
        "$WORK_DIR/rockdev/Image"; do
        [ -f "$search_dir/trust.img" ] && TRUST_IMG="$search_dir/trust.img" && break
    done

    # Tell the user which boot chain source we're using
    if [ -n "$IDBLOADER" ]; then
        case "$IDBLOADER" in
            "$PREBUILT_DIR"/*) echo "  Boot chain source: prebuilt/ (known-good Radxa reference)" ;;
            *)                  echo "  Boot chain source: $IDBLOADER (your build output)" ;;
        esac
    fi

    # Write idbloader.img at sector 64 (BootROM entry point)
    if [ -n "$IDBLOADER" ]; then
        echo "  Writing idbloader.img -> sector 64..."
        sudo dd if="$IDBLOADER" of="$SDCARD" seek=64 bs=512 conv=notrunc 2>/dev/null
    else
        # Fallback: assemble idbloader.img from rkbin prebuilt binaries
        # Must use loaderimage (not cat!) to create proper Rockchip SD header
        # ROCK 4C+ uses RK3399-T with LPDDR4 — prefer rk3399pro DDR binaries
        RKBIN_DIR="$WORK_DIR/rkbin"
        LOADERIMAGE="$RKBIN_DIR/tools/loaderimage"
        DDR_BIN=$(ls "$RKBIN_DIR"/bin/rk33/rk3399pro_ddr_*MHz_v*.bin 2>/dev/null | head -1)
        if [ -z "$DDR_BIN" ]; then
            DDR_BIN=$(ls "$RKBIN_DIR"/bin/rk33/rk3399_ddr_*MHz_v*.bin 2>/dev/null | head -1)
        fi
        MINILOADER=$(ls "$RKBIN_DIR"/bin/rk33/rk3399_miniloader_v*.bin 2>/dev/null | grep -v spinor | head -1)
        if [ -f "$LOADERIMAGE" ] && [ -f "$DDR_BIN" ] && [ -f "$MINILOADER" ]; then
            echo "  Assembling idbloader.img from rkbin prebuilts..."
            echo "    DDR:     $(basename "$DDR_BIN")"
            echo "    Loader:  $(basename "$MINILOADER")"
            "$LOADERIMAGE" --pack --uboot "$DDR_BIN" /tmp/idbloader.img
            cat "$MINILOADER" >> /tmp/idbloader.img
            echo "  Writing idbloader.img -> sector 64..."
            sudo dd if=/tmp/idbloader.img of="$SDCARD" seek=64 bs=512 conv=notrunc 2>/dev/null
            rm -f /tmp/idbloader.img
        else
            echo "  WARNING: Cannot assemble idbloader.img!"
            echo "    loaderimage: $LOADERIMAGE"
            echo "    DDR bin:     $DDR_BIN"
            echo "    Miniloader:  $MINILOADER"
        fi
    fi

    # Write uboot.img at sector 0x4000 (16384)
    if [ -n "$UBOOT_IMG" ]; then
        echo "  Writing uboot.img -> sector 0x4000 (16384)..."
        sudo dd if="$UBOOT_IMG" of="$SDCARD" seek=16384 bs=512 conv=notrunc 2>/dev/null
    else
        echo "  WARNING: uboot.img not found!"
    fi

    # Write trust.img at sector 0x6000 (24576)
    if [ -n "$TRUST_IMG" ]; then
        echo "  Writing trust.img -> sector 0x6000 (24576)..."
        sudo dd if="$TRUST_IMG" of="$SDCARD" seek=24576 bs=512 conv=notrunc 2>/dev/null
    else
        echo "  WARNING: trust.img not found!"
    fi

    # =========================================================================
    # STEP 2: Write Android partition images
    # =========================================================================
    echo ""
    echo "=== Step 2/2: Writing Android images ==="

    # Write each partition
    write_partition() {
        local name="$1"
        local seek="$2"
        local img="${PART_MAP[$name]}"

        if [ -z "$img" ]; then
            return
        fi

        local img_path="$OUT_DIR/$img"
        if [ -f "$img_path" ]; then
            local size=$(stat -c%s "$img_path")
            local size_mb=$((size / 1024 / 1024))
            echo "  Writing $img -> $name (seek=$seek, ${size_mb}MB)..."
            sudo dd if="$img_path" of="$SDCARD" seek="$seek" bs=512 conv=notrunc 2>/dev/null
        fi
    }

    # Write each partition from parsed layout
    while IFS=: read -r name seek; do
        if [ -n "$name" ] && [ -n "$seek" ]; then
            write_partition "$name" "$seek"
        fi
    done <<< "$PARTITIONS"

    echo ""
    echo "Syncing..."
    sudo sync
    sudo eject "$SDCARD" 2>/dev/null || true

    echo ""
    echo "SD card flashed successfully!"
    echo "Insert the SD card into ROCK 4C+ and power on."
fi

# ---------------------------------------------------------------------------
# 5. Done
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo " Flashing complete!"
echo "============================================"
echo ""
echo "First boot may take 5-10 minutes."
echo "Connect HDMI and power on the device."
echo ""
#!/bin/bash
# =============================================================================
# 04-build-android.sh
# Builds Android TV 12 for Radxa ROCK 4C+ (RK3399-T)
# Uses Vicharak BSP build.sh (kernel 5.10)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.build-config"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: No .build-config found. Run 00-setup-usb.sh first!"
    exit 1
fi

echo "============================================"
echo " Building Android TV 12"
echo " BSP: Vicharak (kernel 5.10)"
echo " Target: Radxa ROCK 4C+ (RK3399-T)"
echo "============================================"
echo ""

cd "$WORK_DIR"

# ---------------------------------------------------------------------------
# 1. Set up environment
# ---------------------------------------------------------------------------
echo "[1/4] Setting up build environment..."
source build/envsetup.sh

# Try to detect the lunch target from previous config
if lunch rk3399-userdebug 2>/dev/null; then
    LUNCH_TARGET="rk3399-userdebug"
elif lunch vaaman-userdebug 2>/dev/null; then
    LUNCH_TARGET="vaaman-userdebug"
else
    echo "Available targets:"
    lunch 2>/dev/null | grep -i rk3399 || true
    read -rp "Enter lunch target: " LUNCH_TARGET
    lunch "$LUNCH_TARGET"
fi
echo "Lunch target: $LUNCH_TARGET"

# ---------------------------------------------------------------------------
# 2. Build type selection
# ---------------------------------------------------------------------------
echo ""
echo "[2/4] Build type:"
echo "  1) Full build (U-Boot + Android + Kernel + update.img)"
echo "  2) Android only (skip U-Boot/Kernel if already built)"
echo "  3) Kernel only"
echo "  4) U-Boot only"
echo ""
read -rp "Enter choice [1-4]: " BUILD_CHOICE

# ---------------------------------------------------------------------------
# 3. Build using Vicharak build.sh
# ---------------------------------------------------------------------------
echo "[3/4] Starting build..."
echo "This will take 4-8 hours on first build."
echo ""

START_TIME=$(date +%s)

case $BUILD_CHOICE in
    1)
        # Full build: U-Boot + Android + Kernel + update image
        echo "Running: ./build.sh -UACKup"
        ./build.sh -UACKup 2>&1 | tee build.log
        ;;
    2)
        # Android only
        echo "Running: ./build.sh -A"
        ./build.sh -A 2>&1 | tee build.log
        ;;
    3)
        # Kernel only
        echo "Running: ./build.sh -CK"
        ./build.sh -CK 2>&1 | tee build.log
        ;;
    4)
        # U-Boot only
        echo "Running: ./build.sh -U"
        ./build.sh -U 2>&1 | tee build.log
        ;;
    *)
        echo "Invalid choice. Running full build."
        ./build.sh -UACKup 2>&1 | tee build.log
        ;;
esac

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

# ---------------------------------------------------------------------------
# 4. Build summary
# ---------------------------------------------------------------------------
echo ""
echo "[4/4] Build summary..."
echo ""
echo "============================================"
echo " Build Complete!"
echo "============================================"
echo ""
echo "Build time: $((BUILD_TIME / 60)) minutes $((BUILD_TIME % 60)) seconds"
echo ""

# Find output images
echo "Output images:"
echo "----------------------------------------"

# Vicharak output is typically in rockdev/Image-rk3399/
for img_dir in rockdev/Image-rk3399 rockdev/Image-* rockdev/Image; do
    if [ -d "$img_dir" ]; then
        echo "Location: $img_dir/"
        ls -lh "$img_dir"/*.img 2>/dev/null | awk '{print "  " $NF " (" $5 ")"}'
        break
    fi
done

echo ""
echo "Key files:"
echo "  update.img   - Full firmware (flash this)"
echo "  boot.img     - Kernel + ramdisk"
echo "  system.img   - Android system"
echo "  vendor.img   - Vendor partition"
echo ""

echo "Next step: Run 05-flash-device.sh"
echo ""
echo "============================================"
echo ""
echo "Build time: $((BUILD_TIME / 60)) minutes $((BUILD_TIME % 60)) seconds"
echo ""

# List output files
echo "Output files:"
echo "----------------------------------------"
find out/target/product/rk3399_ROCKPI4C* -maxdepth 1 -type f \( -name "*.img" -o -name "*.zip" \) 2>/dev/null | while read -r f; do
    SIZE=$(du -h "$f" | cut -f1)
    echo "  $(basename "$f") ($SIZE)"
done

echo ""
echo "Key output files:"
echo "  - boot.img          : Kernel + ramdisk"
echo "  - system.img        : Android system partition"
echo "  - vendor.img        : Vendor partition (HALs, firmware)"
echo "  - dtbo.img          : Device tree overlay"
echo "  - update.img        : Full firmware (Rockchip format)"
echo "  - *.zip             : OTA update package"
echo ""

echo "Next step: Run 05-flash-device.sh to flash to ROCK 4C+"
echo ""

#!/bin/bash
# =============================================================================
# 03-configure-build.sh
# Configures Android TV 12 build for Radxa ROCK 4C+ (RK3399-T)
# Uses Vicharak BSP (kernel 5.10, device/rockchip/rk3399)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default work directory (USB drive mount point)
WORK_DIR="${WORK_DIR:-/mnt/aosp-build/androidtv-rock4cplus}"

# Optionally load .build-config if it exists (for custom paths)
CONFIG_FILE="$SCRIPT_DIR/../.build-config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

echo "============================================"
echo " Configuring Android TV 12 Build"
echo " BSP: Vicharak (kernel 5.10)"
echo " Target: Radxa ROCK 4C+ (RK3399-T)"
echo "============================================"
echo ""

# Resolve script directory BEFORE changing to WORK_DIR
SCRIPT_DIR_FIX="$(cd "$(dirname "$0")" && pwd)"

cd "$WORK_DIR"

# ---------------------------------------------------------------------------
# 1. Set up build environment
# ---------------------------------------------------------------------------
echo "[1/7] Setting up build environment..."
source build/envsetup.sh

# ---------------------------------------------------------------------------
# 2. Copy Android kernel configs (Vicharak step)
# ---------------------------------------------------------------------------
echo "[2/7] Copying Android kernel configs..."
if [ -d "mkcombinedroot/configs" ]; then
    cp -vr mkcombinedroot/configs/android-1* kernel-5.10/arch/arm64/configs/ 2>/dev/null || true
    echo "Kernel configs copied to kernel-5.10/"
fi

# Fix: Vaaman BoardConfig defaults to kernel 4.19, but BSP has 5.10
VAAMAN_BC="device/rockchip/rk3399/vaaman/BoardConfig.mk"
if [ -f "$VAAMAN_BC" ]; then
    if grep -q "PRODUCT_KERNEL_VERSION := 4.19" "$VAAMAN_BC"; then
        sed -i 's/PRODUCT_KERNEL_VERSION := 4.19/PRODUCT_KERNEL_VERSION := 5.10/' "$VAAMAN_BC"
        echo "Fixed kernel version: 4.19 -> 5.10 in Vaaman BoardConfig"
    fi
fi

# Fix: U-Boot make.sh uses relative path for prebuilt GCC, which fails on Debian 13
UBOOT_MAKE_SH="u-boot/make.sh"
if [ -f "$UBOOT_MAKE_SH" ]; then
    if grep -q "CROSS_COMPILE_ARM64=../prebuilts" "$UBOOT_MAKE_SH"; then
        ABS_PATH="$WORK_DIR/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-"
        sed -i "s|CROSS_COMPILE_ARM64=../prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-|CROSS_COMPILE_ARM64=$ABS_PATH|" "$UBOOT_MAKE_SH"
        echo "Fixed U-Boot toolchain path to absolute in make.sh"
    fi
fi

# ---------------------------------------------------------------------------
# 3. Select lunch target
# ---------------------------------------------------------------------------
echo "[3/7] Selecting lunch target..."
echo ""

# Vicharak BSP uses rk3399 Vaaman device config
echo "Available RK3399 device configs:"
if [ -d "device/rockchip/rk3399" ]; then
    ls device/rockchip/rk3399/*.mk 2>/dev/null | while read -r f; do
        echo "  $(basename "$f")"
    done
fi

# Try to find the correct lunch target
if lunch rk3399-userdebug 2>/dev/null; then
    LUNCH_TARGET="rk3399-userdebug"
elif lunch vaaman-userdebug 2>/dev/null; then
    LUNCH_TARGET="vaaman-userdebug"
else
    echo ""
    echo "Available lunch targets:"
    lunch 2>/dev/null | grep -i rk3399 || true
    echo ""
    read -rp "Enter lunch target manually: " LUNCH_TARGET
    lunch "$LUNCH_TARGET"
fi

echo "Lunch target: $LUNCH_TARGET"

# ---------------------------------------------------------------------------
# 4. Configure for Android TV
# ---------------------------------------------------------------------------
echo "[4/7] Configuring for Android TV..."

DEVICE_MK="device/rockchip/rk3399/device.mk"
if [ ! -f "$DEVICE_MK" ]; then
    DEVICE_MK="device/rockchip/common/device.mk"
fi

if [ -f "$DEVICE_MK" ]; then
    if ! grep -q "ro.build.characteristics=tv" "$DEVICE_MK" 2>/dev/null; then
        cat >> "$DEVICE_MK" << 'EOF'

# === Android TV Configuration ===
PRODUCT_CHARACTERISTICS := tv

# Leanback (Android TV launcher)
PRODUCT_PACKAGES += \
    LeanbackLauncher \
    TvSettings \
    TvProvider \
    TvInputService

# Android TV system properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.build.characteristics=tv \
    ro.com.android.dataroaming=false \
    persist.sys.strictmode.visual=false
EOF
        echo "Android TV config added to $DEVICE_MK"
    else
        echo "Android TV config already present"
    fi
fi

# ---------------------------------------------------------------------------
# 5. Apply ROCK 4C+ device tree (RK3399-T)
# ---------------------------------------------------------------------------
echo "[5/7] Applying ROCK 4C+ device tree..."

DTS_DIR="kernel-5.10/arch/arm64/boot/dts/rockchip"

if [ -d "$DTS_DIR" ]; then
    echo "Found DTS directory: $DTS_DIR"
    
    echo "Existing RK3399 DTS files:"
    ls "$DTS_DIR"/rk3399-*.dts 2>/dev/null | while read -r f; do
        echo "  $(basename "$f")"
    done
    
    if [ -f "$DTS_DIR/rk3399-rock-pi-4.dts" ]; then
        cp "$DTS_DIR/rk3399-rock-pi-4.dts" "$DTS_DIR/rk3399-rock-4c-plus.dts"
        echo "Created rk3399-rock-4c-plus.dts from ROCK Pi 4 template"
    elif [ -f "$DTS_DIR/rk3399-vaaman.dts" ]; then
        cp "$DTS_DIR/rk3399-vaaman.dts" "$DTS_DIR/rk3399-rock-4c-plus.dts"
        echo "Created rk3399-rock-4c-plus.dts from Vaaman template"
    else
        echo "WARNING: No suitable base DTS found."
    fi
else
    echo "WARNING: DTS directory not found at $DTS_DIR"
fi

# ---------------------------------------------------------------------------
# 6. Configure kernel for Android TV
# ---------------------------------------------------------------------------
echo "[6/7] Configuring kernel for Android TV..."

KERNEL_CONFIG="kernel-5.10/arch/arm64/configs/rockchip_defconfig"
if [ ! -f "$KERNEL_CONFIG" ]; then
    KERNEL_CONFIG=$(ls kernel-5.10/arch/arm64/configs/android-* 2>/dev/null | head -1)
fi

if [ -f "$KERNEL_CONFIG" ]; then
    echo "Using kernel config: $KERNEL_CONFIG"
    for opt in \
        "CONFIG_DRM_DW_HDMI_CEC=y" \
        "CONFIG_INPUT_JOYSTICK=y" \
        "CONFIG_IR_GPIO_CIR=y" \
        "CONFIG_IR_RC5_DECODER=y" \
        "CONFIG_IR_NEC_DECODER=y"; do
        if ! grep -q "^${opt%%=*}" "$KERNEL_CONFIG" 2>/dev/null; then
            echo "$opt" >> "$KERNEL_CONFIG"
        fi
    done
    echo "Kernel config updated for Android TV"
else
    echo "WARNING: Kernel config not found."
fi

# ---------------------------------------------------------------------------
# 7. Fix prebuilts/sdk compatibility (Debian/WSL2 workarounds)
# ---------------------------------------------------------------------------
echo ""
echo "[7/7] Fixing prebuilts/sdk compatibility..."
echo ""

# Run Python sanitizer on prebuilts/sdk Android.bp files
if [ -f "$SCRIPT_DIR_FIX/fix_prebuilts.py" ]; then
    echo "Running prebuilts sanitizer..."
    python3 "$SCRIPT_DIR_FIX/fix_prebuilts.py"
fi

# Create missing AndroidManifest.xml files in prebuilts/sdk directories
MANIFEST_DIRS=(
    "prebuilts/sdk/current"
    "prebuilts/sdk/current/androidx"
    "prebuilts/sdk/current/extras/app-toolkit"
    "prebuilts/sdk/current/extras/constraint-layout"
    "prebuilts/sdk/current/extras/material-design"
    "prebuilts/sdk/current/extras/material-design-x"
    "prebuilts/sdk/current/support"
)
MANIFEST_CONTENT='<?xml version="1.0" encoding="utf-8"?><manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.android.stub" />'
for dir in "${MANIFEST_DIRS[@]}"; do
    if [ -d "$dir" ] && [ ! -f "$dir/AndroidManifest.xml" ]; then
        echo "$MANIFEST_CONTENT" > "$dir/AndroidManifest.xml"
        echo "Created $dir/AndroidManifest.xml"
    fi
done

# Fix broken symlinks for clang-3289846 libraries
CLANG_LIB_DIR="prebuilts/clang/host/linux-x86/clang-3289846/lib64"
GCC_SYSROOT="prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/sysroot/usr/lib"
if [ -d "$CLANG_LIB_DIR" ] && [ -d "$GCC_SYSROOT" ]; then
    for lib in libncurses.so.5 libtinfo.so.5; do
        if [ ! -e "$CLANG_LIB_DIR/$lib" ] && [ -e "$GCC_SYSROOT/$lib" ]; then
            ln -sf "../../../../../gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/sysroot/usr/lib/$lib" "$CLANG_LIB_DIR/$lib"
            echo "Fixed symlink: $CLANG_LIB_DIR/$lib"
        fi
    done
fi

# Fix build.sh kernel copy and IS_VEHICLE syntax
BUILD_SH="build.sh"
if [ -f "$BUILD_SH" ]; then
    # Fix 1: Add mkdir before kernel copy
    if grep -q 'cp -rf \$KERNEL_DEBUG \$OUT/kernel' "$BUILD_SH"; then
        sed -i 's|cp -rf \$KERNEL_DEBUG \$OUT/kernel|mkdir -p $(dirname \$OUT/kernel) \&\& cp -rf \$KERNEL_DEBUG \$OUT/kernel|' "$BUILD_SH"
        echo "Fixed build.sh: kernel copy mkdir"
    fi
    # Fix 2: Quote IS_VEHICLE variable
    if grep -q 'if \[ \$IS_VEHICLE = "true" \]; then' "$BUILD_SH"; then
        sed -i 's|if \[ \$IS_VEHICLE = "true" \]; then|if [ "\$IS_VEHICLE" = "true" ]; then|' "$BUILD_SH"
        echo "Fixed build.sh: IS_VEHICLE quoting"
    fi
fi

echo "Prebuilts fixes applied."

# ---------------------------------------------------------------------------
# 8. GApps Integration
# ---------------------------------------------------------------------------
echo ""
echo "[8/8] GApps Integration..."
echo ""
echo "Include Google Play & services for Android TV?"
echo "  1) MindTheGapps (Android TV 12.1) - Recommended"
echo "  2) NikGApps (Android TV, core) - Minimal"
echo "  3) Skip - No GApps"
echo ""
read -rp "Enter choice [1-3]: " GAPPS_CHOICE

GAPPS_DIR="$WORK_DIR/vendor/gapps"

case $GAPPS_CHOICE in
    1)
        echo "Downloading MindTheGapps for Android TV 12.1..."
        mkdir -p "$GAPPS_DIR"
        MTG_ZIP="$GAPPS_DIR/MindTheGapps-12.1.0-arm64-ATV.zip"
        if command -v wget &>/dev/null; then
            wget -q --show-progress -O "$MTG_ZIP" \
                "https://github.com/MindTheGapps/12.1.0-arm64/releases/latest/download/MindTheGapps-12.1.0-arm64-ATV.zip" 2>/dev/null || {
                echo "Auto-download failed. Download manually:"
                echo "  https://github.com/MindTheGapps/12.1.0-arm64/releases"
                echo "  Save as: $MTG_ZIP"
            }
        else
            echo "Download manually from: https://github.com/MindTheGapps/12.1.0-arm64/releases"
            echo "Save as: $MTG_ZIP"
        fi
        echo "MindTheGapps configured."
        ;;
    2)
        mkdir -p "$GAPPS_DIR"
        echo "Download NikGApps core ATV from:"
        echo "  https://sourceforge.net/projects/nikgapps/files/Releases/Android-12"
        echo "  Save to: $GAPPS_DIR/"
        ;;
    3)
        echo "Skipping GApps."
        ;;
esac

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo " Configuration complete!"
echo "============================================"
echo ""
echo "Build target: $LUNCH_TARGET"
echo "Kernel: kernel-5.10"
echo "Device: device/rockchip/rk3399"
echo ""
echo "Next step: Run 04-build-android.sh"
echo ""

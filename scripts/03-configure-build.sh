#!/bin/bash
# =============================================================================
# 03-configure-build.sh (Multi-BSP version)
# Configures Android build for RK3399 BSP selected in 02-download-source.sh
# Automatically applies BSP-specific configuration
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load .build-config with BSP_CHOICE and WORK_DIR
CONFIG_FILE="$SCRIPT_DIR/../.build-config"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: .build-config not found!"
    echo "Run 02-download-source.sh first to download a BSP."
    exit 1
fi

source "$CONFIG_FILE"

echo "============================================"
echo " Configuring Android Build"
echo " BSP_CHOICE: $BSP_CHOICE"
echo " WORK_DIR: $WORK_DIR"
echo "============================================"
echo ""

if [ ! -d "$WORK_DIR" ]; then
    echo "ERROR: WORK_DIR does not exist: $WORK_DIR"
    exit 1
fi

cd "$WORK_DIR"

# ---------------------------------------------------------------------------
# Common: Set up build environment
# ---------------------------------------------------------------------------
echo "[1/6] Setting up build environment..."
source build/envsetup.sh

# ---------------------------------------------------------------------------
# BSP-specific configuration
# ---------------------------------------------------------------------------
case $BSP_CHOICE in
    1)
        # ====================================================================
        # RADXA ANDROID 9 PIE
        # ====================================================================
        echo "[2/6] Configuring Radxa Android 9 Pie..."
        
        # Select lunch target
        if lunch rk3399_box-userdebug 2>/dev/null; then
            LUNCH_TARGET="rk3399_box-userdebug"
        else
            echo "Available targets:"
            lunch 2>/dev/null | grep -i rk3399 || true
            read -rp "Enter lunch target: " LUNCH_TARGET
            lunch "$LUNCH_TARGET"
        fi
        
        echo "Using lunch target: $LUNCH_TARGET"
        echo "[3/6] Android 9 Pie — skipping TV config (older system)"
        echo "[4/6] Android 9 Pie — device tree already included"
        echo "[5/6] Kernel config — using default (Android 9)"
        echo "[6/6] Prebuilts fixes — minimal (Android 9 prebuilts are stable)"
        ;;
    
    2)
        # ====================================================================
        # VICHARAK ANDROID 12 (kernel 5.10) ★ RECOMMENDED
        # ====================================================================
        echo "[2/6] Configuring Vicharak Android 12 (kernel 5.10)..."
        
        # Copy kernel configs
        if [ -d "mkcombinedroot/configs" ]; then
            cp -vr mkcombinedroot/configs/android-1* kernel-5.10/arch/arm64/configs/ 2>/dev/null || true
        fi
        
        # Fix kernel version in Vaaman BoardConfig
        VAAMAN_BC="device/rockchip/rk3399/vaaman/BoardConfig.mk"
        if [ -f "$VAAMAN_BC" ] && grep -q "PRODUCT_KERNEL_VERSION := 4.19" "$VAAMAN_BC"; then
            sed -i 's/PRODUCT_KERNEL_VERSION := 4.19/PRODUCT_KERNEL_VERSION := 5.10/' "$VAAMAN_BC"
            echo "Fixed kernel version: 4.19 -> 5.10"
        fi
        
        # Lunch target
        if lunch rk3399-userdebug 2>/dev/null; then
            LUNCH_TARGET="rk3399-userdebug"
        else
            read -rp "Enter lunch target: " LUNCH_TARGET
            lunch "$LUNCH_TARGET"
        fi
        echo "Using lunch target: $LUNCH_TARGET"
        
        echo "[3/6] Configuring for Android TV 12..."
        # Configure Android TV (Leanback, system properties)
        DEVICE_MK="device/rockchip/rk3399/device.mk"
        if [ -f "$DEVICE_MK" ] && ! grep -q "ro.build.characteristics=tv" "$DEVICE_MK"; then
            cat >> "$DEVICE_MK" << 'EOF'

# === Android TV 12 Configuration ===
PRODUCT_CHARACTERISTICS := tv
PRODUCT_PACKAGES += LeanbackLauncher TvSettings TvProvider
PRODUCT_PROPERTY_OVERRIDES += ro.build.characteristics=tv
EOF
        fi
        
        echo "[4/6] Applying ROCK 4C+ device tree..."
        DTS_DIR="kernel-5.10/arch/arm64/boot/dts/rockchip"
        if [ -d "$DTS_DIR" ] && [ -f "$DTS_DIR/rk3399-rock-pi-4.dts" ]; then
            cp "$DTS_DIR/rk3399-rock-pi-4.dts" "$DTS_DIR/rk3399-rock-4c-plus.dts"
            echo "Created rk3399-rock-4c-plus.dts"
        fi
        
        echo "[5/6] Configuring kernel for Android TV..."
        KERNEL_CONFIG="kernel-5.10/arch/arm64/configs/rockchip_defconfig"
        if [ -f "$KERNEL_CONFIG" ]; then
            for opt in "CONFIG_DRM_DW_HDMI_CEC=y" "CONFIG_IR_GPIO_CIR=y"; do
                grep -q "^${opt%%=*}" "$KERNEL_CONFIG" || echo "$opt" >> "$KERNEL_CONFIG"
            done
        fi
        
        echo "[6/6] Applying prebuilts fixes..."
        python3 "$SCRIPT_DIR/fix_prebuilts.py"
        ;;
    
    3)
        # ====================================================================
        # ADVANTECH ANDROID 12 (kernel 4.19)
        # ====================================================================
        echo "[2/6] Configuring Advantech Android 12 (kernel 4.19)..."
        
        echo "WARNING: Advantech BSP requires manual prebuilts/external extraction!"
        echo "Please extract:"
        echo "  - prebuilts-rk3399-AndroidS12-20230518.tar.gz"
        echo "  - external-rk3399-AndroidS12-20230522.tar.gz"
        echo ""
        read -rp "Continue? [y/N]: " CONFIRM
        if [ "$CONFIRM" != "y" ]; then
            echo "Skipping Advantech configuration."
            exit 0
        fi
        
        # Lunch target
        if lunch rk3399-userdebug 2>/dev/null; then
            LUNCH_TARGET="rk3399-userdebug"
        else
            read -rp "Enter lunch target: " LUNCH_TARGET
            lunch "$LUNCH_TARGET"
        fi
        
        echo "[3/6] [4/6] [5/6] [6/6] Configuration complete (Advantech BSP uses default settings)"
        ;;
    
    4)
        # ====================================================================
        # AOSP ANDROID 12 (EXPERIMENTAL)
        # ====================================================================
        echo "[2/6] Configuring AOSP Android 12..."
        echo ""
        echo "WARNING: Pure AOSP requires manual Rockchip BSP integration!"
        echo "You need to add:"
        echo "  - kernel/"
        echo "  - hardware/rockchip/ (vendor HALs)"
        echo "  - device/rockchip/rk3399 (device tree)"
        echo ""
        read -rp "Continue? [y/N]: " CONFIRM
        if [ "$CONFIRM" != "y" ]; then
            exit 0
        fi
        
        echo "[3/6] [4/6] [5/6] [6/6] AOSP configuration — manual integration required"
        ;;
    
    *)
        echo "ERROR: Invalid BSP_CHOICE: $BSP_CHOICE"
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Common: Fix prebuilts and U-Boot
# ---------------------------------------------------------------------------
echo ""
echo "Applying common prebuilts fixes..."

# Fix U-Boot make.sh absolute path
if [ -f "u-boot/make.sh" ] && grep -q "CROSS_COMPILE_ARM64=../prebuilts" "u-boot/make.sh"; then
    ABS_PATH="$WORK_DIR/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-"
    sed -i "s|CROSS_COMPILE_ARM64=../prebuilts|CROSS_COMPILE_ARM64=$ABS_PATH|" "u-boot/make.sh"
fi

# Fix clang symlinks
CLANG_LIB_DIR="prebuilts/clang/host/linux-x86/clang-3289846/lib64"
GCC_SYSROOT="prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/sysroot/usr/lib"
if [ -d "$CLANG_LIB_DIR" ] && [ -d "$GCC_SYSROOT" ]; then
    for lib in libncurses.so.5 libtinfo.so.5; do
        if [ ! -e "$CLANG_LIB_DIR/$lib" ] && [ -e "$GCC_SYSROOT/$lib" ]; then
            ln -sf "../../../../../gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/sysroot/usr/lib/$lib" "$CLANG_LIB_DIR/$lib"
        fi
    done
fi

# Fix build.sh
if [ -f "build.sh" ]; then
    sed -i 's|cp -rf \$KERNEL_DEBUG \$OUT/kernel|mkdir -p $(dirname \$OUT/kernel) \&\& cp -rf \$KERNEL_DEBUG \$OUT/kernel|' "build.sh" 2>/dev/null || true
    sed -i 's|if \[ \$IS_VEHICLE = "true" \]|if [ "\$IS_VEHICLE" = "true" ]|' "build.sh" 2>/dev/null || true
fi

echo ""
echo "============================================"
echo " Configuration complete!"
echo "============================================"
echo ""
echo "Next step: Run 04-build-android.sh"
echo ""

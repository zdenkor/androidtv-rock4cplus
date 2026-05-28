#!/bin/bash
# =============================================================================
# 03-configure-build.sh
# Configures Android TV 12 build for Radxa ROCK 4C+ (RK3399-T)
# Uses Vicharak BSP (kernel 5.10, device/rockchip/rk3399)
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
echo " Configuring Android TV 12 Build"
echo " BSP: Vicharak (kernel 5.10)"
echo " Target: Radxa ROCK 4C+ (RK3399-T)"
echo "============================================"
echo ""

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
# 7. GApps Integration
# ---------------------------------------------------------------------------
echo ""
echo "[7/7] GApps Integration..."
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

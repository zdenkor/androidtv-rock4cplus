#!/bin/bash
# =============================================================================
# 03-configure-build.sh (Multi-BSP version)
# Configures Android build for RK3399 BSP
# Detects all downloaded BSPs and prompts user to select which to configure
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="/mnt/aosp-build"

# Check if BASE_DIR exists
if [ ! -d "$BASE_DIR" ]; then
    echo "ERROR: Base directory not found: $BASE_DIR"
    echo "Run 02-download-source.sh first to download a BSP."
    exit 1
fi

# Detect all downloaded BSP directories and sort them in logical order
declare -a BSP_DIRS=()
declare -a BSP_NAMES=()

# Find all BSP directories and sort them in the desired order:
# 1. Radxa Android 9, 2. Radxa Android 11, 3. Vicharak Android 12, 4. AOSP Android 12
for pattern in "radxa9" "radxa11" "vicharak12" "aosp12"; do
    for dir in "$BASE_DIR"/androidtv-rock4cplus-"$pattern"*; do
        if [ -d "$dir" ]; then
            BSP_DIRS+=("$dir")
            BSP_NAMES+=("$(basename "$dir")")
        fi
    done
done

# If no BSPs found, check for .build-config
if [ ${#BSP_DIRS[@]} -eq 0 ]; then
    CONFIG_FILE="$SCRIPT_DIR/../.build-config"
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        if [ -d "$WORK_DIR" ]; then
            BSP_DIRS+=("$WORK_DIR")
            BSP_NAMES+=("$(basename "$WORK_DIR")")
        fi
    fi
fi

# Prompt user to select BSP if multiple found or none in .build-config
if [ ${#BSP_DIRS[@]} -eq 0 ]; then
    echo "ERROR: No BSP directories found in $BASE_DIR"
    echo "Run 02-download-source.sh first to download a BSP."
    exit 1
elif [ ${#BSP_DIRS[@]} -eq 1 ]; then
    WORK_DIR="${BSP_DIRS[0]}"
    BSP_NAME="${BSP_NAMES[0]}"
    echo "Found BSP: $BSP_NAME"
    echo "Configuring this BSP..."
else
    echo "============================================"
    echo " Multiple BSPs Found"
    echo "============================================"
    echo ""
    echo "Select which BSP to configure:"
    echo ""
    for i in "${!BSP_DIRS[@]}"; do
        echo "  $((i+1)). ${BSP_NAMES[$i]}"
        echo "     Path: ${BSP_DIRS[$i]}"
        echo ""
    done
    while true; do
        read -rp "Enter choice (1-${#BSP_DIRS[@]}): " CHOICE
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#BSP_DIRS[@]} ]; then
            break
        fi
        echo "  [ERROR] Invalid choice: '$CHOICE'. Valid: 1-${#BSP_DIRS[@]}"
    done
    WORK_DIR="${BSP_DIRS[$((CHOICE-1))]}"
    BSP_NAME="${BSP_NAMES[$((CHOICE-1))]}"
    echo ""
fi

# Determine BSP type from directory name
if [[ "$BSP_NAME" == *radxa9* ]]; then
    BSP_CHOICE=1
    BSP_TYPE="Radxa Android 9 Pie"
elif [[ "$BSP_NAME" == *radxa11* ]]; then
    BSP_CHOICE=2
    BSP_TYPE="Radxa Android 11 (kernel 4.19)"
elif [[ "$BSP_NAME" == *vicharak12* ]]; then
    BSP_CHOICE=3
    BSP_TYPE="Vicharak Android 12 (kernel 5.10)"
elif [[ "$BSP_NAME" == *aosp12* ]]; then
    BSP_CHOICE=4
    BSP_TYPE="AOSP Android 12"
else
    echo "WARNING: Unknown BSP type: $BSP_NAME"
    echo "Defaulting to Vicharak (option 2)"
    BSP_CHOICE=2
    BSP_TYPE="Vicharak Android 12 (kernel 5.10)"
fi

echo "============================================"
echo " Configuring Android Build"
echo " BSP: $BSP_TYPE"
echo " WORK_DIR: $WORK_DIR"
echo "============================================"
echo ""

if [ ! -d "$WORK_DIR" ]; then
    echo "ERROR: WORK_DIR does not exist: $WORK_DIR"
    exit 1
fi

cd "$WORK_DIR"

# Check for Android source tree
if [ ! -f "build/envsetup.sh" ]; then
    echo "ERROR: Android source tree not found in: $WORK_DIR"
    echo "Expected file missing: $WORK_DIR/build/envsetup.sh"
    
    # Check if this is a directory that needs to be extracted/unpacked
    echo "Checking for compressed archives or subdirectories..."
    for item in "$WORK_DIR"/*; do
        if [ -d "$item" ] && [ -f "$item/build/envsetup.sh" ]; then
            echo "Found Android source in subdirectory: $item"
            WORK_DIR="$item"
            break
        elif [[ "$item" == *.tar* ]] || [[ "$item" == *.zip* ]]; then
            echo "Found archive: $item"
            echo "Please extract the archive first, then run this script again."
            exit 1
        fi
    done
    
    if [ ! -f "build/envsetup.sh" ]; then
        echo "Please run ./scripts/02-download-source.sh first and download a BSP into /mnt/aosp-build."
        exit 1
    fi
fi

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
        
        # Select lunch target - ROCK 4C+ uses rk3399_box-userdebug (target 57)
        echo "============================================"
        echo " LUNCH TARGET SELECTION"
        echo "============================================"
        echo ""
        echo "For ROCK 4C+, using target 57 (rk3399_box-userdebug)..."
        echo ""
        
        echo "[3/6] Fixing Python indentation errors BEFORE lunch..."
        # Proactively fix ALL Python indentation in device/rockchip (convert tabs to spaces)
        # This MUST be done before lunch, as lunch will trigger auto_generator.py
        if [ -d "device/rockchip" ]; then
            echo "Fixing device/rockchip/**/*.py files..."
            python3 "$SCRIPT_DIR/fix_option1_radxa9_auto_generator.py"
        fi
        
        # Call lunch with target name and suppress interactive mode
        lunch rk3399_box-userdebug < /dev/null
        
        echo "[4/6] Android 9 Pie — device tree already included"
        echo "[5/6] Kernel config — using default (Android 9)"
        echo "[6/6] Prebuilts fixes — minimal (Android 9 prebuilts are stable)"
        ;;
    
    2)
        # ====================================================================
        # RADXA ANDROID 11 (rk11, kernel 4.19)
        # ====================================================================
        echo "[2/6] Configuring Radxa Android 11 (kernel 4.19)..."

        # Fix Python indentation BEFORE lunch
        if [ -d "device/rockchip" ]; then
            echo "Fixing device/rockchip/**/*.py files..."
            python3 "$SCRIPT_DIR/fix_option1_radxa9_auto_generator.py" 2>/dev/null || true
        fi

        # Call lunch
        lunch rk3399_box-userdebug < /dev/null

        echo "[3/6] Android 11 — device tree already included"
        echo "[4/6] Kernel config — using default (Android 11, kernel 4.19)"
        echo "[5/6] Applying ROCK 4C+ device tree..."
        DTS_DIR="kernel/arch/arm64/boot/dts/rockchip"
        if [ -d "$DTS_DIR" ] && [ -f "$DTS_DIR/rk3399-rock-pi-4.dts" ]; then
            cp "$DTS_DIR/rk3399-rock-pi-4.dts" "$DTS_DIR/rk3399-rock-4c-plus.dts"
            echo "Created rk3399-rock-4c-plus.dts"
        fi

        echo "[6/6] Prebuilts fixes — minimal"
        ;;
    
    3)
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
        
        # Find correct lunch target for Vicharak
        echo "[2b/6] Detecting available lunch targets..."
        LUNCH_TARGET=""
        
        # List all available product configs first
        echo "Searching for product configurations..."
        if [ -d "device/rockchip/rk3399" ]; then
            ls -la device/rockchip/rk3399/ | head -20
            
            # Look for AndroidProducts.mk files
            for dir in device/rockchip/rk3399/*/; do
                if [ -f "${dir}AndroidProducts.mk" ]; then
                    PRODUCT_NAME=$(basename "$dir")
                    echo "Found product directory: $PRODUCT_NAME"
                    if [ -z "$LUNCH_TARGET" ]; then
                        LUNCH_TARGET="$PRODUCT_NAME-userdebug"
                    fi
                fi
            done
        fi
        
        # If still no target found, try common Vicharak product names
        if [ -z "$LUNCH_TARGET" ]; then
            echo "No product directories found, trying common names..."
            
            # Try common Vicharak product names
            for COMMON_PRODUCT in vaaman eminence; do
                if [ -d "device/rockchip/rk3399/$COMMON_PRODUCT" ]; then
                    LUNCH_TARGET="$COMMON_PRODUCT-userdebug"
                    echo "Using common product: $LUNCH_TARGET"
                    break
                fi
            done
        fi
        
        # Final fallback
        if [ -z "$LUNCH_TARGET" ]; then
            LUNCH_TARGET="rk3399-userdebug"
            echo "WARNING: Using fallback target, may fail: $LUNCH_TARGET"
        fi
        
        echo "Using lunch target: $LUNCH_TARGET"
        echo "Calling: lunch $LUNCH_TARGET"
        lunch "$LUNCH_TARGET" < /dev/null || {
            echo "ERROR: lunch target '$LUNCH_TARGET' failed"
            echo "Attempting to find available targets by listing device configs..."
            find device/rockchip -name "AndroidProducts.mk" -type f | head -20
            exit 1
        }
        
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
        # fix_prebuilts.py removed - using universal fix scripts instead
        ;;
    
    4)
        # ====================================================================
        # AOSP ANDROID 12 (EXPERIMENTAL)
        # ====================================================================
        echo "[2/6] Configuring AOSP Android 12..."
        echo ""

        if [ ! -d "device/rockchip/rk3399" ] || [ ! -d "kernel" ] || [ ! -d "hardware/rockchip" ]; then
            echo "ERROR: AOSP Rockchip overlay not fully installed."
            echo "Please run 02-download-source.sh and select Option 3 again."
            echo "Required directories:"
            echo "  device/rockchip/rk3399"
            echo "  hardware/rockchip"
            echo "  kernel"
            echo ""
            exit 1
        fi

        # Auto-fix: clone missing device/rockchip/common if not present
        if [ ! -d "device/rockchip/common" ]; then
            echo "Cloning missing device/rockchip/common..."
            git clone --depth=1 https://github.com/khadas/android_device_rockchip_common.git device/rockchip/common || {
                echo "ERROR: Failed to clone device/rockchip/common"
                exit 1
            }
        fi

        echo "[3/6] Applying ROCK 4C+ integration..."
        if [ -f "$SCRIPT_DIR/../configs/BoardConfig.mk" ]; then
            echo "Copying ROCK 4C+ BoardConfig.mk..."
            cp -f "$SCRIPT_DIR/../configs/BoardConfig.mk" "device/rockchip/rk3399/BoardConfig.mk"
        fi

        if [ -f "$SCRIPT_DIR/../patches/rk3399-rock-4c-plus.dts" ] && [ -d "kernel/arch/arm64/boot/dts/rockchip" ]; then
            echo "Copying ROCK 4C+ device tree..."
            cp -f "$SCRIPT_DIR/../patches/rk3399-rock-4c-plus.dts" "kernel/arch/arm64/boot/dts/rockchip/"
        fi

        echo "[4/6] Fixing Python indentation / build scripts..."
        if [ -f "device/rockchip/common/auto_generator.py" ]; then
            python3 "$SCRIPT_DIR/fix_option3_aosp12_auto_generator.py" || true
        else
            echo "  Skipping: auto_generator.py not found (may not be needed for this BSP)"
        fi

        echo "[5/6] Detecting AOSP Rockchip lunch target..."
        LUNCH_TARGET=""
        if [ -f "device/rockchip/rk3399/rk3399_all.mk" ]; then
            LUNCH_TARGET="rk3399_all-userdebug"
        elif [ -f "device/rockchip/rk3399/rk3399.mk" ]; then
            LUNCH_TARGET="rk3399-userdebug"
        fi

        if [ -z "$LUNCH_TARGET" ]; then
            echo "WARNING: No Rockchip lunch target found."
            echo "Attempting fallback target: rk3399_all-userdebug"
            LUNCH_TARGET="rk3399_all-userdebug"
        fi

        # Fix BUILD_NUMBER readonly issue - comment out BUILD_NUMBER in makefile before lunch
        if [ -f "device/rockchip/rk3399/rk3399_all.mk" ]; then
            sed -i 's/^\(BUILD_NUMBER.*\)/#\1  # commented by build fix/' "device/rockchip/rk3399/rk3399_all.mk" 2>/dev/null || true
        fi

        echo "Using lunch target: $LUNCH_TARGET"
        lunch "$LUNCH_TARGET" < /dev/null || {
            echo "ERROR: lunch target '$LUNCH_TARGET' failed"
            echo "Please inspect device/rockchip/rk3399/AndroidProducts.mk and available lunch targets."
            exit 1
        }

        echo "[6/6] AOSP Rockchip integration complete."
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

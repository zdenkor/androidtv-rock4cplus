#!/bin/bash
# =============================================================================
# 04-build-android.sh (Multi-BSP version)
# Builds Android for RK3399 BSP
# Detects all downloaded BSPs and prompts user to select which to build
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

# Detect all downloaded BSP directories
declare -a BSP_DIRS=()
declare -a BSP_NAMES=()

for dir in "$BASE_DIR"/androidtv-rock4cplus-*; do
    if [ -d "$dir" ]; then
        BSP_DIRS+=("$dir")
        BSP_NAMES+=("$(basename "$dir")")
    fi
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
    echo "Building this BSP..."
else
    echo "============================================"
    echo " Multiple BSPs Found"
    echo "============================================"
    echo ""
    echo "Select which BSP to build:"
    echo ""
    for i in "${!BSP_DIRS[@]}"; do
        echo "  $((i+1)). ${BSP_NAMES[$i]}"
        echo "     Path: ${BSP_DIRS[$i]}"
        echo ""
    done
    read -rp "Enter choice (1-${#BSP_DIRS[@]}): " CHOICE
    if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#BSP_DIRS[@]} ]; then
        echo "ERROR: Invalid choice"
        exit 1
    fi
    WORK_DIR="${BSP_DIRS[$((CHOICE-1))]}"
    BSP_NAME="${BSP_NAMES[$((CHOICE-1))]}"
    echo ""
fi

# Determine BSP type from directory name
if [[ "$BSP_NAME" == *radxa9* ]]; then
    BSP_CHOICE=1
    BSP_TYPE="Radxa Android 9 Pie"
elif [[ "$BSP_NAME" == *vicharak12* ]]; then
    BSP_CHOICE=2
    BSP_TYPE="Vicharak Android 12 (kernel 5.10)"
elif [[ "$BSP_NAME" == *advantech12* ]]; then
    BSP_CHOICE=3
    BSP_TYPE="Advantech Android 12 (kernel 4.19)"
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
echo " Building Android"
echo " BSP: $BSP_TYPE"
echo " WORK_DIR: $WORK_DIR"
echo "============================================"
echo ""

if [ ! -d "$WORK_DIR" ]; then
    echo "ERROR: WORK_DIR does not exist: $WORK_DIR"
    exit 1
fi

cd "$WORK_DIR"

# Allow missing dependencies (some prebuilts modules may have unresolvable deps)
export ALLOW_MISSING_DEPENDENCIES=true

# Fix missing Realtek Bluetooth HAL stub for AOSP builds
if [ ! -f "hardware/realtek/rtkbt/rtkbt.mk" ]; then
    echo "[INFO] Creating stub for missing hardware/realtek/rtkbt/rtkbt.mk"
    mkdir -p hardware/realtek/rtkbt
    echo "# Stub for missing Realtek Bluetooth HAL" > hardware/realtek/rtkbt/rtkbt.mk
fi

# Fix TARGET_DEVICE_DIR manual assignment (Android 12+ forbids this)
DEVICE_MK="device/rockchip/common/device.mk"
if [ -f "$DEVICE_MK" ] && grep -q '^\s*TARGET_DEVICE_DIR=' "$DEVICE_MK"; then
    echo "[INFO] Patching $DEVICE_MK to comment out manual TARGET_DEVICE_DIR"
    sed -i 's/^\(\s*TARGET_DEVICE_DIR=\)/#\1/' "$DEVICE_MK"
    sed -i 's/^\(\s*TARGET_DEVICE_DIR :=\)/#\1/' "$DEVICE_MK"
fi

START_TIME=$(date +%s)

# ---------------------------------------------------------------------------
# Clean and setup (common to all BSPs)
# ---------------------------------------------------------------------------
echo "[1/4] Setting up build environment..."
source build/envsetup.sh

echo "[2/4] Cleaning old build artifacts..."
rm -rf out/soong/.intermediates out/.module_paths out/soong/host 2>/dev/null || true
rm -rf out/target/product/*/obj/RENDERSCRIPT_BITCODE 2>/dev/null || true
rm -f out/soong/build.ninja out/build-*.ninja 2>/dev/null || true
echo "Cache cleaned."

# ---------------------------------------------------------------------------
# BSP-specific build
# ---------------------------------------------------------------------------
case $BSP_CHOICE in
    1)
        # ====================================================================
        # RADXA ANDROID 9 PIE — uses make
        # ====================================================================
        echo "[3/4] Configuring Radxa Android 9 Pie..."
        lunch rk3399_box-userdebug 2>/dev/null || lunch 2>/dev/null | head -20
        
        echo "[4/4] Building Android 9 Pie..."
        echo ""
        echo "Build command: make -j\$(nproc)"
        echo ""
        make -j$(nproc) 2>&1 | tee build.log || {
            echo ""
            echo "========================================"
            echo "BUILD FAILED"
            echo "========================================"
            tail -50 build.log
            exit 1
        }
        
        BUILD_OUTPUT="out/target/product/rk3399_box/system.img"
        ;;
    
    2)
        # ====================================================================
        # VICHARAK ANDROID 12 — uses ./build.sh
        # ====================================================================
        echo "[3/4] Configuring Vicharak Android 12..."
        lunch rk3399-userdebug 2>/dev/null || lunch 2>/dev/null | head -20
        
        echo "[4/4] Building Vicharak Android 12..."
        echo ""
        echo "Build command: ./build.sh -UACKup"
        echo ""
        
        if [ ! -f "build.sh" ]; then
            echo "ERROR: build.sh not found!"
            exit 1
        fi
        
        ./build.sh -UACKup 2>&1 | tee build.log || {
            echo ""
            echo "========================================"
            echo "BUILD FAILED"
            echo "========================================"
            tail -50 build.log
            exit 1
        }
        
        BUILD_OUTPUT="out/target/product/vaaman/system.img"
        ;;
    
    3)
        # ====================================================================
        # ADVANTECH ANDROID 12 — uses ./build.sh
        # ====================================================================
        echo "[3/4] Configuring Advantech Android 12..."
        lunch rk3399-userdebug 2>/dev/null || lunch 2>/dev/null | head -20
        
        echo "[4/4] Building Advantech Android 12..."
        echo ""
        echo "Build command: ./build.sh"
        echo ""
        
        if [ ! -f "build.sh" ]; then
            echo "ERROR: build.sh not found!"
            exit 1
        fi
        
        ./build.sh 2>&1 | tee build.log || {
            echo ""
            echo "========================================"
            echo "BUILD FAILED"
            echo "========================================"
            tail -50 build.log
            exit 1
        }
        
        BUILD_OUTPUT="out/target/product/rk3399/system.img"
        ;;
    
    4)
        # ====================================================================
        # AOSP ANDROID 12 — uses m (mm)
        # ====================================================================
        echo "[3/4] Configuring AOSP Android 12..."

        LUNCH_TARGET=""
        if [ -d "device/rockchip/rk3399" ]; then
            if [ -f "device/rockchip/rk3399/rk3399_all.mk" ]; then
                LUNCH_TARGET="rk3399_all-userdebug"
            elif [ -f "device/rockchip/rk3399/rk3399.mk" ]; then
                LUNCH_TARGET="rk3399-userdebug"
            fi
        fi

        if [ -n "$LUNCH_TARGET" ]; then
            echo "Auto-detected Rockchip AOSP target: $LUNCH_TARGET"
            lunch "$LUNCH_TARGET" < /dev/null || {
                echo "ERROR: lunch target '$LUNCH_TARGET' failed"
                exit 1
            }
            PRODUCT_NAME="${LUNCH_TARGET%%-*}"
            BUILD_OUTPUT="out/target/product/${PRODUCT_NAME}/system.img"
        else
            echo "WARNING: No Rockchip AOSP lunch target found."
            echo "Falling back to generic sdk_gphone_arm64-userdebug"
            lunch sdk_gphone_arm64-userdebug 2>/dev/null || lunch 2>/dev/null | head -20
            BUILD_OUTPUT="out/target/product/generic_arm64/system.img"
        fi

        echo "[4/4] Building AOSP Android 12..."
        echo ""
        echo "Build command: m -j\$(nproc)"
        echo ""

        m -j$(nproc) 2>&1 | tee build.log || {
            echo ""
            echo "========================================"
            echo "BUILD FAILED"
            echo "========================================"
            tail -50 build.log
            exit 1
        }
        ;;
    
    *)
        echo "ERROR: Invalid BSP_CHOICE: $BSP_CHOICE"
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Build complete
# ---------------------------------------------------------------------------
END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))
BUILD_MINS=$((BUILD_TIME / 60))
BUILD_SECS=$((BUILD_TIME % 60))

echo ""
echo "============================================"
echo " BUILD SUCCESSFUL!"
echo "============================================"
echo ""
echo "Build time: ${BUILD_MINS}m ${BUILD_SECS}s"
echo ""

if [ -f "$BUILD_OUTPUT" ]; then
    SIZE_MB=$(du -m "$BUILD_OUTPUT" | cut -f1)
    echo "Output image: $BUILD_OUTPUT"
    echo "Size: ${SIZE_MB}MB"
    echo ""
    echo "Next step: Run 05-flash-device.sh"
else
    echo "WARNING: Expected output not found: $BUILD_OUTPUT"
    echo "Check build.log for details."
fi

echo ""

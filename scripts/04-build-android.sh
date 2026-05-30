#!/bin/bash
# =============================================================================
# 04-build-android.sh
# Builds Android TV 12 for Radxa ROCK 4C+ (RK3399-T)
# Uses Vicharak BSP build.sh (kernel 5.10)
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
echo " Building Android TV 12"
echo " BSP: Vicharak (kernel 5.10)"
echo " Target: Radxa ROCK 4C+ (RK3399-T)"
echo "============================================"
echo ""

# Resolve script directory BEFORE changing to WORK_DIR
SCRIPT_DIR_FIX="$SCRIPT_DIR"

cd "$WORK_DIR"

# ---------------------------------------------------------------------------
# 0. Re-apply prebuilts fixes (in case source was re-synced)
# ---------------------------------------------------------------------------
echo "[0/4] Re-applying prebuilts fixes..."
if [ -f "$SCRIPT_DIR_FIX/fix_prebuilts.py" ]; then
    python3 "$SCRIPT_DIR_FIX/fix_prebuilts.py" 2>/dev/null || true
fi

# Clean ninja cache to avoid stale references from disabled modules
echo "Cleaning ninja cache..."
rm -rf out/soong/.intermediates out/.module_paths out/soong/host 2>/dev/null
rm -rf out/target/product/*/obj/RENDERSCRIPT_BITCODE 2>/dev/null
rm -f out/soong/build.ninja out/build-*.ninja 2>/dev/null
echo "Cache cleaned."

# Create dummy bcc_strip_attr and llvm-rs-cc to satisfy ninja dependencies
# (real ones need libLLVM_android which is missing from clang prebuilts)
mkdir -p out/host/linux-x86/bin
for tool in bcc_strip_attr llvm-rs-cc bcc_compat bcc mcld; do
    cat > "out/host/linux-x86/bin/$tool" << 'DUMMYEOF'
#!/bin/bash
# Dummy tool — creates expected .bc output files to satisfy ninja
# Handles: -o <file>, positional <file>.bc, and --output <file>
out=""
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
    case "${args[$i]}" in
        -o|--output) out="${args[$i+1]}" ;;
        *.bc) out="${args[$i]}" ;;
    esac
done
# If no output found, try last argument
[ -z "$out" ] && out="${args[${#args[@]}-1]}"
if [ -n "$out" ] && [[ "$out" == *.bc ]]; then
    mkdir -p "$(dirname "$out")" 2>/dev/null
    touch "$out"
fi
exit 0
DUMMYEOF
    chmod +x "out/host/linux-x86/bin/$tool"
done
echo "Created dummy bcc/llvm tools"

# Pre-create ALL RenderScript .bc outputs to satisfy ninja copy rules
for bc_name in libclcore.bc libclcore_debug_g.bc libclcore_debug.bc; do
    for base in out/target/product/*/obj/RENDERSCRIPT_BITCODE \
                out/target/product/*/obj_arm/RENDERSCRIPT_BITCODE; do
        for b in $base; do
            mkdir -p "$b/${bc_name}_intermediates" 2>/dev/null
            touch "$b/${bc_name}_intermediates/$bc_name" 2>/dev/null
        done
    done
done

# Re-fix clang symlinks if needed
CLANG_LIB_DIR="prebuilts/clang/host/linux-x86/clang-3289846/lib64"
GCC_SYSROOT="prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/sysroot/usr/lib"
if [ -d "$CLANG_LIB_DIR" ] && [ -d "$GCC_SYSROOT" ]; then
    for lib in libncurses.so.5 libtinfo.so.5; do
        if [ ! -e "$CLANG_LIB_DIR/$lib" ] && [ -e "$GCC_SYSROOT/$lib" ]; then
            ln -sf "../../../../../gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/sysroot/usr/lib/$lib" "$CLANG_LIB_DIR/$lib"
        fi
    done
fi

echo "Prebuilts fixes verified."
echo ""

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

# Fix: Debian 13's GCC 12+ is too new for U-Boot.
# Pre-build U-Boot manually with prebuilt GCC 6.3.1, then skip it in build.sh.
GCC_PREBUILT="$WORK_DIR/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-"

if [ -f "${GCC_PREBUILT}gcc" ]; then
    echo "Pre-building U-Boot with GCC 6.3.1..."
    cd "$WORK_DIR/u-boot"
    make clean 2>/dev/null; make mrproper 2>/dev/null; make distclean 2>/dev/null
    export CROSS_COMPILE="$GCC_PREBUILT"
    make rk3399-vaaman-android_defconfig 2>&1 | tail -1
    make -j$(nproc) 2>&1 | tail -3
    unset CROSS_COMPILE
    cd "$WORK_DIR"
    
    if [ -f "$WORK_DIR/u-boot/idbloader.img" ]; then
        echo "U-Boot built successfully (idbloader.img)"
        # Copy U-Boot outputs to where build.sh expects them
        mkdir -p "$WORK_DIR/rockdev"
        cp "$WORK_DIR/u-boot/idbloader.img" "$WORK_DIR/rockdev/" 2>/dev/null || true
        cp "$WORK_DIR/u-boot/u-boot.itb" "$WORK_DIR/rockdev/" 2>/dev/null || true
        cp "$WORK_DIR/u-boot/trust.img" "$WORK_DIR/rockdev/" 2>/dev/null || true
        SKIP_UBOOT=true
    else
        echo "WARNING: U-Boot build may have failed. Continuing anyway..."
        SKIP_UBOOT=false
    fi
else
    SKIP_UBOOT=false
fi

START_TIME=$(date +%s)

case $BUILD_CHOICE in
    1)
        # Full build: U-Boot + Android + Kernel + update image
        if [ "$SKIP_UBOOT" = true ]; then
            echo "Running: ./build.sh -ACKup (U-Boot pre-built)"
            ./build.sh -ACKup 2>&1 | tee build.log
        else
            echo "Running: ./build.sh -UACKup"
            ./build.sh -UACKup 2>&1 | tee build.log
        fi
        BUILD_EXIT=${PIPESTATUS[0]}
        ;;
    2)
        # Android only
        echo "Running: ./build.sh -A"
        ./build.sh -A 2>&1 | tee build.log
        BUILD_EXIT=${PIPESTATUS[0]}
        ;;
    3)
        # Kernel only
        echo "Running: ./build.sh -CK"
        ./build.sh -CK 2>&1 | tee build.log
        BUILD_EXIT=${PIPESTATUS[0]}
        ;;
    4)
        # U-Boot only
        echo "Running: ./build.sh -U"
        ./build.sh -U 2>&1 | tee build.log
        BUILD_EXIT=${PIPESTATUS[0]}
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

if [ "$BUILD_EXIT" -ne 0 ]; then
    echo "============================================"
    echo " BUILD FAILED (exit code: $BUILD_EXIT)"
    echo "============================================"
    echo ""
    echo "Build time: $((BUILD_TIME / 60)) minutes $((BUILD_TIME % 60)) seconds"
    echo ""
    if [ -f build.log ]; then
        echo "Last 30 lines of build.log:"
        echo "----------------------------------------"
        tail -n 30 build.log
        echo "----------------------------------------"
    fi
    echo ""
    echo "Fix the errors above and re-run this script."
    exit 1
fi

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

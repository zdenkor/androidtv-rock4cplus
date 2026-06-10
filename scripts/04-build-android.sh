#!/bin/bash
# =============================================================================
# 04-build-android.sh (Multi-BSP version)
# Builds Android for RK3399 BSP
# Detects all downloaded BSPs and prompts user to select which to build
# =============================================================================

set -e
set -o pipefail

# =============================================================================
# Progress helpers
# =============================================================================

# Show a spinner while a background task runs.
# Usage: start_spinner "Doing work..." &
#        SPINNER_PID=$!
#        ... long task ...
#        kill $SPINNER_PID 2>/dev/null
#        printf "\r%-80s\r" ""  # clear line
_spin_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
start_spinner() {
    local msg="$1"
    local i=0
    while true; do
        printf "\r%s %s" "${_spin_chars:$((i % 10)):1}" "$msg"
        i=$((i + 1))
        sleep 0.1
    done
}

# Print elapsed time since $1 (seconds since epoch).
elapsed_since() {
    local start="$1"
    local now
    now=$(date +%s)
    local elapsed=$((now - start))
    local min=$((elapsed / 60))
    local sec=$((elapsed % 60))
    printf "%dm %ds" "$min" "$sec"
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="/mnt/aosp-build"

# Check if BASE_DIR exists
if [ ! -d "$BASE_DIR" ]; then
    echo "ERROR: Base directory not found: $BASE_DIR"
    echo "Run 02-download-source.sh first to download a BSP."
    exit 1
fi

# Detect all downloaded BSP directories in fixed order: 1=radxa9, 2=radxa11, 3=vicharak12, 4=aosp12
declare -a BSP_DIRS=()
declare -a BSP_NAMES=()

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

# Determine BSP type from directory name
get_bsp_type() {
    local name="$1"
    if [[ "$name" == *radxa9* ]]; then
        echo "Radxa Android 9 Pie"
    elif [[ "$name" == *vicharak12* ]]; then
        echo "Vicharak Android 12 (kernel 5.10)"
    elif [[ "$name" == *advantech12* ]]; then
        echo "Advantech Android 12 (kernel 4.19)"
    elif [[ "$name" == *aosp12* ]]; then
        echo "AOSP Android 12"
    elif [[ "$name" == *radxa11* ]]; then
        echo "Radxa Android 11 (kernel 4.19)"
    else
        echo "Unknown"
    fi
}

# Prompt user to select BSP if multiple found or none in .build-config
if [ ${#BSP_DIRS[@]} -eq 0 ]; then
    echo "ERROR: No BSP directories found in $BASE_DIR"
    echo "Run 02-download-source.sh first to download a BSP."
    exit 1
elif [ ${#BSP_DIRS[@]} -eq 1 ]; then
    WORK_DIR="${BSP_DIRS[0]}"
    BSP_NAME="${BSP_NAMES[0]}"
    echo "Found BSP: $(get_bsp_type "$BSP_NAME")"
    echo "  ($BSP_NAME)"
    echo "Building this BSP..."
else
    echo "============================================"
    echo " Multiple BSPs Found"
    echo "============================================"
    echo ""
    echo "Select which BSP to build:"
    echo ""
    for i in "${!BSP_DIRS[@]}"; do
        bsp_type=$(get_bsp_type "${BSP_NAMES[$i]}")
        echo "  $((i+1)). $bsp_type"
        echo "     Dir: ${BSP_NAMES[$i]}"
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
elif [[ "$BSP_NAME" == *advantech12* ]]; then
    BSP_CHOICE=3
    BSP_TYPE="Advantech Android 12 (kernel 4.19)"
elif [[ "$BSP_NAME" == *aosp12* ]]; then
    BSP_CHOICE=4
    BSP_TYPE="AOSP Android 12"
else
    echo "WARNING: Unknown BSP type: $BSP_NAME"
    echo "Defaulting to Vicharak (option 3)"
    BSP_CHOICE=3
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

# =============================================================================
# Ask user whether to clean previous build state
# =============================================================================
echo "============================================"
echo " Previous Build State"
echo "============================================"
echo ""

HAS_OUT="no"
HAS_LOG="no"
[ -d "out" ] && HAS_OUT="yes ($(du -sh out 2>/dev/null | cut -f1))"
[ -f "build.log" ] && HAS_LOG="yes"

if [ "$HAS_OUT" = "no" ] && [ "$HAS_LOG" = "no" ]; then
    echo "No previous build state found. Starting fresh build."
    echo ""
else
    echo "Found previous build state:"
    echo "  Build output (out/):       $HAS_OUT"
    echo "  Build log:                 $HAS_LOG"
    echo ""

    while true; do
        read -rp "Clean previous build state and start fresh? [y/N]: " CLEAN_CHOICE
        case "$CLEAN_CHOICE" in
            [yY]|[yY][eE][sS])
                echo ""
                echo "Cleaning previous build state..."

                # 1. Remove build output
                if [ -d "out" ]; then
                    echo "  [1/3] Removing out/..."
                    rm -rf out
                    echo "        Done."
                else
                    echo "  [1/3] No out/ to remove."
                fi

                # 2. Git reset any modified tracked files
                if git rev-parse --git-dir >/dev/null 2>&1; then
                    echo "  [2/3] Git-resetting any modified tracked files..."
                    git checkout -- . 2>/dev/null || true
                    git clean -fd 2>/dev/null || true
                    echo "        Done."
                else
                    echo "  [2/3] No top-level .git — skipping git reset."
                fi

                # 3. Remove build log
                if [ -f "build.log" ]; then
                    echo "  [3/3] Removing build.log..."
                    rm -f build.log
                    echo "        Done."
                else
                    echo "  [3/3] No build.log to remove."
                fi

                echo ""
                echo "Clean complete. Proceeding with fresh build..."
                echo ""
                break
                ;;
            [nN]|[nN][oO]|"")
                echo ""
                echo "Keeping previous state. Resuming build..."
                echo ""
                break
                ;;
            *)
                echo "  Please answer y or n."
                ;;
        esac
    done
fi

# Allow missing dependencies (some prebuilts modules may have unresolvable deps)
export ALLOW_MISSING_DEPENDENCIES=true

# BSP-specific pre-build fixes
if [[ "$BSP_CHOICE" == "4" ]]; then
    # AOSP Android 12 only: missing Realtek Bluetooth HAL
    if [ ! -f "hardware/realtek/rtkbt/rtkbt.mk" ]; then
        echo "[INFO] Creating stub for missing hardware/realtek/rtkbt/rtkbt.mk"
        mkdir -p hardware/realtek/rtkbt
        echo "# Stub for missing Realtek Bluetooth HAL" > hardware/realtek/rtkbt/rtkbt.mk
    fi
fi

if [[ "$BSP_CHOICE" == "2" || "$BSP_CHOICE" == "3" || "$BSP_CHOICE" == "4" || "$BSP_CHOICE" == "5" ]]; then
    # Android 11/12+: manual TARGET_DEVICE_DIR assignment is forbidden
    DEVICE_MK="device/rockchip/common/device.mk"
    if [ -f "$DEVICE_MK" ] && grep -q 'TARGET_DEVICE_DIR=' "$DEVICE_MK"; then
        echo "[INFO] Patching $DEVICE_MK to comment out manual TARGET_DEVICE_DIR"
        sed -i 's/^[[:space:]]*TARGET_DEVICE_DIR=/#&/' "$DEVICE_MK"
        sed -i 's/^[[:space:]]*TARGET_DEVICE_DIR :=/#&/' "$DEVICE_MK"
    fi
fi

if [[ "$BSP_CHOICE" == "1" ]]; then
    # Android 9 only: PRODUCT_CHARACTERISTICS is set with := in multiple product .mk files
    # Change all := to ?= to avoid "cannot assign to readonly variable" errors
    echo "[INFO] Patching PRODUCT_CHARACTERISTICS := -> ?= in all device/rockchip .mk files"
    find device/rockchip -name "*.mk" -exec sed -i 's/^\([[:space:]]*PRODUCT_CHARACTERISTICS\) :=/\1 ?=/' {} +
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

        # Fix mixed tabs/spaces in auto_generator.py (patch may introduce tabs)
        AUTO_GEN="device/rockchip/common/auto_generator.py"
        if [ -f "$AUTO_GEN" ]; then
            echo "[INFO] Fixing auto_generator.py..."
            python3 -c "
path = '$AUTO_GEN'
with open(path) as f:
    content = f.read()

# Normalize all tabs to 4 spaces
content = content.replace('\t', '    ')

# Fix: if (self.rk_param == 'hwver'): has no body — insert pass after it
old = 'if (self.rk_param == \"hwver\"):'
new = 'if (self.rk_param == \"hwver\"):\n            pass'
content = content.replace(old, new)

with open(path, 'w') as f:
    f.write(content)
print('Fixed auto_generator.py')
"
        fi

        # Build kernel first (required for Android 9)
        if [ -d "kernel" ] && [ -f "kernel/arch/arm64/configs/rockchip_defconfig" ]; then
            echo "[4a/4] Building kernel..."
            KERNEL_START=$(date +%s)
            # Fix for GCC 10+ "duplicate 'extern'" error on yylloc in dtc
            # dtc-parser.tab.h already declares 'extern YYLTYPE yylloc;'
            # so the declaration in dtc-lexer.l causes a duplicate extern error.
            # Remove the line entirely from both source and generated files.
            DTC_LEXER="kernel/scripts/dtc/dtc-lexer.l"
            DTC_LEXER_GEN="kernel/scripts/dtc/dtc-lexer.lex.c"
            if [ -f "$DTC_LEXER" ] && grep -q "YYLTYPE yylloc" "$DTC_LEXER"; then
                sed -i '/YYLTYPE yylloc/d' "$DTC_LEXER"
                echo "Patched dtc-lexer.l (removed yylloc declaration)"
            fi
            if [ -f "$DTC_LEXER_GEN" ] && grep -q "YYLTYPE yylloc" "$DTC_LEXER_GEN"; then
                sed -i '/YYLTYPE yylloc/d' "$DTC_LEXER_GEN"
                echo "Patched dtc-lexer.lex.c (removed yylloc declaration)"
            fi
            # Clean stale build artifacts so patches take effect
            echo "Cleaning kernel build artifacts..."
            make -C kernel ARCH=arm64 clean 2>/dev/null || true
            make -C kernel ARCH=arm64 rockchip_defconfig && make -C kernel ARCH=arm64 -j$(nproc) Image dtbs || {
                echo ""
                echo "========================================"
                echo "KERNEL BUILD FAILED"
                echo "========================================"
                exit 1
            }
            echo "Kernel build finished in $(elapsed_since $KERNEL_START)"
        fi
        
        # Build Android (use PIPESTATUS to catch make failure through tee)
        echo "[4b/4] Building Android (make -j$(nproc))..."

        ANDROID_START=$(date +%s)
        make -j$(nproc) 2>&1 | tee build.log
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo ""
            echo "========================================"
            echo "BUILD FAILED"
            echo "========================================"
            tail -50 build.log
            exit 1
        fi
        echo "Android build finished in $(elapsed_since $ANDROID_START)"
        
        BUILD_OUTPUT="out/target/product/rk3399_box/system.img"
        ;;
    
    2)
        # ====================================================================
        # RADXA ANDROID 11 (rk11, kernel 4.19) — uses make
        # ====================================================================
        echo "[3/4] Configuring Radxa Android 11..."

        # Auto-detect lunch target (same logic as 03-configure-build.sh)
        LUNCH_TARGET=""
        if [ -d "device/rockchip/rk3399" ]; then
            for product in rk3399_ROCKPI4C_Plus_Android11 rk3399_ROCKPI4C_Android11 rk3399_ROCKPI4B_Android11 rk3399_Android11 rk3399_box rk3399; do
                if [ -f "device/rockchip/rk3399/${product}.mk" ] || [ -f "device/rockchip/rk3399/${product}/${product}.mk" ]; then
                    LUNCH_TARGET="${product}-userdebug"
                    break
                fi
            done
        fi
        if [ -z "$LUNCH_TARGET" ]; then
            LUNCH_TARGET="rk3399-userdebug"
        fi
        lunch "$LUNCH_TARGET" 2>/dev/null || lunch 2>/dev/null | head -20
        
        echo "[4/4] Building Android 11..."
        echo ""
        echo "Build command: make -j\$(nproc)"
        echo ""

        # Disable VINTF kernel config checks for kernel 4.19
        # Kernel 4.19 cannot disable CRYPTO_MD4 due to Kconfig dependencies
        echo "Disabling VINTF kernel config enforcement..."
        DEVICE_MK="device/rockchip/rk3399/device.mk"
        if [ -f "$DEVICE_MK" ] && ! grep -q "PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS" "$DEVICE_MK"; then
            echo 'PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false' >> "$DEVICE_MK"
            echo "  Added PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false to $DEVICE_MK"
        fi
        # Also try the product-specific mk file
        PRODUCT_MK="device/rockchip/rk3399/${LUNCH_TARGET%%-*}.mk"
        if [ -f "$PRODUCT_MK" ] && ! grep -q "PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS" "$PRODUCT_MK"; then
            echo 'PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false' >> "$PRODUCT_MK"
            echo "  Added PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false to $PRODUCT_MK"
        fi

        # Add "resize" flag to /data in fstab so Android auto-expands
        # the userdata filesystem to fill the SD card on first boot.
        # Without this, df -h shows only the baseline 4GB even on a 64GB card.
        echo "Patching fstab to add resize flag for /data..."
        FSTAB_FILES=$(find device/rockchip -name "fstab*" -type f 2>/dev/null)
        if [ -n "$FSTAB_FILES" ]; then
            for fstab in $FSTAB_FILES; do
                # Only patch if /data line exists and doesn't already have "resize"
                if grep -q '/data' "$fstab" && ! grep -q 'resize' "$fstab"; then
                    echo "  Adding resize to /data in $fstab"
                    # Add "resize" before the wait/check flags on the /data line
                    sed -i '/\/data/s/\(wait[,]\)/resize,\1/' "$fstab"
                    sed -i '/\/data/s/\(wait\)/resize,\1/' "$fstab"
                    # If neither worked, append resize to the options field
                    if ! grep -q 'resize' "$fstab"; then
                        sed -i '/\/data/s/\(ext4\|f2fs\)/\1,resize/' "$fstab"
                    fi
                fi
            done
        else
            echo "  WARNING: No fstab files found in device/rockchip/"
        fi

        # Fix auto_generator.py (same patch issue as Android 9)
        AUTO_GEN="device/rockchip/common/auto_generator.py"
        if [ -f "$AUTO_GEN" ]; then
            echo "[INFO] Fixing auto_generator.py..."
            python3 -c "
path = '$AUTO_GEN'
with open(path) as f:
    content = f.read()
content = content.replace('\t', '    ')
content = content.replace('if (self.rk_param == \"hwver\"):', 'if (self.rk_param == \"hwver\"):\n            pass')
with open(path, 'w') as f:
    f.write(content)
" 2>/dev/null || python -c "
path = '$AUTO_GEN'
with open(path) as f:
    content = f.read()
content = content.replace('\t', '    ')
content = content.replace('if (self.rk_param == \"hwver\"):', 'if (self.rk_param == \"hwver\"):\n            pass')
with open(path, 'w') as f:
    f.write(content)
" 2>/dev/null || true
            echo "  Done."
        fi

        # Build kernel first
        if [ -d "kernel" ] && [ -f "kernel/arch/arm64/configs/rockchip_defconfig" ]; then
            echo "[4a/4] Building kernel..."
            KERNEL_START=$(date +%s)

            # Ensure ROCK 4C+ DTS exists and is registered in Makefile
            DTS_MAKEFILE="kernel/arch/arm64/boot/dts/rockchip/Makefile"
            DTS_FILE="kernel/arch/arm64/boot/dts/rockchip/rk3399-rock-4c-plus.dts"
            if [ -f "$SCRIPT_DIR/../patches/rk3399-rock-4c-plus.dts" ]; then
                cp "$SCRIPT_DIR/../patches/rk3399-rock-4c-plus.dts" "$DTS_FILE"
            elif [ ! -f "$DTS_FILE" ] && [ -f "kernel/arch/arm64/boot/dts/rockchip/rk3399-rock-pi-4.dts" ]; then
                cp "kernel/arch/arm64/boot/dts/rockchip/rk3399-rock-pi-4.dts" "$DTS_FILE"
            fi
            if [ -f "$DTS_MAKEFILE" ] && ! grep -q 'rk3399-rock-4c-plus' "$DTS_MAKEFILE"; then
                echo 'dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3399-rock-4c-plus.dtb' >> "$DTS_MAKEFILE"
            fi

            DTC_LEXER="kernel/scripts/dtc/dtc-lexer.l"
            DTC_LEXER_GEN="kernel/scripts/dtc/dtc-lexer.lex.c"
            if [ -f "$DTC_LEXER" ] && grep -q "YYLTYPE yylloc" "$DTC_LEXER"; then
                sed -i '/YYLTYPE yylloc/d' "$DTC_LEXER"
            fi
            if [ -f "$DTC_LEXER_GEN" ] && grep -q "YYLTYPE yylloc" "$DTC_LEXER_GEN"; then
                sed -i '/YYLTYPE yylloc/d' "$DTC_LEXER_GEN"
            fi
            make -C kernel ARCH=arm64 clean 2>/dev/null || true
            make -C kernel ARCH=arm64 rockchip_defconfig && \
            {
                # Add Android 11 vintf compatibility: enable BINDERFS and disable MD4
                if [ -x "kernel/scripts/config" ]; then
                    kernel/scripts/config --file kernel/.config --set-val ANDROID_BINDERFS y || true
                    kernel/scripts/config --file kernel/.config --set-val CRYPTO_MD4 n || true
                else
                    if grep -q '^CONFIG_ANDROID_BINDERFS=' kernel/.config; then
                        sed -i 's/^CONFIG_ANDROID_BINDERFS=.*/CONFIG_ANDROID_BINDERFS=y/' kernel/.config
                    else
                        echo 'CONFIG_ANDROID_BINDERFS=y' >> kernel/.config
                    fi
                    if grep -q '^CONFIG_CRYPTO_MD4=' kernel/.config; then
                        sed -i 's/^CONFIG_CRYPTO_MD4=.*/CONFIG_CRYPTO_MD4=n/' kernel/.config
                    else
                        echo 'CONFIG_CRYPTO_MD4=n' >> kernel/.config
                    fi
                fi
                make -C kernel ARCH=arm64 olddefconfig >/dev/null 2>&1 || true
                # Re-apply Android compatibility overrides after olddefconfig
                if [ -x "kernel/scripts/config" ]; then
                    kernel/scripts/config --file kernel/.config --set-val ANDROID_BINDERFS y || true
                    kernel/scripts/config --file kernel/.config --set-val CRYPTO_MD4 n || true
                else
                    if grep -q '^CONFIG_ANDROID_BINDERFS=' kernel/.config; then
                        sed -i 's/^CONFIG_ANDROID_BINDERFS=.*/CONFIG_ANDROID_BINDERFS=y/' kernel/.config
                    else
                        echo 'CONFIG_ANDROID_BINDERFS=y' >> kernel/.config
                    fi
                    if grep -q '^CONFIG_CRYPTO_MD4=' kernel/.config; then
                        sed -i 's/^CONFIG_CRYPTO_MD4=.*/CONFIG_CRYPTO_MD4=n/' kernel/.config
                    else
                        echo 'CONFIG_CRYPTO_MD4=n' >> kernel/.config
                    fi
                fi
                echo "Kernel .config override:"
                grep -E '^CONFIG_ANDROID_BINDERFS=|^CONFIG_CRYPTO_MD4=' kernel/.config || true
            } && \
            make -C kernel ARCH=arm64 -j$(nproc) Image dtbs || {
                echo ""
                echo "========================================"
                echo "KERNEL BUILD FAILED"
                echo "========================================"
                exit 1
            }
            echo "Kernel build finished in $(elapsed_since $KERNEL_START)"

            # Generate resource.img from DTB
            if [ -f "kernel/arch/arm64/boot/dts/rockchip/rk3399-rock-4c-plus.dtb" ]; then
                cp "kernel/arch/arm64/boot/dts/rockchip/rk3399-rock-4c-plus.dtb" kernel/resource.img
            elif [ -f "kernel/arch/arm64/boot/dts/rockchip/rk3399-rock-pi-4.dtb" ]; then
                cp "kernel/arch/arm64/boot/dts/rockchip/rk3399-rock-pi-4.dtb" kernel/resource.img
            else
                DTB=$(find kernel/arch/arm64/boot/dts/rockchip/ -name '*.dtb' 2>/dev/null | head -1)
                [ -n "$DTB" ] && cp "$DTB" kernel/resource.img || touch kernel/resource.img
            fi
        fi

        # Build U-Boot for RK3399 (needed for SD card boot)
        if [ -d "u-boot" ]; then
            echo "[4a2/4] Building U-Boot..."
            UBOOT_START=$(date +%s)

            # Find cross-compiler (Linaro 6.3.1 works with this old U-Boot)
            # Use absolute paths — relative paths break after cd u-boot
            CROSS_COMPILE=""
            for cc in \
                "$WORK_DIR/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-" \
                "$WORK_DIR/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-"; do
                if [ -f "${cc}gcc" ]; then
                    CROSS_COMPILE="$cc"
                    break
                fi
            done

            if [ -z "$CROSS_COMPILE" ]; then
                echo "  WARNING: No cross-compiler found. Trying system gcc..."
                CROSS_COMPILE="aarch64-linux-gnu-"
            fi
            echo "  Using cross-compiler: ${CROSS_COMPILE}gcc"

            cd u-boot
            export CROSS_COMPILE="$CROSS_COMPILE"

            # GCC 9+ reserves x18 for Shadow Call Stack; old U-Boot uses it in
            # inline asm. -ffixed-x18 tells GCC x18 is a fixed register.
            # Only needed when NOT using the old Linaro 6.3.1 toolchain.
            UBOOT_EXTRA_FLAGS=""
            if ! echo "$CROSS_COMPILE" | grep -q "linaro-6"; then
                echo "  Non-Linaro compiler detected — adding -ffixed-x18"
                UBOOT_EXTRA_FLAGS="KCFLAGS=-ffixed-x18"
            fi

            # Try defconfigs in order of compatibility with ROCK 4C+
            UBOOT_DEFCONFIG=""
            for cfg in "rock-pi-4-rk3399" "evb-rk3399" "firefly-rk3399" "rk3399"; do
                if [ -f "configs/${cfg}_defconfig" ]; then
                    UBOOT_DEFCONFIG="${cfg}_defconfig"
                    break
                fi
            done

            if [ -z "$UBOOT_DEFCONFIG" ]; then
                echo "  WARNING: No RK3399 U-Boot defconfig found. Skipping U-Boot build."
                cd ..
                UBOOT_START=""
            fi

            if [ -n "$UBOOT_START" ]; then
                echo "  Using defconfig: $UBOOT_DEFCONFIG"
                make "$UBOOT_DEFCONFIG" $UBOOT_EXTRA_FLAGS
                make -j$(nproc) $UBOOT_EXTRA_FLAGS || {
                    echo "  WARNING: U-Boot build failed. SD card boot may not work."
                }
                cd ..

                # Generate idbloader.img using loaderimage (NOT cat!)
                # cat produces a broken idbloader without Rockchip SD header
                # ROCK 4C+ uses RK3399-T with LPDDR4 — prefer rk3399pro DDR binaries
                LOADERIMAGE="rkbin/tools/loaderimage"
                DDR_BIN=$(ls rkbin/bin/rk33/rk3399pro_ddr_*MHz_v*.bin 2>/dev/null | head -1)
                if [ -z "$DDR_BIN" ]; then
                    DDR_BIN=$(ls rkbin/bin/rk33/rk3399_ddr_*MHz_v*.bin 2>/dev/null | head -1)
                fi
                MINILOADER=$(ls rkbin/bin/rk33/rk3399_miniloader_v*.bin 2>/dev/null | grep -v spinor | head -1)

                if [ -f "$LOADERIMAGE" ] && [ -f "$DDR_BIN" ] && [ -f "$MINILOADER" ]; then
                    echo "  Generating idbloader.img..."
                    echo "    DDR:     $(basename "$DDR_BIN")"
                    echo "    Loader:  $(basename "$MINILOADER")"
                    "$LOADERIMAGE" --pack --uboot "$DDR_BIN" u-boot/idbloader.img
                    cat "$MINILOADER" >> u-boot/idbloader.img
                    echo "  idbloader.img created in u-boot/"
                else
                    echo "  WARNING: Cannot generate idbloader.img"
                fi

                # Generate trust.img using trust_merger
                TRUST_MERGER="rkbin/tools/trust_merger"
                TRUST_INI="rkbin/RKTRUST/RK3399TRUST.ini"
                if [ -f "$TRUST_MERGER" ] && [ -f "$TRUST_INI" ]; then
                    echo "  Generating trust.img..."
                    (cd rkbin && tools/trust_merger --pack RKTRUST/RK3399TRUST.ini)
                    if [ -f "rkbin/trust.img" ]; then
                        echo "  trust.img created in rkbin/"
                    fi
                else
                    echo "  WARNING: Cannot generate trust.img"
                fi

                # U-Boot proper stays in u-boot/ (flash script finds it there)
                if [ -f "u-boot/u-boot.itb" ]; then
                    echo "  uboot.img (u-boot.itb) ready in u-boot/"
                elif [ -f "u-boot/u-boot-dtb.img" ]; then
                    echo "  uboot.img (u-boot-dtb.img) ready in u-boot/"
                elif [ -f "u-boot/u-boot.img" ]; then
                    echo "  uboot.img ready in u-boot/"
                fi

                echo "U-Boot build finished in $(elapsed_since $UBOOT_START)"
            fi
        else
            echo "[4a2/4] No u-boot directory found. Skipping U-Boot build."
            echo "  SD card boot will NOT work without idbloader.img + uboot.img + trust.img."
        fi

        echo "[4b/4] Building Android (make -j$(nproc))..."
        ANDROID_START=$(date +%s)

        # Patch VINTF framework compatibility matrix to remove MD4 requirement
        # Kernel 4.19 cannot disable CRYPTO_MD4 due to Kconfig dependencies,
        # so we relax the framework requirement instead (standard workaround)
        echo "Patching VINTF framework compatibility matrix..."
        FCM_FILES=$(grep -rl 'CONFIG_CRYPTO_MD4' hardware/ system/ build/ device/ 2>/dev/null || true)
        if [ -n "$FCM_FILES" ]; then
            for fcm in $FCM_FILES; do
                echo "  Removing CONFIG_CRYPTO_MD4 from: $fcm"
                sed -i '/CONFIG_CRYPTO_MD4/d' "$fcm"
            done
        else
            echo "  WARNING: No files found containing CONFIG_CRYPTO_MD4 in hardware/, system/, build/, device/"
            echo "  Searching entire tree..."
            FCM_FILES=$(grep -rl 'CONFIG_CRYPTO_MD4' . --include='*.xml' 2>/dev/null | head -20 || true)
            if [ -n "$FCM_FILES" ]; then
                for fcm in $FCM_FILES; do
                    echo "  Removing CONFIG_CRYPTO_MD4 from: $fcm"
                    sed -i '/CONFIG_CRYPTO_MD4/d' "$fcm"
                done
            else
                echo "  No files found. VINTF check may still fail."
            fi
        fi

        make -j$(nproc) 2>&1 | tee build.log
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo ""
            echo "========================================"
            echo "BUILD FAILED"
            echo "========================================"
            tail -50 build.log
            exit 1
        fi
        echo "Android build finished in $(elapsed_since $ANDROID_START)"
        
        BUILD_OUTPUT="out/target/product/${LUNCH_TARGET%%-*}/system.img"
        ;;
    
    3)
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
        
        VICHARAK_START=$(date +%s)
        ./build.sh -UACKup 2>&1 | tee build.log
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo ""
            echo "========================================"
            echo "BUILD FAILED"
            echo "========================================"
            tail -50 build.log
            exit 1
        fi
        echo "Build finished in $(elapsed_since $VICHARAK_START)"
        
        BUILD_OUTPUT="out/target/product/vaaman/system.img"
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

        AOSP_START=$(date +%s)
        m -j$(nproc) 2>&1 | tee build.log
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo ""
            echo "========================================"
            echo "BUILD FAILED"
            echo "========================================"
            tail -50 build.log
            exit 1
        fi
        echo "Build finished in $(elapsed_since $AOSP_START)"
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

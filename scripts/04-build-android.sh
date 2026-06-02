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

# Detect all downloaded BSP directories in fixed order: 1=radxa9, 2=vicharak12, 3=aosp12
declare -a BSP_DIRS=()
declare -a BSP_NAMES=()

for pattern in "radxa9" "vicharak12" "aosp12"; do
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

# =============================================================================
# Ask user whether to clean previous build state
# =============================================================================
echo "============================================"
echo " Previous Build State"
echo "============================================"
echo ""

HAS_OUT="no"
HAS_MARKER="no"
HAS_LOG="no"
[ -d "out" ] && HAS_OUT="yes ($(du -sh out 2>/dev/null | cut -f1))"
[ -f ".2to3_done" ] && HAS_MARKER="yes"
[ -f "build.log" ] && HAS_LOG="yes"

if [ "$HAS_OUT" = "no" ] && [ "$HAS_MARKER" = "no" ] && [ "$HAS_LOG" = "no" ]; then
    echo "No previous build state found. Starting fresh build."
    echo ""
else
    echo "Found previous build state:"
    echo "  Build output (out/):       $HAS_OUT"
    echo "  2to3 conversion marker:    $HAS_MARKER"
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
                    echo "  [1/5] Removing out/..."
                    rm -rf out
                    echo "        Done."
                else
                    echo "  [1/5] No out/ to remove."
                fi

                # 2. Remove 2to3 marker and restore modified .py files
                if [ -f ".2to3_done" ]; then
                    echo "  [2/5] Removing .2to3_done marker..."
                    rm -f .2to3_done
                    echo "        Done."
                else
                    echo "  [2/5] No .2to3_done marker."
                fi

                # 3. Restore 2to3-modified .py files back to original
                PYFILES_LIST=".2to3_files.txt"
                if [ -f "$PYFILES_LIST" ]; then
                    echo "  [3/5] Restoring 2to3-modified Python files..."
                    RESTORED=0
                    FAILED=0
                    while IFS= read -r f; do
                        if [ -f "$f" ]; then
                            # Try git checkout on the file (works in repo-based trees)
                            if git -C "$(dirname "$f")" checkout -- "$(basename "$f")" 2>/dev/null; then
                                RESTORED=$((RESTORED + 1))
                            else
                                FAILED=$((FAILED + 1))
                            fi
                        fi
                    done < "$PYFILES_LIST"
                    rm -f "$PYFILES_LIST"
                    echo "        Restored $RESTORED files ($FAILED could not be restored — will be re-converted)"
                else
                    echo "  [3/5] No .2to3_files.txt — skipping file restore."
                fi

                # 4. Git reset any other modified tracked files
                if git rev-parse --git-dir >/dev/null 2>&1; then
                    echo "  [4/5] Git-resetting any other modified tracked files..."
                    git checkout -- . 2>/dev/null || true
                    git clean -fd 2>/dev/null || true
                    echo "        Done."
                else
                    echo "  [4/5] No top-level .git — skipping git reset."
                fi

                # 5. Remove build log
                if [ -f "build.log" ]; then
                    echo "  [5/5] Removing build.log..."
                    rm -f build.log
                    echo "        Done."
                else
                    echo "  [5/5] No build.log to remove."
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

if [[ "$BSP_CHOICE" == "2" || "$BSP_CHOICE" == "3" || "$BSP_CHOICE" == "4" ]]; then
    # Android 12+ only: manual TARGET_DEVICE_DIR assignment is forbidden
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
        
        # Fix Python 2 syntax for Python 3 (Android 9 uses Python 2 scripts)
        # Use Python's official 2to3 tool — handles all edge cases properly
        # Only runs once; skip if already done (marker file check)
        MARKER="$WORK_DIR/.2to3_done"
        if [ -f "$MARKER" ]; then
            echo "[INFO] Python 2to3 conversion already done, skipping."
        else
            echo "[INFO] Converting Python 2 scripts to Python 3 using 2to3..."
            if ! command -v 2to3 &>/dev/null; then
                echo "[INFO] Installing 2to3..."
                sudo apt-get install -y 2to3 2>/dev/null || sudo apt-get install -y python3-lib2to3 2>/dev/null || true
            fi

            # Save list of all .py files that will be touched (for clean/restore later)
            PYFILES_LIST="$WORK_DIR/.2to3_files.txt"
            find build libcore external/annotation-tools development frameworks system device \
                -not -path "*/edk2/*" \
                -name "*.py" 2>/dev/null | sort > "$PYFILES_LIST"
            TOTAL_FILES=$(wc -l < "$PYFILES_LIST")
            echo "[INFO] Found $TOTAL_FILES Python files to process (list saved to .2to3_files.txt)"

            # Phase 1: 2to3 conversion with progress
            echo "[INFO] Phase 1/3: Running 2to3..."
            PROCESSED=0
            find build libcore external/annotation-tools development frameworks system device \
                -not -path "*/edk2/*" \
                -name "*.py" -print0 | while IFS= read -r -d '' f; do
                2to3 -w -n "$f" 2>/dev/null
                PROCESSED=$((PROCESSED + 1))
                if [ $((PROCESSED % 50)) -eq 0 ] || [ "$PROCESSED" -eq "$TOTAL_FILES" ]; then
                    PCT=$((PROCESSED * 100 / TOTAL_FILES))
                    printf "\r  [2to3] %d/%d (%d%%)" "$PROCESSED" "$TOTAL_FILES" "$PCT"
                fi
            done
            printf "\r  [2to3] %d/%d (100%%) done.\n" "$TOTAL_FILES" "$TOTAL_FILES"

            # Phase 2: fix open(filename, "rb") -> open(filename, "r")
            echo "[INFO] Phase 2/3: Fixing open(filename, \"rb\")..."
            PROCESSED=0
            find build libcore external/annotation-tools development frameworks system device \
                -not -path "*/edk2/*" \
                -name "*.py" -print0 | while IFS= read -r -d '' f; do
                sed -i 's/open(filename, "rb")/open(filename, "r")/' "$f" 2>/dev/null
                PROCESSED=$((PROCESSED + 1))
                if [ $((PROCESSED % 50)) -eq 0 ] || [ "$PROCESSED" -eq "$TOTAL_FILES" ]; then
                    PCT=$((PROCESSED * 100 / TOTAL_FILES))
                    printf "\r  [sed-rb] %d/%d (%d%%)" "$PROCESSED" "$TOTAL_FILES" "$PCT"
                fi
            done
            printf "\r  [sed-rb] %d/%d (100%%) done.\n" "$TOTAL_FILES" "$TOTAL_FILES"

            # Phase 3: fix open(output_file, "wb") -> open(output_file, "w")
            echo "[INFO] Phase 3/3: Fixing open(output_file, \"wb\")..."
            PROCESSED=0
            find build libcore external/annotation-tools development frameworks system device \
                -not -path "*/edk2/*" \
                -name "*.py" -print0 | while IFS= read -r -d '' f; do
                sed -i 's/open(output_file, "wb")/open(output_file, "w")/' "$f" 2>/dev/null
                PROCESSED=$((PROCESSED + 1))
                if [ $((PROCESSED % 50)) -eq 0 ] || [ "$PROCESSED" -eq "$TOTAL_FILES" ]; then
                    PCT=$((PROCESSED * 100 / TOTAL_FILES))
                    printf "\r  [sed-wb] %d/%d (%d%%)" "$PROCESSED" "$TOTAL_FILES" "$PCT"
                fi
            done
            printf "\r  [sed-wb] %d/%d (100%%) done.\n" "$TOTAL_FILES" "$TOTAL_FILES"

            # Revert insertkeys.py: it genuinely needs binary mode to read .x509.pem certs
            INSERTKEYS="build/tools/security/insertkeys.py"
            if [ -f "$INSERTKEYS" ]; then
                sed -i 's/open(filename, "r")/open(filename, "rb")/' "$INSERTKEYS"
                sed -i 's/open(output_file, "w")/open(output_file, "wb")/' "$INSERTKEYS"
                # Fix Python 2 "is not" with literal (2to3 misses this)
                sed -i 's/if line is not "":/if line != "":/' "$INSERTKEYS"
                echo "[INFO] Restored binary mode + fixed syntax in insertkeys.py"
            fi
            # Also fix the copy already staged in out/ (build copies it there)
            INSERTKEYS_OUT="out/host/linux-x86/bin/insertkeys.py"
            if [ -f "$INSERTKEYS_OUT" ]; then
                sed -i 's/open(filename, "r")/open(filename, "rb")/' "$INSERTKEYS_OUT"
                sed -i 's/open(output_file, "w")/open(output_file, "wb")/' "$INSERTKEYS_OUT"
                sed -i 's/if line is not "":/if line != "":/' "$INSERTKEYS_OUT"
                echo "[INFO] Fixed insertkeys.py in out/ as well"
            fi
            # Remove stale generated mac_permissions intermediates so they regenerate
            rm -f out/target/product/*/obj/ETC/plat_mac_permissions.xml_intermediates/plat_mac_permissions.xml 2>/dev/null || true

            touch "$MARKER"
            echo "Python 2to3 conversion complete"
        fi

        # Fix mixed tabs/spaces in auto_generator.py (patch may introduce tabs)
        AUTO_GEN="device/rockchip/common/auto_generator.py"
        if [ -f "$AUTO_GEN" ]; then
            echo "[INFO] Fixing auto_generator.py..."
            python3 -c "
path = '$AUTO_GEN'
with open(path) as f:
    lines = f.readlines()
fixed = []
for i, line in enumerate(lines):
    # Normalize tabs to spaces
    stripped = line.lstrip('\t')
    leading_tabs = len(line) - len(stripped)
    line = '    ' * leading_tabs + stripped
    # Fix: if 'pass' is at same indent as 'if', push it one level deeper
    if line.rstrip() == 'pass' and i > 0:
        prev = fixed[-1].rstrip()
        if prev.startswith('if ') and prev.endswith(':'):
            # Count indent of the 'if' line
            prev_indent = len(fixed[-1]) - len(fixed[-1].lstrip(' '))
            # 'pass' should be 4 spaces deeper than 'if'
            line = ' ' * (prev_indent + 4) + 'pass\n'
    fixed.append(line)
with open(path, 'w') as f:
    f.writelines(fixed)
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
        
        ADVANTECH_START=$(date +%s)
        ./build.sh 2>&1 | tee build.log
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo ""
            echo "========================================"
            echo "BUILD FAILED"
            echo "========================================"
            tail -50 build.log
            exit 1
        fi
        echo "Build finished in $(elapsed_since $ADVANTECH_START)"
        
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

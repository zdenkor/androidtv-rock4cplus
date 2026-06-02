#!/bin/bash

# ============================================================================
# 03a-preinstall-apps.sh
# Pre-install application selection script
# Downloads APKs via curl (direct URLs + F-Droid), apkeep as optional fallback
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="/mnt/aosp-build"

# Detect all downloaded BSP directories
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

# Check .build-config if no BSPs found
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

if [ ${#BSP_DIRS[@]} -eq 0 ]; then
    echo "ERROR: No BSP directories found in $BASE_DIR"
    echo "Run 02-download-source.sh first."
    exit 1
fi

# Select BSP
if [ ${#BSP_DIRS[@]} -eq 1 ]; then
    WORK_DIR="${BSP_DIRS[0]}"
    BSP_NAME="${BSP_NAMES[0]}"
else
    echo "============================================"
    echo " Select BSP for Preinstall Apps"
    echo "============================================"
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
fi

APPS_DIR="$WORK_DIR/apps"
mkdir -p "$APPS_DIR"

# ============================================================================
# Download helpers
# ============================================================================

# Download from a direct URL with retries
download_url() {
    local url="$1"
    local dest="$2"
    local temp="${dest}.tmp"
    rm -f "$temp"

    if curl -L -f --connect-timeout 30 --max-time 300 --retry 3 --retry-delay 5 \
        -H "Accept: application/octet-stream" \
        -A "Mozilla/5.0 (Linux; Android 12)" \
        -o "$temp" "$url" 2>/dev/null; then
        if [ -f "$temp" ] && [ -s "$temp" ]; then
            local size=$(stat -c%s "$temp" 2>/dev/null || echo 0)
            if [ "$size" -gt 1000 ]; then
                mv "$temp" "$dest"
                echo "  [OK] $(basename "$dest") ($size bytes)"
                return 0
            fi
        fi
    fi
    rm -f "$temp"
    return 1
}

# Download from F-Droid package page (scrapes the APK download link)
download_fdroid() {
    local fdroid_url="$1"
    local dest="$2"

    local page
    page=$(curl -sL --connect-timeout 15 "$fdroid_url" 2>/dev/null)

    # Extract APK download link from F-Droid page
    local apk_url
    apk_url=$(echo "$page" | grep -oP 'https://f-droid\.org/repo/[^"]+\.apk' | head -1)
    if [ -z "$apk_url" ]; then
        apk_url=$(echo "$page" | grep -oP 'href="[^"]*\.apk"' | head -1 | sed 's/href="//;s/"//')
    fi

    if [ -n "$apk_url" ]; then
        echo "  F-Droid: $(basename "$apk_url")"
        download_url "$apk_url" "$dest" && return 0
    fi
    return 1
}

# Try apkeep as fallback (Google Play / APKPure / GitHub / F-Droid)
download_apkeep() {
    local pkg="$1"
    local dest="$2"

    if ! command -v apkeep &>/dev/null; then
        return 1
    fi

    local temp_dir="$APPS_DIR/.apkeep-tmp"
    mkdir -p "$temp_dir"

    for source in google-play apk-pure github fdroid; do
        rm -f "$temp_dir"/*.apk 2>/dev/null
        if apkeep -a "$pkg" -d "$source" "$temp_dir" 2>/dev/null; then
            local downloaded
            downloaded=$(find "$temp_dir" -name "*.apk" -type f 2>/dev/null | head -1)
            if [ -n "$downloaded" ] && [ -s "$downloaded" ]; then
                local size=$(stat -c%s "$downloaded" 2>/dev/null || echo 0)
                if [ "$size" -gt 1000 ]; then
                    mv "$downloaded" "$dest"
                    echo "  [OK] $(basename "$dest") ($size bytes via apkeep/$source)"
                    rm -rf "$temp_dir"
                    return 0
                fi
            fi
        fi
    done
    rm -rf "$temp_dir"
    return 1
}

# Download a single app: direct URL → F-Droid → apkeep fallback
download_app() {
    local app_name="$1"
    local pkg="$2"
    local filename="$3"
    local fallback_url="$4"
    local fdroid_url="$5"

    local dest="$APPS_DIR/$filename"

    # Skip if already downloaded and valid
    if [ -f "$dest" ] && [ -s "$dest" ]; then
        local existing_size=$(stat -c%s "$dest" 2>/dev/null || echo 0)
        if [ "$existing_size" -gt 1000 ]; then
            echo "  [SKIP] $filename (already exists, $existing_size bytes)"
            return 0
        fi
    fi

    echo "  Downloading $app_name..."

    # 1. Try direct URL
    if [ -n "$fallback_url" ] && [ "${fallback_url:0:4}" = "http" ]; then
        download_url "$fallback_url" "$dest" && return 0
    fi

    # 2. Try F-Droid page
    if [ -n "$fdroid_url" ] && [ "${fdroid_url:0:4}" = "http" ]; then
        echo "  Trying F-Droid..."
        download_fdroid "$fdroid_url" "$dest" && return 0
    fi

    # 3. Try apkeep as last resort
    if [ -n "$pkg" ] && [ "$pkg" != "SKIP" ]; then
        echo "  Trying apkeep..."
        download_apkeep "$pkg" "$dest" && return 0
    fi

    echo "  [FAIL] $app_name (no working source)"
    return 1
}

# ============================================================================
# Menu
# ============================================================================

show_menu() {
    local csv_file="$1"
    echo ""
    echo "========================================"
    echo " Preinstall Apps for Android TV"
    echo "========================================"
    echo " BSP: $BSP_NAME"
    echo " Target: $APPS_DIR"
    echo "========================================"
    echo ""

    local i=1
    local has_essential=false
    local has_additional=false

    while IFS=, read -r app_id app_name app_desc app_priority filename fallback_url fdroid_url rest; do
        [[ -z "$app_id" || "$app_id" == "app_id" || "$app_id" =~ ^# ]] && continue
        if [[ "$app_priority" == "essential" ]]; then
            if ! $has_essential; then
                echo " [ESSENTIAL - Recommended]"
                has_essential=true
            fi
            printf "   %2d) %-15s - %s\n" "$i" "$app_name" "$app_desc"
            ((i++))
        fi
    done < "$csv_file"

    while IFS=, read -r app_id app_name app_desc app_priority filename fallback_url fdroid_url rest; do
        [[ -z "$app_id" || "$app_id" == "app_id" || "$app_id" =~ ^# ]] && continue
        if [[ "$app_priority" == "additional" ]]; then
            if ! $has_additional; then
                echo ""
                echo " [ADDITIONAL]"
                has_additional=true
            fi
            printf "   %2d) %-15s - %s\n" "$i" "$app_name" "$app_desc"
            ((i++))
        fi
    done < "$csv_file"

    echo ""
    echo "    A) Select ALL apps"
    echo "    E) Select ESSENTIAL only"
    echo "    Q) Quit"
    echo ""
}

get_app_count() {
    local csv_file="$1"
    local count=0
    while IFS=, read -r app_id rest; do
        [[ -z "$app_id" || "$app_id" == "app_id" || "$app_id" =~ ^# ]] && continue
        ((count++))
    done < "$csv_file"
    echo "$count"
}

# ============================================================================
# Main
# ============================================================================

CSV_FILE="$SCRIPT_DIR/apks.csv"

if [[ ! -f "$CSV_FILE" ]]; then
    echo "ERROR: $CSV_FILE not found!"
    exit 1
fi

TOTAL_APPS=$(get_app_count "$CSV_FILE")

while true; do
    show_menu "$CSV_FILE"
    read -rp "Enter choice: " APPS_CHOICES
    APPS_CHOICES=$(echo "$APPS_CHOICES" | tr -d '[:space:]')

    if [[ -z "$APPS_CHOICES" ]]; then
        echo "  [ERROR] Empty choice. Please try again."
        continue
    fi

    if [[ "$APPS_CHOICES" == "Q" || "$APPS_CHOICES" == "q" ]]; then
        echo "Canceled by user."
        exit 0
    fi

    if [[ "$APPS_CHOICES" =~ ^[AaEe]$ ]]; then
        break
    fi
    if [[ "$APPS_CHOICES" =~ ^[0-9]+$ ]] && [ "$APPS_CHOICES" -ge 1 ] && [ "$APPS_CHOICES" -le "$TOTAL_APPS" ]; then
        break
    fi

    echo "  [ERROR] Invalid choice: '$APPS_CHOICES'. Valid: 1-$TOTAL_APPS, A, E, Q"
done

echo ""
echo "Downloading apps..."
echo ""

case "$APPS_CHOICES" in
    A|a)
        while IFS=, read -r app_id app_name app_desc app_priority filename fallback_url fdroid_url rest; do
            [[ -z "$app_id" || "$app_id" == "app_id" || "$app_id" =~ ^# ]] && continue
            download_app "$app_name" "$app_id" "$filename" "$fallback_url" "$fdroid_url" || true
        done < "$CSV_FILE"
        ;;
    E|e)
        while IFS=, read -r app_id app_name app_desc app_priority filename fallback_url fdroid_url rest; do
            [[ -z "$app_id" || "$app_id" == "app_id" || "$app_id" =~ ^# ]] && continue
            [[ "$app_priority" != "essential" ]] && continue
            download_app "$app_name" "$app_id" "$filename" "$fallback_url" "$fdroid_url" || true
        done < "$CSV_FILE"
        ;;
    *)
        local target_num=$APPS_CHOICES
        local current_num=0
        while IFS=, read -r app_id app_name app_desc app_priority filename fallback_url fdroid_url rest; do
            [[ -z "$app_id" || "$app_id" == "app_id" || "$app_id" =~ ^# ]] && continue
            ((current_num++))
            if [[ "$current_num" == "$target_num" ]]; then
                download_app "$app_name" "$app_id" "$filename" "$fallback_url" "$fdroid_url" || true
                break
            fi
        done < "$CSV_FILE"
        ;;
esac

echo ""
echo "============================================"
echo " Downloads complete!"
echo "============================================"
echo ""
echo "APKs saved to: $APPS_DIR"
echo ""
ls -lh "$APPS_DIR"/*.apk 2>/dev/null || echo "(no APKs downloaded)"
echo ""

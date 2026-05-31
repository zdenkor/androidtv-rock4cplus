#!/bin/bash

# ============================================================================
# 03a-preinstall-apps.sh
# Pre-install application selection script
# ============================================================================

# Set script and work directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .build-config to get WORK_DIR (set by 02-download-source.sh)
CONFIG_FILE="$SCRIPT_DIR/../.build-config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Fallback to local path if WORK_DIR not set
WORK_DIR="${WORK_DIR:-$(dirname "$SCRIPT_DIR")}"

# Detect BSP type from WORK_DIR
if [[ "$WORK_DIR" == *"radxa9"* ]]; then
    BSP_TYPE="radxa9"
elif [[ "$WORK_DIR" == *"vicharak12"* ]]; then
    BSP_TYPE="vicharak12"
elif [[ "$WORK_DIR" == *"aosp12"* ]]; then
    BSP_TYPE="aosp12"
else
    BSP_TYPE="unknown"
fi

# Define APPS_DIR - download to WORK_DIR/apps
APPS_DIR="$WORK_DIR/apps"
mkdir -p "$APPS_DIR"
SAVED_CHOICES_FILE="$APPS_DIR/.saved_choices"

# App definitions: name|url|file|pkg|desc
# Android 9 (API 28) has limitations - some apps excluded
declare -A APPS

# Essential apps (recommended)
APPS["SmartTube"]="https://github.com/yuliskov/SmartTube/releases/latest/download/SmartTube_stable.apk|SmartTube.apk|com.smarttube.next|SponsorBlock YouTube"
APPS["Kodi"]="https://mirrors.kodi.tv/releases/android/arm64-v8a/kodi-21.1-armeabi-v7a-android-arm64-v8a.apk|Kodi.apk|org.xbmc.kodi|Media center"
APPS["Projectivy"]="https://github.com/randomnumber123/Projectivy/releases/latest/download/Projectivy.apk|Projectivy.apk|com.riviprojectivy.launcher|Clean launcher"
APPS["TVBro"]="https://github.com/randomnumber123/TVBro/releases/latest/download/TVBro.apk|TVBro.apk|com.example.tvbro|Web browser for TV"
APPS["LocalSend"]="https://github.com/randomnumber123/LocalSend/releases/latest/download/LocalSend.apk|LocalSend.apk|com.example.localsend|AirDrop alternative"
APPS["ButtonMapper"]="https://github.com/randomnumber123/ButtonMapper/releases/latest/download/ButtonMapper.apk|ButtonMapper.apk|com.example.buttonmapper|Remap remote buttons"
APPS["Fdroid"]="https://github.com/randomnumber123/Fdroid/releases/latest/download/Fdroid.apk|Fdroid.apk|org.fdroid.fdroid|Open source app store"
APPS["AdAway"]="https://github.com/randomnumber123/AdAway/releases/latest/download/AdAway.apk|AdAway.apk|org.adaway|System-wide ad blocker"

# Additional apps
APPS["AuroraStore"]="https://github.com/randomnumber123/AuroraStore/releases/latest/download/AuroraStore.apk|AuroraStore.apk|com.aurora.store|Anonymous Google Play"
APPS["VLC"]="https://mirrors.videolan.org/vlc-android/latest/vlc-android-3.5.5-arm64-v8a.apk|VLC.apk|org.videolan.vlc|Media player"
APPS["TiviMate"]="https://github.com/randomnumber123/TiviMate/releases/latest/download/TiviMate.apk|TiviMate.apk|com.example.tivimate|IPTV player"
APPS["Xplore"]="https://github.com/randomnumber123/Xplore/releases/latest/download/Xplore.apk|Xplore.apk|com.example.xplore|File manager"
APPS["SideloadLauncher"]="https://github.com/randomnumber123/SideloadLauncher/releases/latest/download/SideloadLauncher.apk|SideloadLauncher.apk|com.example.sideloadlauncher|Show sideloaded apps"
APPS["BackgroundApps"]="https://github.com/randomnumber123/BackgroundApps/releases/latest/download/BackgroundApps.apk|BackgroundApps.apk|com.example.backgroundapps|Task killer"
APPS["AptoideTV"]="https://github.com/randomnumber123/AptoideTV/releases/latest/download/AptoideTV.apk|AptoideTV.apk|com.aptoide.tvstore|Alternative app store"

# Filter apps based on BSP type (Android 9 API 28 compatibility)
filter_apps() {
    local app_name="$1"
    if [[ "$BSP_TYPE" == "radxa9" ]]; then
        # Android 9 - exclude apps that may not be compatible
        case "$app_name" in
            AuroraStore|SideloadLauncher|AptoideTV) return 1 ;;
        esac
    fi
    return 0
}

# Display app menu
show_menu() {
    echo ""
    echo "========================================"
    echo " Preinstall Apps for Android TV"
    echo "========================================"
    echo " BSP Type: $BSP_TYPE"
    echo " Target:   $APPS_DIR"
    echo "========================================"
    echo " Select apps to download (e.g., 1,3,5 or A for all):"
    echo ""
    echo " [ESSENTIAL - Recommended]"
    local i=1
    for app in SmartTube Kodi Projectivy TVBro LocalSend ButtonMapper Fdroid AdAway; do
        if filter_apps "$app"; then
            echo "   $i) $app - ${APPS[$app]##*|}"
            ((i++))
        fi
    done
    echo ""
    echo " [ADDITIONAL]"
    for app in AuroraStore VLC TiviMate Xplore SideloadLauncher BackgroundApps AptoideTV; do
        if filter_apps "$app"; then
            echo "   $i) $app - ${APPS[$app]##*|}"
            ((i++))
        fi
    done
    echo ""
    echo "   A) Select ALL apps"
    echo "   E) Select ESSENTIAL only"
    echo "   Q) Quit without changes"
    echo ""
}

# Download an app
download_app() {
    local app_name="$1"
    local app_data="${APPS[$app_name]}"
    local url="${app_data%%|*}"
    local file="${app_data##*|}"
    file="${file%%|*}"
    local pkg="${app_data##*|}"
    pkg="${pkg%%|*}"
    
    echo "  Downloading $app_name..."
    if curl -L -o "$APPS_DIR/$file" --progress-bar "$url" 2>/dev/null; then
        echo "  [OK] $app_name downloaded"
        return 0
    else
        echo "  [FAIL] $app_name failed"
        return 1
    fi
}

# Main logic
show_menu

# Check for saved choices
if [[ -f "$SAVED_CHOICES_FILE" ]]; then
    read -r -p "Use saved choices? (y/n): " use_saved
    if [[ "$use_saved" == "y" || "$use_saved" == "Y" ]]; then
        APPS_CHOICES=$(cat "$SAVED_CHOICES_FILE")
    fi
fi

if [[ -z "$APPS_CHOICES" ]]; then
    read -r -p "Enter choice: " APPS_CHOICES
fi

# Parse choices
if [[ "$APPS_CHOICES" == "Q" || "$APPS_CHOICES" == "q" ]]; then
    echo "Exiting..."
    exit 0
fi

# Save choices
echo "$APPS_CHOICES" > "$SAVED_CHOICES_FILE"

echo ""
echo "========================================"
echo " Downloading selected apps..."
echo "========================================"

# Process selections
case "$APPS_CHOICES" in
    A|a)
        for app in "${!APPS[@]}"; do
            filter_apps "$app" && download_app "$app"
        done
        ;;
    E|e)
        for app in SmartTube Kodi Projectivy TVBro LocalSend ButtonMapper Fdroid AdAway; do
            filter_apps "$app" && download_app "$app"
        done
        ;;
    *)
        # Parse numeric selection
        i=1
        for app in SmartTube Kodi Projectivy TVBro LocalSend ButtonMapper Fdroid AdAway AuroraStore VLC TiviMate Xplore SideloadLauncher BackgroundApps AptoideTV; do
            if filter_apps "$app"; then
                if [[ "$APPS_CHOICES" == *"$i"* ]]; then
                    download_app "$app"
                fi
                ((i++))
            fi
        done
        ;;
esac

echo ""
echo "========================================"
echo " Download complete! Apps saved to:"
echo " $APPS_DIR"
echo "========================================"
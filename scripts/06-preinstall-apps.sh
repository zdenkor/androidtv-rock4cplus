#!/bin/bash
# =============================================================================
# 06-preinstall-apps.sh
# Downloads and integrates preinstalled apps into the Android TV build
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
echo " Preinstalled Apps for Android TV"
echo "============================================"
echo ""

APPS_DIR="$WORK_DIR/vendor/rockchip/apps"
mkdir -p "$APPS_DIR"

# ---------------------------------------------------------------------------
# App definitions: name, URL, filename, description
# ---------------------------------------------------------------------------
declare -A APPS

# --- Essential Apps ---
APPS[SmartTube,url]="https://github.com/yuliskov/SmartTube/releases/latest/download/SmartTube_stable.apk"
APPS[SmartTube,file]="SmartTube.apk"
APPS[SmartTube,desc]="Ad-free YouTube client with 4K HDR, SponsorBlock"

APPS[Kodi,url]="https://mirrors.kodi.tv/releases/android/arm64-v8a/kodi-21.2-Omega-arm64-v8a.apk"
APPS[Kodi,file]="Kodi.apk"
APPS[Kodi,desc]="Media center (local files, Plex, Jellyfin, IPTV)"

APPS[ProjectivyLauncher,url]="https://github.com/spocky/miproja1/releases/latest/download/ProjectivyLauncher.apk"
APPS[ProjectivyLauncher,file]="ProjectivyLauncher.apk"
APPS[ProjectivyLauncher,desc]="Customizable Android TV launcher (no ads)"

APPS[TVBro,url]="https://github.com/truefedex/tv-bro/releases/latest/download/tv-bro.apk"
APPS[TVBro,file]="TVBro.apk"
APPS[TVBro,desc]="Web browser optimized for TV remote control"

APPS[LocalSend,url]="https://github.com/localsend/localsend/releases/latest/download/LocalSend-android-arm64.apk"
APPS[LocalSend,file]="LocalSend.apk"
APPS[LocalSend,desc]="AirDrop-like file sharing (cross-platform)"

APPS[ButtonMapper,url]="https://github.com/florisboard/florisboard/releases/latest/download/app-release.apk"
APPS[ButtonMapper,file]="ButtonMapper.apk"
APPS[ButtonMapper,desc]="Remap remote control buttons"

APPS[FDroid,url]="https://f-droid.org/F-Droid.apk"
APPS[FDroid,file]="FDroid.apk"
APPS[FDroid,desc]="Open-source app store"

APPS[AdAway,url]="https://app.adaway.org/adaway.apk"
APPS[AdAway,file]="AdAway.apk"
APPS[AdAway,desc]="System-wide ad blocker (hosts-based, needs root)"

# --- Additional Recommended Apps ---
APPS[AuroraStore,url]="https://gitlab.com/AuroraOSS/AuroraStore/-/releases/permalink/latest/downloads/AuroraStore.apk"
APPS[AuroraStore,file]="AuroraStore.apk"
APPS[AuroraStore,desc]="Anonymous Google Play Store client"

APPS[VLC,url]="https://get.videolan.org/vlc-android/3.5.7/VLC-Android-3.5.7-arm64.apk"
APPS[VLC,file]="VLC.apk"
APPS[VLC,desc]="Universal media player"

APPS[TiviMate,url]="https://tivimate.com/download/TiviMate.apk"
APPS[TiviMate,file]="TiviMate.apk"
APPS[TiviMate,desc]="IPTV player with EPG guide"

APPS[Xplore,url]="https://www.lonelycatgames.com/download/xplore/X-plore.apk"
APPS[Xplore,file]="Xplore.apk"
APPS[Xplore,desc]="File manager with network shares (SMB, FTP)"

APPS[SideloadLauncher,url]="https://github.com/Chainfire/SideloadLauncher/releases/latest/download/SideloadLauncher.apk"
APPS[SideloadLauncher,file]="SideloadLauncher.apk"
APPS[SideloadLauncher,desc]="Show sideloaded apps in Android TV launcher"

APPS[BackgroundApps,url]="https://f-droid.org/repo/com.ebaschiera.backgroundappsandprocesslist.apk"
APPS[BackgroundApps,file]="BackgroundApps.apk"
APPS[BackgroundApps,desc]="Task manager / force-stop apps"

APPS[AptoideTV,url]="https://aptoide-tv.en.uptodown.com/android/download"
APPS[AptoideTV,file]="AptoideTV.apk"
APPS[AptoideTV,desc]="App store designed for Android TV"

# ---------------------------------------------------------------------------
# Download apps
# ---------------------------------------------------------------------------
echo "Select apps to preinstall:"
echo ""
echo "  ESSENTIAL (recommended):"
echo "    [1] SmartTube          - ${APPS[SmartTube,desc]}"
echo "    [2] Kodi               - ${APPS[Kodi,desc]}"
echo "    [3] Projectivy Launcher - ${APPS[ProjectivyLauncher,desc]}"
echo "    [4] TV Bro             - ${APPS[TVBro,desc]}"
echo "    [5] LocalSend          - ${APPS[LocalSend,desc]}"
echo "    [6] Button Mapper      - ${APPS[ButtonMapper,desc]}"
echo "    [7] F-Droid            - ${APPS[FDroid,desc]}"
echo "    [8] AdAway             - ${APPS[AdAway,desc]}"
echo ""
echo "  ADDITIONAL:"
echo "    [9] Aurora Store       - ${APPS[AuroraStore,desc]}"
echo "   [10] VLC                - ${APPS[VLC,desc]}"
echo "   [11] TiviMate           - ${APPS[TiviMate,desc]}"
echo "   [12] X-plore            - ${APPS[Xplore,desc]}"
echo "   [13] Sideload Launcher  - ${APPS[SideloadLauncher,desc]}"
echo "   [14] Background Apps    - ${APPS[BackgroundApps,desc]}"
echo "   [15] Aptoide TV         - ${APPS[AptoideTV,desc]}"
echo ""
echo "  [A] ALL apps (1-15)"
echo "  [E] Essential only (1-8)"
echo ""
read -rp "Enter choices (e.g., 1,2,3,7 or A): " APP_CHOICES

# Parse choices
SELECTED=()
if [ "$APP_CHOICES" = "A" ] || [ "$APP_CHOICES" = "a" ]; then
    SELECTED=("SmartTube" "Kodi" "ProjectivyLauncher" "TVBro" "LocalSend" "ButtonMapper" "FDroid" "AdAway" "AuroraStore" "VLC" "TiviMate" "Xplore" "SideloadLauncher" "BackgroundApps" "AptoideTV")
elif [ "$APP_CHOICES" = "E" ] || [ "$APP_CHOICES" = "e" ]; then
    SELECTED=("SmartTube" "Kodi" "ProjectivyLauncher" "TVBro" "LocalSend" "ButtonMapper" "FDroid" "AdAway")
else
    IFS=',' read -ra NUMS <<< "$APP_CHOICES"
    declare -A MAP=([1]="SmartTube" [2]="Kodi" [3]="ProjectivyLauncher" [4]="TVBro" [5]="LocalSend" [6]="ButtonMapper" [7]="FDroid" [8]="AdAway" [9]="AuroraStore" [10]="VLC" [11]="TiviMate" [12]="Xplore" [13]="SideloadLauncher" [14]="BackgroundApps" [15]="AptoideTV")
    for n in "${NUMS[@]}"; do
        n=$(echo "$n" | xargs)  # trim whitespace
        if [ -n "${MAP[$n]}" ]; then
            SELECTED+=("${MAP[$n]}")
        fi
    done
fi

# ---------------------------------------------------------------------------
# Download selected apps
# ---------------------------------------------------------------------------
echo ""
echo "Downloading selected apps..."
echo ""

DOWNLOADED=0
FAILED=0

for app in "${SELECTED[@]}"; do
    url="${APPS[$app,url]}"
    file="${APPS[$app,file]}"
    
    echo "  [$app] $url"
    
    if command -v wget &>/dev/null; then
        if wget -q --show-progress -O "$APPS_DIR/$file" "$url" 2>/dev/null; then
            echo "    -> Downloaded: $file"
            ((DOWNLOADED++)) || true
        else
            echo "    -> FAILED (will need manual download)"
            ((FAILED++)) || true
        fi
    elif command -v curl &>/dev/null; then
        if curl -sSL -o "$APPS_DIR/$file" "$url" 2>/dev/null; then
            echo "    -> Downloaded: $file"
            ((DOWNLOADED++)) || true
        else
            echo "    -> FAILED (will need manual download)"
            ((FAILED++)) || true
        fi
    else
        echo "    -> No download tool available. Install wget or curl."
        ((FAILED++)) || true
    fi
done

# ---------------------------------------------------------------------------
# Create Android.mk for prebuilt apps
# ---------------------------------------------------------------------------
echo ""
echo "Creating Android.mk for prebuilt apps..."

cat > "$APPS_DIR/Android.mk" << 'MKEOF'
LOCAL_PATH := $(call my-dir)

MKEOF

for app in "${SELECTED[@]}"; do
    file="${APPS[$app,file]}"
    if [ -f "$APPS_DIR/$file" ]; then
        # Convert app name to lowercase module name
        module_name=$(echo "$app" | tr '[:upper:]' '[:lower:]')
        
        cat >> "$APPS_DIR/Android.mk" << MKEOF

# $app - ${APPS[$app,desc]}
include \$(CLEAR_VARS)
LOCAL_MODULE := $module_name
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := $file
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := \$(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_PRIVILEGED_MODULE := false
LOCAL_DEX_PREOPT := false
include \$(BUILD_PREBUILT)
MKEOF
    fi
done

# ---------------------------------------------------------------------------
# Add to device.mk
# ---------------------------------------------------------------------------
DEVICE_MK="$WORK_DIR/device/rockchip/rk3399/device.mk"
if [ ! -f "$DEVICE_MK" ]; then
    DEVICE_MK="$WORK_DIR/device/rockchip/common/device.mk"
fi

if [ -f "$DEVICE_MK" ]; then
    if ! grep -q "vendor/rockchip/apps" "$DEVICE_MK" 2>/dev/null; then
        cat >> "$DEVICE_MK" << 'MKEOF'

# === Preinstalled Apps ===
PRODUCT_PACKAGES += \
MKEOF
        for app in "${SELECTED[@]}"; do
            module_name=$(echo "$app" | tr '[:upper:]' '[:lower:]')
            if [ -f "$APPS_DIR/${APPS[$app,file]}" ]; then
                echo "    $module_name \\" >> "$DEVICE_MK"
            fi
        done
        # Remove trailing backslash from last line
        sed -i '$ s/ \\$//' "$DEVICE_MK"
        echo "" >> "$DEVICE_MK"
        echo "Preinstalled apps added to $DEVICE_MK"
    else
        echo "Preinstalled apps already configured in $DEVICE_MK"
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo " Preinstalled Apps Summary"
echo "============================================"
echo ""
echo "Downloaded: $DOWNLOADED | Failed: $FAILED"
echo "Location: $APPS_DIR"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo "Some apps failed to download. Place APKs manually in:"
    echo "  $APPS_DIR"
    echo ""
    echo "Then re-run this script to regenerate Android.mk."
fi

echo "Apps will be included in the next build."
echo ""

#!/bin/bash
# =============================================================================
# 03a-preinstall-apps.sh
# Downloads and integrates preinstalled apps into the Android TV build
# =============================================================================

# NOTE: Not using 'set -e' — we handle errors explicitly so the script
# doesn't silently exit on download failures.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default work directory (USB drive mount point)
WORK_DIR="${WORK_DIR:-/mnt/aosp-build/androidtv-rock4cplus}"

# Optionally load .build-config if it exists (for custom paths)
CONFIG_FILE="$SCRIPT_DIR/../.build-config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
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
APPS[SmartTube,pkg]="com.liskovsoft.smarttubetv"

APPS[Kodi,url]="https://mirrors.kodi.tv/releases/android/arm64-v8a/kodi-21.2-Omega-arm64-v8a.apk"
APPS[Kodi,file]="Kodi.apk"
APPS[Kodi,desc]="Media center (local files, Plex, Jellyfin, IPTV) — versioned URL, apkeep fallback recommended"
APPS[Kodi,pkg]="org.xbmc.kodi"

APPS[ProjectivyLauncher,url]="https://github.com/spocky/miproja1/releases/latest/download/ProjectivyLauncher.apk"
APPS[ProjectivyLauncher,file]="ProjectivyLauncher.apk"
APPS[ProjectivyLauncher,desc]="Customizable Android TV launcher (no ads)"

APPS[TVBro,url]="https://github.com/truefedex/tv-bro/releases/latest/download/tv-bro.apk"
APPS[TVBro,file]="TVBro.apk"
APPS[TVBro,desc]="Web browser optimized for TV remote control"
APPS[TVBro,pkg]="com.phlox.tvwebbrowser"

APPS[LocalSend,url]="https://github.com/localsend/localsend/releases/latest/download/LocalSend-android-arm64.apk"
APPS[LocalSend,file]="LocalSend.apk"
APPS[LocalSend,desc]="AirDrop-like file sharing (cross-platform)"
APPS[LocalSend,pkg]="org.localsend.localsend_app"

APPS[KeyMapper,url]="https://f-droid.org/repo/io.github.sds100.keymapper.apk"
APPS[KeyMapper,file]="KeyMapper.apk"
APPS[KeyMapper,desc]="Remap keys and buttons (TV remote, gamepad, keyboard)"
APPS[KeyMapper,pkg]="io.github.sds100.keymapper"

APPS[FDroid,url]="https://f-droid.org/F-Droid.apk"
APPS[FDroid,file]="FDroid.apk"
APPS[FDroid,desc]="Open-source app store"
APPS[FDroid,pkg]="org.fdroid.fdroid"

APPS[AdAway,url]="https://app.adaway.org/adaway.apk"
APPS[AdAway,file]="AdAway.apk"
APPS[AdAway,desc]="System-wide ad blocker (hosts-based, needs root)"
APPS[AdAway,pkg]="org.adaway"

# --- Additional Recommended Apps ---
APPS[AuroraStore,url]="https://f-droid.org/repo/com.aurora.store.apk"
APPS[AuroraStore,file]="AuroraStore.apk"
APPS[AuroraStore,desc]="Anonymous Google Play Store client (via F-Droid — stable URL)"
APPS[AuroraStore,pkg]="com.aurora.store"

APPS[VLC,url]="https://f-droid.org/repo/org.videolan.vlc.apk"
APPS[VLC,file]="VLC.apk"
APPS[VLC,desc]="Universal media player (via F-Droid — stable URL)"
APPS[VLC,pkg]="org.videolan.vlc"

APPS[TiviMate,url]="https://tivimate.com/download/TiviMate.apk"
APPS[TiviMate,file]="TiviMate.apk"
APPS[TiviMate,desc]="IPTV player with EPG guide (MANUAL DOWNLOAD REQUIRED — proprietary app, get from tivimate.com)"
APPS[TiviMate,pkg]="com.aronszabo.tvplayer"

APPS[Xplore,url]="https://github.com/zhanghai/MaterialFiles/releases/latest/download/app-release-universal.apk"
APPS[Xplore,file]="Xplore.apk"
APPS[Xplore,desc]="Material Design file manager (replaces broken X-plore)"
APPS[Xplore,pkg]="me.zhanghai.android.files"

APPS[SideloadLauncher,url]="https://github.com/Droid-ify/client/releases/latest/download/app-release.apk"
APPS[SideloadLauncher,file]="SideloadLauncher.apk"
APPS[SideloadLauncher,desc]="F-Droid client with modern UI (replaces broken SideloadLauncher)"
APPS[SideloadLauncher,pkg]="com.looker.droidify"

APPS[BackgroundApps,url]="https://github.com/TeamAmaze/AmazeFileManager/releases/latest/download/app-fdroid-release.apk"
APPS[BackgroundApps,file]="BackgroundApps.apk"
APPS[BackgroundApps,desc]="Feature-rich file manager (replaces broken Background Apps)"
APPS[BackgroundApps,pkg]="com.amaze.filemanager"

APPS[AptoideTV,url]="https://aptoide-tv.en.uptodown.com/android/download"
APPS[AptoideTV,file]="AptoideTV.apk"
APPS[AptoideTV,desc]="App store for Android TV (MANUAL ONLY — no direct download. Get from aptoide.com or skip)"
APPS[AptoideTV,pkg]="cm.aptoide.pt"

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
echo "    [6] Key Mapper         - ${APPS[KeyMapper,desc]}"
echo "    [7] F-Droid            - ${APPS[FDroid,desc]}"
echo "    [8] AdAway             - ${APPS[AdAway,desc]}"
echo ""
echo "  ADDITIONAL:"
echo "    [9] Aurora Store       - ${APPS[AuroraStore,desc]}"
echo "   [10] VLC                - ${APPS[VLC,desc]}"
echo "   [11] TiviMate (manual)  - ${APPS[TiviMate,desc]}"
echo "   [12] MaterialFiles      - ${APPS[Xplore,desc]}"
echo "   [13] Droid-ify          - ${APPS[SideloadLauncher,desc]}"
echo "   [14] AmazeFileManager   - ${APPS[BackgroundApps,desc]}"
echo "   [15] AptoideTV (manual) - ${APPS[AptoideTV,desc]}"
echo ""
echo "  [A] ALL apps (1-15)"
echo "  [E] Essential only (1-8)"
echo "  [W] Working apps only (auto-downloadable, excludes manual)"
echo ""
read -rp "Enter choices (e.g., 1,2,3,7 or A): " APP_CHOICES

# Parse choices
SELECTED=()
if [ "$APP_CHOICES" = "A" ] || [ "$APP_CHOICES" = "a" ]; then
    SELECTED=("SmartTube" "Kodi" "ProjectivyLauncher" "TVBro" "LocalSend" "KeyMapper" "FDroid" "AdAway" "AuroraStore" "VLC" "TiviMate" "Xplore" "SideloadLauncher" "BackgroundApps" "AptoideTV")
elif [ "$APP_CHOICES" = "E" ] || [ "$APP_CHOICES" = "e" ]; then
    SELECTED=("SmartTube" "Kodi" "ProjectivyLauncher" "TVBro" "LocalSend" "KeyMapper" "FDroid" "AdAway")
elif [ "$APP_CHOICES" = "W" ] || [ "$APP_CHOICES" = "w" ]; then
    SELECTED=("SmartTube" "Kodi" "ProjectivyLauncher" "TVBro" "LocalSend" "KeyMapper" "FDroid" "AdAway" "AuroraStore" "VLC" "Xplore" "SideloadLauncher" "BackgroundApps")
    echo ""
    echo "Selected working apps only (excludes TiviMate, AptoideTV — manual download required)"
else
    IFS=',' read -ra NUMS <<< "$APP_CHOICES"
    declare -A MAP=([1]="SmartTube" [2]="Kodi" [3]="ProjectivyLauncher" [4]="TVBro" [5]="LocalSend" [6]="KeyMapper" [7]="FDroid" [8]="AdAway" [9]="AuroraStore" [10]="VLC" [11]="TiviMate" [12]="Xplore" [13]="SideloadLauncher" [14]="BackgroundApps" [15]="AptoideTV")
    for n in "${NUMS[@]}"; do
        n=$(echo "$n" | xargs)  # trim whitespace
        if [ -n "${MAP[$n]}" ]; then
            SELECTED+=("${MAP[$n]}")
        fi
    done
fi

# ---------------------------------------------------------------------------
# Helper: resolve GitHub /latest/download/ and GitLab /permalink/latest/ URLs
# via their respective APIs. These are FUTURE-PROOF — they always fetch the
# latest release regardless of version number changes.
#
# Direct URLs (Kodi, VLC, F-Droid, AdAway, etc.) are NOT resolved here —
# they pass through unchanged and must be updated manually when versions change.
# ---------------------------------------------------------------------------
resolve_release_url() {
    local url="$1"
    
    # --- GitHub: github.com/OWNER/REPO/releases/latest/download/FILENAME ---
    # Uses GitHub Releases API. Works for ANY repo with releases.
    # Picks arm64-v8a > arm64 > universal > aarch64 > first available.
    if [[ "$url" =~ github\.com/([^/]+/[^/]+)/releases/latest/download/(.+) ]]; then
        local repo="${BASH_REMATCH[1]}"
        local api_url="https://api.github.com/repos/$repo/releases/latest"
        local download_url
        
        local all_urls
        all_urls=$(curl -sSL "$api_url" 2>/dev/null | grep -o '"browser_download_url": *"[^"]*\.apk"' | grep -o 'https://[^"]*')
        
        if [ -n "$all_urls" ]; then
            download_url=$(echo "$all_urls" | grep -i "arm64-v8a" | head -1)
            [ -z "$download_url" ] && download_url=$(echo "$all_urls" | grep -i "arm64" | head -1)
            [ -z "$download_url" ] && download_url=$(echo "$all_urls" | grep -i "universal" | head -1)
            [ -z "$download_url" ] && download_url=$(echo "$all_urls" | grep -i "aarch64" | head -1)
            [ -z "$download_url" ] && download_url=$(echo "$all_urls" | head -1)
        fi
        
        if [ -n "$download_url" ]; then
            echo "$download_url"
            return 0
        fi
    fi
    
    # --- GitLab: gitlab.com/OWNER/REPO/-/releases/permalink/latest/downloads/FILENAME ---
    # Uses GitLab Releases API. Works for ANY project with releases.
    if [[ "$url" =~ gitlab\.com/([^/]+/[^/]+)/-/releases/permalink/latest/downloads/(.+) ]]; then
        local repo="${BASH_REMATCH[1]}"
        local encoded_repo="${repo//\//%2F}"
        local api_url="https://gitlab.com/api/v4/projects/${encoded_repo}/releases/permalink/latest"
        local download_url
        
        # GitLab API returns JSON with assets.links array containing direct_asset_url
        # We need to follow redirects (-L) and extract the actual .apk URLs
        local api_response
        api_response=$(curl -sSL "$api_url" 2>/dev/null)
        
        # Extract all direct_asset_url values for .apk files
        local all_urls
        all_urls=$(echo "$api_response" | grep -o '"direct_asset_url":"[^"]*\.apk"' | sed 's/"direct_asset_url":"//g; s/"$//g; s/\\//g')
        
        # Fallback: if no direct_asset_url, try browser_download_url or url field
        if [ -z "$all_urls" ]; then
            all_urls=$(echo "$api_response" | grep -o '"url":"[^"]*\.apk"' | sed 's/"url":"//g; s/"$//g; s/\\//g')
        fi
        
        if [ -n "$all_urls" ]; then
            download_url=$(echo "$all_urls" | grep -i "arm64-v8a" | head -1)
            [ -z "$download_url" ] && download_url=$(echo "$all_urls" | grep -i "arm64" | head -1)
            [ -z "$download_url" ] && download_url=$(echo "$all_urls" | grep -i "universal" | head -1)
            [ -z "$download_url" ] && download_url=$(echo "$all_urls" | grep -i "aarch64" | head -1)
            [ -z "$download_url" ] && download_url=$(echo "$all_urls" | head -1)
        fi
        
        if [ -n "$download_url" ]; then
            echo "$download_url"
            return 0
        fi
    fi
    
    # Not a recognized API-backed URL — return original (direct URL)
    echo "$url"
    return 1
}

# ---------------------------------------------------------------------------
# Download selected apps
# ---------------------------------------------------------------------------
echo ""
echo "Downloading selected apps..."
echo ""

DOWNLOADED=0
SKIPPED=0
FAILED=0

for app in "${SELECTED[@]}"; do
    url="${APPS[$app,url]}"
    file="${APPS[$app,file]}"
    
    echo "  [$app] $url"
    
    # Skip if already downloaded (file exists, is >10KB, and is a valid APK)
    if [ -f "$APPS_DIR/$file" ]; then
        local_size=$(stat -c%s "$APPS_DIR/$file" 2>/dev/null || stat -f%z "$APPS_DIR/$file" 2>/dev/null || echo 0)
        if [ "$local_size" -gt 10000 ] && head -c2 "$APPS_DIR/$file" | grep -q 'PK'; then
            echo "    -> Already downloaded ($(numfmt --to=iec $local_size 2>/dev/null || echo ${local_size} bytes)), skipping"
            ((SKIPPED++)) || true
            continue
        else
            echo "    -> Existing file invalid (${local_size} bytes, not an APK), re-downloading..."
            rm -f "$APPS_DIR/$file"
        fi
    fi
    
    # Resolve GitHub/GitLab /latest/ URLs via API
    resolved_url=$(resolve_release_url "$url")
    if [ "$resolved_url" != "$url" ]; then
        echo "    -> Resolved: $resolved_url"
    fi
    
    downloaded=false

    # --- Method 1: wget ---
    if ! $downloaded && command -v wget &>/dev/null; then
        set -o pipefail
        if wget --show-progress -O "$APPS_DIR/$file" --user-agent="Mozilla/5.0 (Linux; Android 14; TV) AppleWebKit/537.36" "$resolved_url" 2>&1 | tail -5; then
            set +o pipefail
            if [ -f "$APPS_DIR/$file" ] && head -c2 "$APPS_DIR/$file" | grep -q 'PK'; then
                echo "    -> Downloaded: $file"
                downloaded=true
            else
                echo "    -> wget got invalid file (not APK), will try fallback..."
                rm -f "$APPS_DIR/$file"
            fi
        else
            set +o pipefail
            echo "    -> wget failed (HTTP error), will try fallback..."
        fi
    fi

    # --- Method 2: curl ---
    if ! $downloaded && command -v curl &>/dev/null; then
        if curl -SL --progress-bar -o "$APPS_DIR/$file" -H "User-Agent: Mozilla/5.0 (Linux; Android 14; TV) AppleWebKit/537.36" "$resolved_url"; then
            if [ -f "$APPS_DIR/$file" ] && head -c2 "$APPS_DIR/$file" | grep -q 'PK'; then
                echo "    -> Downloaded: $file"
                downloaded=true
            else
                echo "    -> curl got invalid file (not APK), will try fallback..."
                rm -f "$APPS_DIR/$file"
            fi
        else
            echo "    -> curl failed (HTTP error), will try fallback..."
        fi
    fi

    # --- Method 3: apkeep (APKMirror -> F-Droid) ---
    if ! $downloaded && command -v apkeep &>/dev/null && [ -n "${APPS[$app,pkg]}" ]; then
        echo "    -> Trying apkeep fallback for ${APPS[$app,pkg]}..."
        # Try APKMirror first
        if apkeep -a "${APPS[$app,pkg]}" -d apkmirror "$APPS_DIR" 2>/dev/null; then
            mv -f "$APPS_DIR/${APPS[$app,pkg]}.apk" "$APPS_DIR/$file" 2>/dev/null
            if [ -f "$APPS_DIR/$file" ] && head -c2 "$APPS_DIR/$file" | grep -q 'PK'; then
                echo "    -> Downloaded via apkeep (APKMirror): $file"
                downloaded=true
            else
                echo "    -> apkeep APKMirror download invalid, trying F-Droid..."
                rm -f "$APPS_DIR/$file" "$APPS_DIR/${APPS[$app,pkg]}.apk" 2>/dev/null
            fi
        fi
        # If still not downloaded, try F-Droid
        if ! $downloaded; then
            if apkeep -a "${APPS[$app,pkg]}" -d fdroid "$APPS_DIR" 2>/dev/null; then
                mv -f "$APPS_DIR/${APPS[$app,pkg]}.apk" "$APPS_DIR/$file" 2>/dev/null
                if [ -f "$APPS_DIR/$file" ] && head -c2 "$APPS_DIR/$file" | grep -q 'PK'; then
                    echo "    -> Downloaded via apkeep (F-Droid): $file"
                    downloaded=true
                else
                    echo "    -> apkeep F-Droid download invalid"
                    rm -f "$APPS_DIR/$file" "$APPS_DIR/${APPS[$app,pkg]}.apk" 2>/dev/null
                fi
            fi
        fi
    fi

    # --- Final accounting ---
    if $downloaded; then
        ((DOWNLOADED++)) || true
    else
        echo "    -> FAILED (all download methods exhausted)"
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
echo "Downloaded: $DOWNLOADED | Skipped (already present): $SKIPPED | Failed: $FAILED"
echo "Location: $APPS_DIR"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo "Some apps failed to download. Place APKs manually in:"
    echo "  $APPS_DIR"
    echo ""
    echo "Then re-run this script to regenerate Android.mk."
elif [ "$DOWNLOADED" -eq 0 ] && [ "$SKIPPED" -gt 0 ]; then
    echo "All apps already present — nothing to download."
fi

echo "Apps will be included in the next build."
echo ""

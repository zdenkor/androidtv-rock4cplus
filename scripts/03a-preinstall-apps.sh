#!/bin/bash

# ============================================================================
# 03a-preinstall-apps.sh
# Pre-install application selection script
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="/mnt/aosp-build"

# Detect all downloaded BSP directories
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

# Error if no BSP found
if [ ${#BSP_DIRS[@]} -eq 0 ]; then
    echo "ERROR: No BSP directories found in $BASE_DIR"
    echo "Run 02-download-source.sh first."
    exit 1
fi

# Gmail setup for Google Play downloads via apkeep
# apkeep uses AUTH token - see https://github.com/EFForg/apkeep/blob/master/USAGE-google-play.md

setup_apkeep_credentials() {
    APKEEP_EMAIL_FILE="$APPS_DIR/.apkkeep_email"
    APKEEP_TOKEN_FILE="$APPS_DIR/.apkkeep_token"
    echo ""
    echo "============================================"
    echo " Gmail Setup for Google Play Downloads"
    echo "============================================"
    echo ""
    echo "apkeep requires AUTH token for Google Play."
    echo "Get free AUTH token from Aurora Store:"
    echo "  https://auroraoss.com/AuroraStore/Download"
    echo ""
    
    if [ -f "$APKEEP_TOKEN_FILE" ] && [ -s "$APKEEP_TOKEN_FILE" ]; then
        read -rp "Use saved AUTH token? (y/n): " use_saved
        if [[ "$use_saved" != "y" && "$use_saved" != "Y" ]]; then
            setup_new_credentials
        fi
    else
        setup_new_credentials
    fi
}

setup_new_credentials() {
    echo ""
    read -rp "Gmail address: " APKEEP_EMAIL
    echo ""
    echo "AUTH token (from Aurora Store, starts with 'ya29.'):"
    read -rsp "AUTH token: " APKEEP_TOKEN
    echo ""
    
    if [ -n "$APKEEP_EMAIL" ] && [ -n "$APKEEP_TOKEN" ]; then
        echo "$APKEEP_EMAIL" > "$APPS_DIR/.apkkeep_email"
        echo "$APKEEP_TOKEN" > "$APPS_DIR/.apkkeep_token"
        chmod 600 "$APPS_DIR/.apkkeep_email" "$APPS_DIR/.apkkeep_token" 2>/dev/null
        echo "Credentials saved."
    fi
}

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
    read -rp "Enter choice (1-${#BSP_DIRS[@]}): " CHOICE
    if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#BSP_DIRS[@]} ]; then
        echo "ERROR: Invalid choice"
        exit 1
    fi
    WORK_DIR="${BSP_DIRS[$((CHOICE-1))]}"
    BSP_NAME="${BSP_NAMES[$((CHOICE-1))]}"
fi

# Determine BSP type
if [[ "$BSP_NAME" == *radxa9* ]]; then
    BSP_TYPE="radxa9"
elif [[ "$BSP_NAME" == *vicharak12* ]]; then
    BSP_TYPE="vicharak12"
elif [[ "$BSP_NAME" == *aosp12* ]]; then
    BSP_TYPE="aosp12"
else
    BSP_TYPE="unknown"
fi

# Define APPS_DIR - download to WORK_DIR/apps
APPS_DIR="$WORK_DIR/apps"
mkdir -p "$APPS_DIR"
SAVED_CHOICES_FILE="$APPS_DIR/.saved_choices"

# App definitions: pkg|apkpure|github|apkmonk|direct|filename|desc
declare -A APPS

# Essential apps (recommended)
APPS["SmartTube"]="com.smarttube.next|||https://github.com/yuliskov/SmartTube/releases/latest/download/SmartTube_stable.apk|SmartTube.apk|SponsorBlock YouTube"
APPS["Kodi"]="org.xbmc.kodi|||https://mirrors.kodi.tv/releases/android/arm64-v8a/kodi-21.1-armeabi-v7a-android-arm64-v8a.apk|Kodi.apk|Media center"
APPS["Projectivy"]="com.riviprojectivy.launcher||||Projectivy.apk|Clean launcher"
APPS["TVBro"]="com.example.tvbro||||TVBro.apk|Web browser for TV"
APPS["LocalSend"]="com.example.localsend||||LocalSend.apk|AirDrop alternative"
APPS["ButtonMapper"]="com.example.buttonmapper||||ButtonMapper.apk|Remap remote buttons"
APPS["Fdroid"]="org.fdroid.fdroid|||https://f-droid.org/repo/org.fdroid.fdroid_160900.apk|Fdroid.apk|Open source app store"
APPS["AdAway"]="org.adaway|||https://f-droid.org/repo/org.adaway_20191010.apk|AdAway.apk|System-wide ad blocker"

# Additional apps
APPS["AuroraStore"]="com.aurora.store||||AuroraStore.apk|Anonymous Google Play"
APPS["VLC"]="org.videolan.vlc|||https://mirrors.videolan.org/vlc/android/3.5.5/vlc-android-3.5.5-arm64-v8a.apk|VLC.apk|Media player"
APPS["TiviMate"]="com.example.tivimate||||TiviMate.apk|IPTV player"
APPS["Xplore"]="com.lonelycatgame.xplore||||Xplore.apk|File manager"
APPS["SideloadLauncher"]="com.example.sideloadlauncher||||SideloadLauncher.apk|Show sideloaded apps"
APPS["AptoideTV"]="com.aptoide.tvstore||||AptoideTV.apk|Alternative app store"

# Filter apps based on BSP type (Android 9 API 28 compatibility)
filter_apps() {
    local app_name="$1"
    if [[ "$BSP_TYPE" == "radxa9" ]]; then
        case "$app_name" in
            AuroraStore|SideloadLauncher|AptoideTV) return 1 ;;
        esac
    fi
    return 0
}

# Download an app - tries multiple sources in order
download_app() {
    local app_name="$1"
    local app_data="${APPS[$app_name]}"
    
    # Parse: pkg|apkpure|github|apkmonk|direct|filename|desc
    local pkg="${app_data%%|*}"
    app_data="${app_data#*|}"
    local apkpure="${app_data%%|*}"
    app_data="${app_data#*|}"
    local github="${app_data%%|*}"
    app_data="${app_data#*|}"
    local apkmonk="${app_data%%|*}"
    app_data="${app_data#*|}"
    local direct="${app_data%%|*}"
    app_data="${app_data#*|}"
    local file="${app_data%%|*}"
    local desc="${app_data##*|}"
    
    local dest="$APPS_DIR/$file"
    local success=false
    
    echo "  Downloading $app_name..."
    
    # 1) Try apkeep (Google Play as primary, then other sources)
    if command -v apkeep &>/dev/null; then
        # Load AUTH token if available
        local email_opt=""
        local token_opt=""
        if [ -f "$APKEEP_EMAIL_FILE" ] && [ -f "$APKEEP_TOKEN_FILE" ]; then
            email_opt="-e $(cat "$APKEEP_EMAIL_FILE")"
            token_opt="--auth-token $(cat "$APKEEP_TOKEN_FILE")"
        fi
        
        # Try Google Play first
        if [[ -n "$pkg" && "$pkg" != "$app_name" ]]; then
            if eval apkeep -a \"$pkg\" -d google-play $email_opt $token_opt --accept-tos \"$APPS_DIR\" 2>/dev/null; then
                for downloaded in "$APPS_DIR"/*.apk; do
                    if [[ -f "$downloaded" && "$downloaded" != "$dest" ]]; then
                        mv "$downloaded" "$dest" 2>/dev/null && success=true && break
                    fi
                done
                if $success; then
                    echo "  [OK] $app_name (apkeep/GP)"
                    return 0
                fi
            fi
        fi
        
        # Try APKPure
        if [[ -n "$apkpure" && "$apkpure" != "$app_name" ]]; then
            if apkeep -a "$apkpure" -d apkpure "$APPS_DIR" 2>/dev/null; then
                for downloaded in "$APPS_DIR"/*.apk; do
                    if [[ -f "$downloaded" && "$downloaded" != "$dest" ]]; then
                        mv "$downloaded" "$dest" 2>/dev/null && success=true && break
                    fi
                done
                if $success; then
                    echo "  [OK] $app_name (apkeep/APKPure)"
                    return 0
                fi
            fi
        fi
        
        # Try GitHub
        if [[ -n "$github" && "$github" != "$app_name" ]]; then
            if apkeep -a "$github" -d github "$APPS_DIR" 2>/dev/null; then
                for downloaded in "$APPS_DIR"/*.apk; do
                    if [[ -f "$downloaded" && "$downloaded" != "$dest" ]]; then
                        mv "$downloaded" "$dest" 2>/dev/null && success=true && break
                    fi
                done
                if $success; then
                    echo "  [OK] $app_name (apkeep/GitHub)"
                    return 0
                fi
            fi
        fi
        
        # Try APKMonk
        if [[ -n "$apkmonk" && "$apkmonk" != "$app_name" ]]; then
            if apkeep -a "$apkmonk" -d apkmonk "$APPS_DIR" 2>/dev/null; then
                for downloaded in "$APPS_DIR"/*.apk; do
                    if [[ -f "$downloaded" && "$downloaded" != "$dest" ]]; then
                        mv "$downloaded" "$dest" 2>/dev/null && success=true && break
                    fi
                done
                if $success; then
                    echo "  [OK] $app_name (apkeep/APKMonk)"
                    return 0
                fi
            fi
        fi
    fi
    
    # 2) Fallback: direct URL via curl
    if [[ -n "$direct" && "$direct" == http* ]]; then
        if curl -L -o "$dest" --progress-bar "$direct" 2>/dev/null; then
            echo "  [OK] $app_name (curl/direct)"
            return 0
        fi
    fi
    
    # 3) Fallback: GitHub URL via curl
    if [[ -n "$github" && "$github" == http* ]]; then
        if curl -L -o "$dest" --progress-bar "$github" 2>/dev/null; then
            echo "  [OK] $app_name (curl/GitHub)"
            return 0
        fi
    fi
    
    echo "  [FAIL] $app_name"
    return 1
}

# Display app menu
show_menu() {
    echo ""
    echo "========================================"
    echo " Preinstall Apps for Android TV"
    echo "========================================"
    echo " BSP: $BSP_NAME"
    echo " Target: $APPS_DIR"
    echo "========================================"
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
    for app in AuroraStore VLC TiviMate Xplore SideloadLauncher AptoideTV; do
        if filter_apps "$app"; then
            echo "   $i) $app - ${APPS[$app]##*|}"
            ((i++))
        fi
    done
    echo ""
    echo "   A) Select ALL apps"
    echo "   E) Select ESSENTIAL only"
    echo "   Q) Quit"
    echo ""
}

# Main
setup_apkeep_credentials
show_menu

if [[ -f "$SAVED_CHOICES_FILE" ]]; then
    read -rp "Use saved choices? (y/n): " use_saved
    if [[ "$use_saved" != "y" && "$use_saved" != "Y" ]]; then
        read -rp "Enter choice: " APPS_CHOICES
    else
        APPS_CHOICES=$(cat "$SAVED_CHOICES_FILE")
    fi
else
    read -rp "Enter choice: " APPS_CHOICES
fi

[[ -z "$APPS_CHOICES" ]] && read -rp "Enter choice: " APPS_CHOICES

if [[ "$APPS_CHOICES" == "Q" || "$APPS_CHOICES" == "q" ]]; then
    exit 0
fi

echo "$APPS_CHOICES" > "$SAVED_CHOICES_FILE"

echo ""
echo "Downloading..."
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
        i=1
        for app in SmartTube Kodi Projectivy TVBro LocalSend ButtonMapper Fdroid AdAway AuroraStore VLC TiviMate Xplore SideloadLauncher AptoideTV; do
            if filter_apps "$app"; then
                [[ "$APPS_CHOICES" == *"$i"* ]] && download_app "$app"
                ((i++))
            fi
        done
        ;;
esac

echo ""
echo "Done! Apps in: $APPS_DIR"

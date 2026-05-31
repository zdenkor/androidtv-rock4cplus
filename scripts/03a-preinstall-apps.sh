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
# Supports OAuth token (official) or AUTH token (Aurora Store dispenser)
# See: https://github.com/EFForg/apkeep/blob/master/USAGE-google-play.md

setup_apkeep_credentials() {
    echo ""
    echo "============================================"
    echo " APK Download Source Selection"
    echo "============================================"
    echo ""
    echo "Choose download source:"
    echo "  1) Google Play (official) - requires credentials"
    echo "  2) Alternative stores (APKPure, GitHub, etc.)"
    echo ""
    read -rp "Select (1/2): " SOURCE_CHOICE
    
    case "$SOURCE_CHOICE" in
        1) USE_GOOGLE_PLAY=true; setup_google_credentials ;;
        2) USE_GOOGLE_PLAY=false; echo "Will use alternative sources only." ;;
        *) echo "Invalid selection"; exit 1 ;;
    esac
}

setup_google_credentials() {
    local ini_file="$HOME/.config/apkeep/apkeep.ini"
    mkdir -p "$(dirname "$ini_file")"
    
    echo ""
    echo "============================================"
    echo " Gmail Setup for Google Play"
    echo "============================================"
    echo ""
    echo "Choose authentication method:"
    echo "  1) OAuth token (official method - requires browser)"
    echo "  2) AUTH token (from Aurora Store dispenser)"
    echo ""
    read -rp "Select (1/2): " auth_method
    
    case "$auth_method" in
        1) setup_oauth_credentials "$ini_file" ;;
        2) setup_auth_credentials "$ini_file" ;;
        *) echo "Invalid selection"; return 1 ;;
    esac
}

setup_oauth_credentials() {
    local ini_file="$1"
    echo ""
    echo "OAuth Token Method:"
    echo "  1. Visit https://accounts.google.com/EmbeddedSetup"
    echo "  2. Login with your Gmail"
    echo "  3. Accept ToS if popup appears"
    echo "  4. Open browser dev console (F12) ??? Network tab"
    echo "  5. Find last request to accounts.google.com"
    echo "  6. In Cookies tab, find 'oauth_token' (starts with 'oauth2_4/')"
    echo "  7. Copy the value"
    echo ""
    read -rp "Gmail address: " APKEEP_EMAIL
    echo ""
    read -rsp "OAuth token (starts with 'oauth2_4/'): " OAUTH_TOKEN
    echo ""
    
    if [ -n "$APKEEP_EMAIL" ] && [ -n "$OAUTH_TOKEN" ]; then
        echo "Exchanging OAuth token for AAS token..."
        AAS_TOKEN=$(apkeep -e "$APKEEP_EMAIL" --oauth-token "$OAUTH_TOKEN" 2>/dev/null | tail -1)
        
        if [ -n "$AAS_TOKEN" ]; then
            cat > "$ini_file" << EOF
[google]
email = $APKEEP_EMAIL
aas_token = $AAS_TOKEN
EOF
            chmod 600 "$ini_file"
            echo "Credentials saved to $ini_file"
        else
            echo "Failed to obtain AAS token. Check your OAuth token."
        fi
    fi
}

setup_auth_credentials() {
    local ini_file="$1"
    echo ""
    echo "AUTH Token Method (from Aurora Store):"
    echo "  Get free AUTH token from: https://auroraoss.com/AuroraStore/Download"
    echo "  AUTH tokens start with 'ya29.'"
    echo ""
    read -rp "Gmail address: " APKEEP_EMAIL
    echo ""
    read -rsp "AUTH token (starts with 'ya29.'): " AUTH_TOKEN
    echo ""
    
    if [ -n "$APKEEP_EMAIL" ] && [ -n "$AUTH_TOKEN" ]; then
        cat > "$ini_file" << EOF
[google]
email = $APKEEP_EMAIL
auth_token = $AUTH_TOKEN
EOF
        chmod 600 "$ini_file"
        echo "Credentials saved to $ini_file"
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
APPS["Fdroid"]="org.fdroid.fdroid||||https://f-droid.org/F-Droid.apk|Fdroid.apk|Open source app store"
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
    # Handle empty fields - count pipes to determine position
    local field_count=$(echo "$app_data" | awk -F'|' '{print NF}')
    echo "    DEBUG: fields in app_data=$field_count" >&2
    
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
    echo "    DEBUG: direct='$direct' file='$file' desc='$desc'" >&2
    
    local dest="$APPS_DIR/$file"
    local success=false
    local debug_curl_output=""
    
    echo "  Downloading $app_name..."
    echo "    DEBUG: USE_GOOGLE_PLAY='$USE_GOOGLE_PLAY'" >&2
    echo "    DEBUG: success='$success'" >&2
    
    # Download based on source selection
    if $USE_GOOGLE_PLAY && command -v apkeep &>/dev/null; then
        # Load credentials from ini file
        local ini_file="$HOME/.config/apkeep/apkeep.ini"
        local email_opt=""
        local token_opt=""
        if [ -f "$ini_file" ]; then
            email=$(grep "^email" "$ini_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
            if [ -n "$email" ]; then
                email_opt="-e $email"
            fi
            if grep -q "aas_token" "$ini_file" 2>/dev/null; then
                token_opt="-t $(grep "^aas_token" "$ini_file" | cut -d'=' -f2 | tr -d ' ')"
            elif grep -q "auth_token" "$ini_file" 2>/dev/null; then
                token_opt="--auth-token $(grep "^auth_token" "$ini_file" | cut -d'=' -f2 | tr -d ' ')"
            fi
        fi
        
        # Try Google Play only
        if [[ -n "$pkg" && "$pkg" != "$app_name" ]]; then
            if apkeep -a "$pkg" -d google-play $email_opt $token_opt --accept-tos "$APPS_DIR" 2>/dev/null; then
                for downloaded in "$APPS_DIR"/*.apk; do
                    if [[ -f "$downloaded" && "$downloaded" != "$dest" ]]; then
                        mv "$downloaded" "$dest" 2>/dev/null && success=true && break
                    fi
                done
                if $success; then
                    echo "  [OK] $app_name (Google Play)"
                    return 0
                fi
            fi
        fi
        
        # Google Play failed - ask user if they want alternatives
        echo "  [FAIL] $app_name (Google Play)"
        if [[ "$pkg" != "$app_name" ]]; then
            read -rp "    Try alternatives? (y/n): " try_alt
            if [[ "$try_alt" != "y" && "$try_alt" != "Y" ]]; then
                return 1
            fi
        fi
    fi
    
    # Try alternatives: APKPure, GitHub, APKMonk, direct URLs
    # Try APKPure via apkeep
    if [[ -n "$apkpure" && "$apkpure" != "$app_name" && -z "$success" ]]; then
        if command -v apkeep &>/dev/null && apkeep -a "$apkpure" -d apkpure "$APPS_DIR" 2>/dev/null; then
            for downloaded in "$APPS_DIR"/*.apk; do
                if [[ -f "$downloaded" && "$downloaded" != "$dest" ]]; then
                    mv "$downloaded" "$dest" 2>/dev/null && success=true && break
                fi
            done
            if $success; then
                echo "  [OK] $app_name (APKPure)"
                return 0
            fi
        fi
    fi
    
    # Try GitHub
    if [[ -n "$github" && "$github" != "$app_name" && -z "$success" ]]; then
        if command -v apkeep &>/dev/null && apkeep -a "$github" -d github "$APPS_DIR" 2>/dev/null; then
            for downloaded in "$APPS_DIR"/*.apk; do
                if [[ -f "$downloaded" && "$downloaded" != "$dest" ]]; then
                    mv "$downloaded" "$dest" 2>/dev/null && success=true && break
                fi
            done
            if $success; then
                echo "  [OK] $app_name (GitHub)"
                return 0
            fi
        fi
    fi
    
    # Try APKMonk
    if [[ -n "$apkmonk" && "$apkmonk" != "$app_name" && -z "$success" ]]; then
        if command -v apkeep &>/dev/null && apkeep -a "$apkmonk" -d apkmonk "$APPS_DIR" 2>/dev/null; then
            for downloaded in "$APPS_DIR"/*.apk; do
                if [[ -f "$downloaded" && "$downloaded" != "$dest" ]]; then
                    mv "$downloaded" "$dest" 2>/dev/null && success=true && break
                fi
            done
            if $success; then
                echo "  [OK] $app_name (APKMonk)"
                return 0
            fi
        fi
    fi
    
    # Try direct URL via curl
    echo "    DEBUG: Trying direct URL: $direct" >&2
    if [[ -n "$direct" && "$direct" == http* && -z "$success" ]]; then
        echo "    DEBUG: executing curl -L -o $dest $direct" >&2
        curl -L -o "$dest" "$direct" 2>&1
        local exit_code=$?
        echo "    DEBUG: curl exit code=$exit_code" >&2
        if [[ -f "$dest" && -s "$dest" ]]; then
            echo "  [OK] $app_name (direct)"
            return 0
        else
            echo "    DEBUG: file not created or empty" >&2
        fi
    fi
    
    # Try GitHub URL via curl
    if [[ -n "$github" && "$github" == http* && -z "$success" ]]; then
        if curl -L -o "$dest" --progress-bar "$github" 2>/dev/null; then
            echo "  [OK] $app_name (GitHub curl)"
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

read -rp "Enter choice: " APPS_CHOICES
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

#!/bin/bash
# =============================================================================
# 01-setup-environment.sh
# Sets up the build environment for Android TV (AOSP)
# Supports: Ubuntu 18.04 / 20.04 / 22.04 (on WSL2 or native)
# Target: Radxa ROCK 4C+ (RK3399-T)
# AOSP versions: Android 9 Pie, Android 11, Android 12
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default work directory (USB drive mount point)
WORK_DIR="${WORK_DIR:-/mnt/aosp-build/androidtv-rock4cplus}"

# Optionally load .build-config if it exists (for custom paths)
CONFIG_FILE="$SCRIPT_DIR/../.build-config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "Loaded config: WORK_DIR=$WORK_DIR"
fi

# Check if a repo copy exists on the USB drive
USB_REPO="/mnt/aosp-build/androidtv-rock4cplus-repo"
if [ -d "$USB_REPO" ] && [ "$SCRIPT_DIR" != "$USB_REPO/scripts" ]; then
    echo ""
    echo "NOTE: Repository copy exists on USB drive at:"
    echo "  $USB_REPO"
    echo "Consider running scripts from there instead:"
    echo "  cd $USB_REPO && ./scripts/01-setup-environment.sh"
    echo ""
fi

# Detect distribution
if [ -f /etc/os-release ]; then
    source /etc/os-release
    DISTRO="$ID"
    DISTRO_VERSION="$VERSION_ID"
else
    echo "WARNING: Cannot detect distribution. Assuming Ubuntu."
    DISTRO="unknown"
fi

echo "============================================"
echo " Android TV Build Environment Setup"
echo " Detected: $DISTRO $DISTRO_VERSION"
echo " Target: Radxa ROCK 4C+ (RK3399-T)"
echo "============================================"
echo ""

# =============================================================================
# Choose AOSP version to build
# =============================================================================
echo "Select which Android version you want to build:"
echo ""
echo "  1) Android 9 Pie (Radxa, kernel 4.4)"
echo "     - Best on Ubuntu 18.04 LTS (Python 2 native, JDK 8)"
echo "     - Most stable, all hardware works"
echo ""
echo "  2) Android 11 (Radxa rk11, kernel 4.19) ★ RECOMMENDED"
echo "     - Best on Ubuntu 18.04 LTS (Python 2 native, JDK 8)"
echo "     - Newer kernel, good hardware support"
echo ""
echo "  3) Android 12 (Vicharak BSP, kernel 5.10) EXPERIMENTAL"
echo "     - Best on Ubuntu 22.04 LTS (Python 3, JDK 11)"
echo "     - Full Rockchip BSP included"
echo ""
echo "  4) Android 12 AOSP (pure Google, EXPERIMENTAL)"
echo "     - Best on Ubuntu 22.04 LTS (Python 3, JDK 11)"
echo "     - No Rockchip BSP — manual integration required"
echo ""

# If BSP_CHOICE already set from .build-config, use it; otherwise prompt
if [ -n "$BSP_CHOICE" ] && [ "$BSP_CHOICE" -ge 1 ] 2>/dev/null && [ "$BSP_CHOICE" -le 4 ] 2>/dev/null; then
    AOSP_CHOICE="$BSP_CHOICE"
    echo "Using saved BSP choice: $AOSP_CHOICE"
else
    read -rp "Enter choice [1-4]: " AOSP_CHOICE
    if ! [[ "$AOSP_CHOICE" =~ ^[1-4]$ ]]; then
        echo "Invalid choice. Exiting."
        exit 1
    fi
fi

# Map choice to version name
case $AOSP_CHOICE in
    1) AOSP_VERSION="Android 9 Pie"; AOSP_VER="9" ;;
    2) AOSP_VERSION="Android 11"; AOSP_VER="11" ;;
    3) AOSP_VERSION="Android 12 (Vicharak)"; AOSP_VER="12" ;;
    4) AOSP_VERSION="Android 12 (AOSP)"; AOSP_VER="12" ;;
esac

echo ""
echo "Selected: $AOSP_VERSION"
echo ""

# =============================================================================
# OS recommendation based on AOSP version
# =============================================================================
if [ "$AOSP_VER" = "9" ] || [ "$AOSP_VER" = "11" ]; then
    # Android 9/11 need Python 2 and JDK 8 — Ubuntu 18.04 is ideal
    if [ "$DISTRO" = "ubuntu" ] && [ "$DISTRO_VERSION" != "18.04" ]; then
        echo "============================================"
        echo " NOTE: $AOSP_VERSION builds best on Ubuntu 18.04 LTS"
        echo "============================================"
        echo ""
        echo "You are running $DISTRO $DISTRO_VERSION."
        echo "Android 9/11 use Python 2 scripts and need JDK 8."
        echo "On newer Ubuntu, JDK 8 will be pulled from the bionic repo."
        echo ""
        echo "For best results, install Ubuntu 18.04 in WSL2:"
        echo "  wsl --install -d Ubuntu-18.04"
        echo ""
        read -rp "Continue with $DISTRO $DISTRO_VERSION? [y/N]: " CONFIRM
        if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
            echo "Aborted. Please install Ubuntu 18.04 and try again."
            exit 1
        fi
        echo ""
    fi
else
    # Android 12 needs Python 3 and JDK 11 — Ubuntu 20.04/22.04 is ideal
    :
fi

# Helper: install packages, skipping any that don't exist in the repo
install_safe() {
    local pkg
    for pkg in "$@"; do
        if apt-cache show "$pkg" &>/dev/null; then
            echo "  Installing: $pkg"
            sudo apt-get install -y "$pkg" 2>/dev/null || echo "  (failed, continuing: $pkg)"
        else
            echo "  Not available, skipping: $pkg"
        fi
    done
}

# ---------------------------------------------------------------------------
# 1. Update system
# ---------------------------------------------------------------------------
echo "[1/10] Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# ---------------------------------------------------------------------------
# 2. Install essential build packages
# ---------------------------------------------------------------------------
echo "[2/10] Installing essential packages..."
install_safe \
    git-core gnupg flex bison build-essential zip curl zlib1g-dev \
    gcc-multilib g++-multilib libc6-dev-i386 \
    libx11-dev libgl1-mesa-dev \
    libxml2-utils xsltproc unzip fontconfig python3 python3-pip \
    bc dosfstools mtools rsync

# Distro-specific: x11proto / 32z1 / ncurses / lz4
install_safe x11proto-core-dev lib32z1-dev libncurses5 libncurses5-dev libtinfo5 liblz4-tool

# ---------------------------------------------------------------------------
# 3. Install AOSP-specific build dependencies
# ---------------------------------------------------------------------------
echo "[3/10] Installing AOSP build dependencies..."
install_safe \
    libssl-dev cpio pkg-config lzop \
    libelf-dev bison flex \
    u-boot-tools device-tree-compiler swig \
    python3-dev python3-setuptools

# Android 9/11: also need Python 2 and related packages
if [ "$AOSP_VER" = "9" ] || [ "$AOSP_VER" = "11" ]; then
    echo "[3a/8] Installing Python 2 packages (required for Android $AOSP_VER)..."
    install_safe python python-dev python2 python2-dev python-jinja2 python-markupsafe
    # Ensure 'python' points to python2 (not python3) for Android 9/11
    if command -v python2 &>/dev/null; then
        if ! command -v python &>/dev/null || ! python --version 2>&1 | grep -q "Python 2"; then
            echo "Creating python -> python2 symlink for Android $AOSP_VER..."
            sudo ln -sf /usr/bin/python2 /usr/bin/python
        fi
    fi
else
    # Android 12: ensure 'python' command exists
    if ! command -v python &>/dev/null; then
        echo "Creating python -> python3 symlink..."
        sudo ln -sf /usr/bin/python3 /usr/bin/python
    fi
fi

# ---------------------------------------------------------------------------
# 4. Install Java (version depends on AOSP target)
# ---------------------------------------------------------------------------
if [ "$AOSP_VER" = "9" ] || [ "$AOSP_VER" = "11" ]; then
    # Android 9/11 need OpenJDK 8
    echo "[4/10] Installing OpenJDK 8 (required for Android $AOSP_VER)..."

    # Install aptitude first (better dependency resolver)
    echo "Installing aptitude for better dependency resolution..."
    sudo apt-get install -y aptitude 2>/dev/null || true

    # Fix broken packages first
    echo "Checking for broken packages..."
    sudo apt-get install -f -y 2>/dev/null || true

    if apt-cache show openjdk-8-jdk &>/dev/null; then
        # Available directly (Ubuntu 18.04)
        echo "Installing OpenJDK 8..."
        sudo apt-get install -y openjdk-8-jdk openjdk-8-jre-headless 2>/dev/null || {
            echo "WARNING: OpenJDK 8 install failed. Trying aptitude..."
            sudo aptitude install -y openjdk-8-jdk 2>/dev/null || true
        }
    else
        # Ubuntu 20.04+ — add bionic repo for JDK 8
        echo "Ubuntu $DISTRO_VERSION detected — pulling OpenJDK 8 from bionic repo..."
        echo "deb http://archive.ubuntu.com/ubuntu bionic main universe" | sudo tee /etc/apt/sources.list.d/bionic-jdk8.list
        sudo apt-get update -y
        sudo apt-get install -y openjdk-8-jdk openjdk-8-jre-headless 2>/dev/null || {
            echo "WARNING: OpenJDK 8 not available from bionic. Trying alternative..."
            sudo apt-get install -y openjdk-11-jdk
            echo "NOTE: JDK 11 installed. Android $AOSP_VER may have build issues with JDK 11."
        }
        sudo rm /etc/apt/sources.list.d/bionic-jdk8.list
        sudo apt-get update -y
    fi
else
    # Android 12 needs OpenJDK 11
    echo "[4/10] Installing OpenJDK 11 (required for Android 12)..."

    # Install aptitude first (better dependency resolver)
    echo "Installing aptitude for better dependency resolution..."
    sudo apt-get install -y aptitude 2>/dev/null || true

    # Fix broken packages first
    echo "Checking for broken packages..."
    sudo apt-get install -f -y 2>/dev/null || true

    # Try to install libjpeg8 first (required by openjdk-11-jre on older Ubuntu)
    echo "Attempting to install libjpeg8..."
    sudo apt-get install -y libjpeg8 2>/dev/null || {
        echo "libjpeg8 not available, trying alternative..."
        sudo apt-get install -y libjpeg62-turbo 2>/dev/null || true
    }

    # Use aptitude for better dependency resolution
    if apt-cache show openjdk-11-jdk &>/dev/null; then
        # Available directly (Ubuntu 20.04/22.04)
        echo "Installing OpenJDK 11 using aptitude..."
        sudo aptitude install -y openjdk-11-jdk 2>/dev/null || {
            echo "WARNING: OpenJDK 11 not available. Using OpenJDK 17 instead..."
            sudo apt-get install -y openjdk-17-jdk
        }
    else
        # Ubuntu 24.04+ — try to find any available JDK
        echo "Trying to install OpenJDK 11 from Ubuntu repos..."
        sudo aptitude install -y openjdk-11-jdk 2>/dev/null || {
            echo "WARNING: OpenJDK 11 not found. Using OpenJDK 17 (may cause build issues)..."
            sudo apt-get install -y openjdk-17-jdk
        }
    fi
fi

# Verify Java
java -version 2>&1 | head -3
echo ""

# ---------------------------------------------------------------------------
# 5. Install OpenSSL 3.x (Ubuntu 18.04 only ships 1.1, needed by apkeep)
# Installs to /usr/local/openssl3 — does NOT replace system OpenSSL
# ---------------------------------------------------------------------------
echo "[5/10] Checking OpenSSL..."
OPENSSL3_DIR="/usr/local/openssl3"
if [ -f "$OPENSSL3_DIR/lib64/libssl.so.3" ] || [ -f "$OPENSSL3_DIR/lib/libssl.so.3" ]; then
    echo "  OpenSSL 3.x already installed at $OPENSSL3_DIR"
else
    echo "  Building OpenSSL 3.0 LTS from source..."
    sudo apt-get install -y build-essential checkinstall zlib1g-dev 2>/dev/null || true

    OPENSSL_VER="3.0.15"
    BUILD_DIR="/tmp/openssl-build-$$"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    if ! wget -q "https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz"; then
        echo "  WARNING: Failed to download OpenSSL. Skipping."
    else
        tar xf "openssl-${OPENSSL_VER}.tar.gz"
        cd "openssl-${OPENSSL_VER}"
        ./Configure --prefix="$OPENSSL3_DIR" --openssldir="$OPENSSL3_DIR" shared zlib
        make -j$(nproc)
        sudo make install_sw 2>/dev/null || sudo make install 2>/dev/null || true

        # Add to ldconfig
        if [ -d "$OPENSSL3_DIR/lib64" ]; then
            echo "$OPENSSL3_DIR/lib64" | sudo tee /etc/ld.so.conf.d/openssl3.conf
        elif [ -d "$OPENSSL3_DIR/lib" ]; then
            echo "$OPENSSL3_DIR/lib" | sudo tee /etc/ld.so.conf.d/openssl3.conf
        fi
        sudo ldconfig

        cd /
        rm -rf "$BUILD_DIR"
        echo "  OpenSSL 3.0 installed to $OPENSSL3_DIR"
    fi
fi

# ---------------------------------------------------------------------------
# 6. Install Rust & Cargo (required for apkeep)
# ---------------------------------------------------------------------------
echo "[6/10] Installing Rust & Cargo..."
if ! command -v cargo &>/dev/null; then
    echo "  Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null || {
        echo "  rustup failed, trying apt package..."
        install_safe cargo
    }
    # Source cargo env for this session
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
fi

if command -v cargo &>/dev/null; then
    echo "  cargo installed: $(cargo --version)"
else
    echo "  WARNING: cargo not available. apkeep will use prebuilt binary."
fi

# ---------------------------------------------------------------------------
# 6. Install apkeep (APK downloader for Google Play, APKPure, etc.)
# See: https://github.com/EFForg/apkeep
# Always built from source via cargo to link against system OpenSSL
# (avoids libssl.so version mismatches with prebuilt binaries)
# ---------------------------------------------------------------------------
echo "[7/10] Installing apkeep..."
if command -v cargo &>/dev/null; then
    # Remove any stale prebuilt binary (may be linked against wrong glibc/OpenSSL)
    rm -f ~/.cargo/bin/apkeep 2>/dev/null || true
    echo "  Building apkeep from source with cargo..."
    if cargo install --force --git https://github.com/EFForg/apkeep.git 2>/dev/null; then
        echo "  apkeep installed via cargo"
    else
        echo "  WARNING: apkeep build failed."
        echo "  Apps requiring Google Play download will use alternative sources."
        echo "  To retry manually: cargo install --force --git https://github.com/EFForg/apkeep.git"
    fi
else
    echo "  WARNING: cargo not available — cannot build apkeep."
    echo "  Apps requiring Google Play download will use alternative sources."
    echo "  Install Rust first: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
fi

# ---------------------------------------------------------------------------
# 6. Install Repo tool (Google's git repository manager)
# ---------------------------------------------------------------------------
echo "[8/10] Installing Repo tool..."
mkdir -p ~/bin
curl -sSL https://storage.googleapis.com/git-repo-downloads/repo -o ~/bin/repo
chmod a+x ~/bin/repo

# Add ~/bin to PATH if not already there
if ! grep -q 'export PATH=.*~/bin' ~/.bashrc; then
    echo 'export PATH=~/bin:$PATH' >> ~/.bashrc
fi
export PATH=~/bin:$PATH

# ---------------------------------------------------------------------------
# 7. Configure Git
# ---------------------------------------------------------------------------
echo "[9/10] Configuring Git..."
if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
    echo "Enter your name for Git commits:"
    read -r GIT_NAME
    git config --global user.name "$GIT_NAME"
fi

if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
    echo "Enter your email for Git commits:"
    read -r GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
fi

# ---------------------------------------------------------------------------
# 8. Configure swap (recommended for 16GB RAM systems)
# ---------------------------------------------------------------------------
echo ""
echo "[10/10] Checking swap..."
CURRENT_SWAP=$(free -g | awk '/^Swap:/ {print $2}')
if [ "$CURRENT_SWAP" -lt 16 ]; then
    echo "Current swap: ${CURRENT_SWAP}GB. Recommended: 16GB+"
    echo "To increase swap, run:"
    echo "  sudo fallocate -l 16G /swapfile"
    echo "  sudo chmod 600 /swapfile"
    echo "  sudo mkswap /swapfile"
    echo "  sudo swapon /swapfile"
fi

# ---------------------------------------------------------------------------
# 8. Set up ccache (optional but recommended)
# ---------------------------------------------------------------------------
echo ""
echo "Setting up ccache..."
install_safe ccache
if command -v ccache &>/dev/null; then
    echo 'export USE_CCACHE=1' >> ~/.bashrc
    echo 'export CCACHE_DIR=$HOME/.ccache' >> ~/.bashrc
    ccache -M 50G
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo " Environment setup complete!"
echo "============================================"
echo ""
echo "Target AOSP version: $AOSP_VERSION"
echo ""
echo "Installed tools summary:"
echo "  - wget, curl, git, repo"
echo "  - apkeep (APKMirror / F-Droid downloader)"
if [ "$AOSP_VER" = "9" ] || [ "$AOSP_VER" = "11" ]; then
    echo "  - OpenJDK 8, Python 2, ccache"
else
    echo "  - OpenJDK 11, Python 3, ccache"
fi
echo ""
echo "Next step: Run 02-download-source.sh"
echo ""
echo "IMPORTANT: Restart your terminal or run:"
echo "  source ~/.bashrc"
echo ""

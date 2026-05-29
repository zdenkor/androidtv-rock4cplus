#!/bin/bash
# =============================================================================
# 01-setup-environment.sh
# Sets up the build environment for Android TV 12 (AOSP)
# Supports: Ubuntu 20.04+ / Debian 11+ (on WSL2 or native)
# Target: Radxa ROCK 4C+ (RK3399-T)
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
    echo "WARNING: Cannot detect distribution. Assuming Debian/Ubuntu."
    DISTRO="unknown"
fi

echo "============================================"
echo " Android TV 12 Build Environment Setup"
echo " Detected: $DISTRO $DISTRO_VERSION"
echo " Target: Radxa ROCK 4C+ (RK3399-T)"
echo "============================================"
echo ""

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
echo "[1/8] Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# ---------------------------------------------------------------------------
# 2. Install essential build packages
# ---------------------------------------------------------------------------
echo "[2/8] Installing essential packages..."
install_safe \
    git-core gnupg flex bison build-essential zip curl zlib1g-dev \
    gcc-multilib g++-multilib libc6-dev-i386 \
    libx11-dev libgl1-mesa-dev \
    libxml2-utils xsltproc unzip fontconfig python3 python3-pip \
    bc dosfstools mtools rsync

# Distro-specific: x11proto / 32z1 / ncurses / lz4
if [ "$DISTRO" = "debian" ]; then
    install_safe x11proto-dev lib32z1-dev libncurses-dev libtinfo6 lz4
elif [ "$DISTRO" = "ubuntu" ]; then
    install_safe x11proto-core-dev lib32z1-dev libncurses5 libncurses5-dev libtinfo5 liblz4-tool
else
    install_safe x11proto-core-dev x11proto-dev lib32z1-dev libncurses-dev libncurses5-dev libtinfo6 libtinfo5 lz4 liblz4-tool
fi

# ---------------------------------------------------------------------------
# 3. Install AOSP-specific build dependencies
# ---------------------------------------------------------------------------
echo "[3/8] Installing AOSP build dependencies..."
install_safe \
    libssl-dev cpio pkg-config lzop \
    libelf-dev bison flex \
    u-boot-tools device-tree-compiler swig \
    python3-dev python3-setuptools

# Ensure 'python' command exists (Debian may only have python3)
if ! command -v python &>/dev/null; then
    echo "Creating python -> python3 symlink..."
    sudo ln -sf /usr/bin/python3 /usr/bin/python
fi

# ---------------------------------------------------------------------------
# 4. Install Java (OpenJDK 11 - required for Android 12)
# ---------------------------------------------------------------------------
echo "[4/8] Installing OpenJDK 11..."

if apt-cache show openjdk-11-jdk &>/dev/null; then
    # Available directly (Ubuntu 20.04/22.04, Debian 11)
    sudo apt-get install -y openjdk-11-jdk
elif [ "$DISTRO" = "debian" ]; then
    # Debian 12+ removed OpenJDK 11 — pull from bullseye repo temporarily
    echo "Debian 12+ detected — pulling OpenJDK 11 from bullseye repo..."
    echo "deb http://deb.debian.org/debian bullseye main" | sudo tee /etc/apt/sources.list.d/bullseye-jdk.list
    sudo apt-get update -y
    sudo apt-get install -y openjdk-11-jdk openjdk-11-jre-headless
    sudo rm /etc/apt/sources.list.d/bullseye-jdk.list
    sudo apt-get update -y
elif [ "$DISTRO" = "ubuntu" ]; then
    # Ubuntu 24.04+ — try to find any available JDK
    echo "Trying to install OpenJDK 11 from Ubuntu repos..."
    sudo apt-get install -y openjdk-11-jdk || {
        echo "WARNING: OpenJDK 11 not found. Trying JDK 17 (may cause build issues)..."
        sudo apt-get install -y openjdk-17-jdk
    }
else
    echo "WARNING: Unknown distro. Trying OpenJDK 11, falling back to 17..."
    sudo apt-get install -y openjdk-11-jdk || sudo apt-get install -y openjdk-17-jdk
fi

# Verify Java
java -version
echo ""

# ---------------------------------------------------------------------------
# 5. Install apkeep (APK downloader for APKMirror / F-Droid)
# ---------------------------------------------------------------------------
echo "[5/8] Installing apkeep..."
if ! command -v apkeep &>/dev/null; then
    # Download latest prebuilt binary from GitHub releases
    APKEEP_URL="https://github.com/EFForg/apkeep/releases/latest/download/apkeep-x86_64-unknown-linux-gnu"
    echo "  Downloading apkeep from GitHub releases..."
    if curl -sSL "$APKEEP_URL" -o ~/bin/apkeep 2>/dev/null; then
        chmod +x ~/bin/apkeep
        echo "  apkeep installed to ~/bin/apkeep"
    else
        echo "  WARNING: Could not download apkeep prebuilt binary."
        echo "  You can install it manually later:"
        echo "    cargo install apkeep"
        echo "    or download from https://github.com/EFForg/apkeep/releases"
    fi
else
    echo "  apkeep already installed: $(apkeep --version 2>/dev/null || echo 'version unknown')"
fi

# ---------------------------------------------------------------------------
# 6. Install Repo tool (Google's git repository manager)
# ---------------------------------------------------------------------------
echo "[6/8] Installing Repo tool..."
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
echo "[7/8] Configuring Git..."
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
echo "[8/8] Checking swap..."
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
echo "Installed tools summary:"
echo "  - wget, curl, git, repo"
echo "  - apkeep (APKMirror / F-Droid downloader)"
echo "  - OpenJDK 11, Python 3, ccache"
echo ""
echo "Next step: Run 02-download-source.sh"
echo ""
echo "IMPORTANT: Restart your terminal or run:"
echo "  source ~/.bashrc"
echo ""

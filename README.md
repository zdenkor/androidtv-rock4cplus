# Android TV for Radxa ROCK 4C+

Build **Android TV 12** for the **Radxa ROCK 4C+** (Rockchip RK3399-T) from source using the Vicharak BSP.

> BSP: [Vicharak Android 12](https://github.com/vicharak-in/rockchip-android-manifest) — kernel 5.10, full Rockchip HALs, last updated Dec 2025.

---

## What This Project Does

This repository provides a complete, automated build system for compiling Android TV 12 from AOSP source for the Radxa ROCK 4C+ single-board computer. It includes:

- **Automated scripts** for USB setup, environment preparation, source download, configuration, building, and flashing
- **Prebuilts compatibility fixes** for Debian 13 / WSL2 (Soong sanitization, missing manifests, symlink fixes)
- **Android TV configuration** (Leanback Launcher, HDMI-CEC, IR remote support)
- **Optional GApps integration** (MindTheGapps or NikGApps)
- **Optional preinstalled apps** (SmartTube, Kodi, Projectivy Launcher, etc.)

### Key Components

| Component | Source | Version |
|-----------|--------|---------|
| AOSP | Vicharak BSP | Android 12 |
| Linux Kernel | Rockchip | 5.10 |
| U-Boot | Rockchip | 2023+ |
| GPU (Mali-T860) | ARM | Panfrost / Mali |
| VPU | Rockchip | MPP |

### Android TV Features

- **Leanback Launcher** — TV-optimized home screen
- **Projectivy Launcher** — Alternative clean launcher (preinstalled)
- **HDMI-CEC** — TV remote control support
- **IR Remote** — GPIO IR receiver support
- **Google Play** — Optional via MindTheGapps or NikGApps
- **Widevine L3** — SD streaming on Netflix, Prime Video, etc.

### Preinstalled Apps (Optional)

Run `06-preinstall-apps.sh` to bake apps directly into the system image.

**Essential (recommended):**

| App | Purpose |
|-----|---------|
| **SmartTube** | Ad-free YouTube, 4K HDR, SponsorBlock |
| **Kodi** | Media center (local, Plex, Jellyfin, IPTV) |
| **Projectivy Launcher** | Clean Android TV launcher, no ads |
| **TV Bro** | Web browser optimized for TV remote |
| **LocalSend** | AirDrop-like file sharing (cross-platform) |
| **Button Mapper** | Remap remote control buttons |
| **F-Droid** | Open-source app store |
| **AdAway** | System-wide ad blocker (hosts-based) |

**Additional:**

| App | Purpose |
|-----|---------|
| **Aurora Store** | Anonymous Google Play Store client |
| **VLC** | Universal media player |
| **TiviMate** | IPTV player with EPG guide |
| **X-plore** | File manager with SMB/FTP/cloud |
| **Sideload Launcher** | Show sideloaded apps in TV launcher |
| **Background Apps** | Task killer / free RAM |
| **Aptoide TV** | Alternative app store for Android TV |

### Streaming & DRM

| Service | Max Quality | Method |
|---------|-------------|--------|
| YouTube | **4K HDR** | SmartTube (no DRM needed) |
| Netflix | 480p SD | Widevine L3 (built-in) |
| Prime Video | 480p SD | Widevine L3 |
| Local media | **4K HDR** | Kodi / VLC / Plex / Jellyfin |
| IPTV | Any | TiviMate / Kodi |

> **Widevine L1** (HD/4K Netflix) requires Google certification — not possible on DIY boards.

---

## Prerequisites

### Hardware Requirements
- **CPU**: 8+ cores recommended
- **RAM**: 32GB+ (16GB minimum with swap)
- **Disk**: 300GB+ free space — **USB 3.0 external drive strongly recommended**
- **OS**: Ubuntu 20.04+ or Debian 11+ (via WSL2 or native)

### Why Use a USB Drive?
AOSP source + build output requires **300GB+**. An external USB 3.0 SSD/HDD formatted as **ext4** is required — NTFS/exFAT will corrupt the source tree (AOSP needs case-sensitive filesystem).

### WSL2 + USB Drive Setup (Windows)
If you are on Windows, use WSL2 with a USB drive:
```powershell
# In PowerShell (Admin):
wsl --install -d Debian          # or Ubuntu-20.04
wsl --set-default-version 2

# Attach USB drive to WSL2:
usbipd list                      # Find your USB drive BUSID
usbipd bind --busid <BUSID>      # Share the device
usbipd attach --wsl --busid <BUSID> # Attach to WSL
```

Configure WSL2 memory in `%USERPROFILE%\.wslconfig`:
```ini
[wsl2]
memory=24GB
processors=8
swap=32GB
```

### Native Linux (Debian/Ubuntu)
If you are on native Linux, simply plug in your USB drive and skip the WSL2 steps above.

---

## Clone This Repository

Before you clone, you need a USB drive formatted as **ext4** (see [USB Drive Setup](#usb-drive-setup-detailed) below). The setup scripts use `/mnt/aosp-build` as the default mount point.

Choose one of the following options based on your setup.

### Option 1: Clone to your home directory (simplest)
Clone the repo to `~/projects`. The `00-setup-usb.sh` script will later copy everything to the USB drive for you.
```bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/zdenkor/androidtv-rock4cplus.git
cd androidtv-rock4cplus
```

### Option 2: Clone directly onto the USB drive
Use this only if you **already formatted your USB drive as ext4** and mounted it (for example at `/mnt/aosp-build`):
```bash
cd /mnt/aosp-build
git clone https://github.com/zdenkor/androidtv-rock4cplus.git
cd androidtv-rock4cplus
```

> **Note:** If your USB drive is not yet formatted, use Option 1 and run `./scripts/00-setup-usb.sh` next. That script will format, mount, and copy the repo to the USB drive automatically.

---

## Quick Start

All scripts are designed to run inside **WSL2 or native Debian/Ubuntu**.

```bash
chmod +x scripts/*.sh
./scripts/00-setup-usb.sh         # Format USB, mount it, copy repo to USB
./scripts/01-setup-environment.sh # Install dependencies
./scripts/02-download-source.sh   # Download AOSP + Rockchip BSP (~80GB)
./scripts/03-configure-build.sh   # Configure device, TV, apply prebuilts fixes
./scripts/06-preinstall-apps.sh   # Optional: preinstall apps
./scripts/04-build-android.sh     # Build Android TV (4-8 hours)
./scripts/05-flash-device.sh    # Flash to ROCK 4C+
```

After `00-setup-usb.sh`, you can continue from the USB copy to avoid cross-filesystem issues:
```bash
cd /mnt/aosp-build/androidtv-rock4cplus-repo
./scripts/01-setup-environment.sh
# ... continue with remaining steps
```

| Step | Script | Description |
|------|--------|-------------|
| 0 | `./scripts/00-setup-usb.sh` | Format & mount USB drive as ext4, copy repo to USB |
| 1 | `./scripts/01-setup-environment.sh` | Install build dependencies & JDK 11 |
| 2 | `./scripts/02-download-source.sh` | Download AOSP + Rockchip BSP (~80GB) |
| 3 | `./scripts/03-configure-build.sh` | Configure for ROCK 4C+, Android TV, and **auto-apply prebuilts fixes** |
| 3b | `./scripts/06-preinstall-apps.sh` | (Optional) Preinstall apps into build |
| 4 | `./scripts/04-build-android.sh` | Build Android TV (4-8 hours) |
| 5 | `./scripts/05-flash-device.sh` | Flash to ROCK 4C+ |

---

## Project Structure

```
AndroidTV for Radxa4C+/
├── README.md
├── .build-config                    # Generated: USB mount & work dir paths
├── .gitignore
├── scripts/
│   ├── 00-setup-usb.sh              # Format & mount USB drive (ext4)
│   ├── 01-setup-environment.sh      # Install dependencies & tools
│   ├── 02-download-source.sh        # Download AOSP + Rockchip BSP
│   ├── 03-configure-build.sh        # Configure device, kernel, TV, GApps
│   ├── 04-build-android.sh          # Build the image
│   ├── 05-flash-device.sh           # Flash to device
│   └── 06-preinstall-apps.sh        # Download & integrate apps
├── patches/
│   └── rk3399-rock-4c-plus.dts      # ROCK 4C+ device tree (RK3399-T)
├── configs/
│   └── BoardConfig.mk               # Board configuration reference
└── docs/
    ├── device-tree.md               # Device tree reference
    ├── kernel-config.md             # Kernel configuration
    └── troubleshooting.md           # Common issues & fixes
```

---

## USB Drive Setup (Detailed)

### Why ext4?
AOSP source code contains files that differ only in case (e.g., `Makefile` vs `makefile`). NTFS and exFAT are case-insensitive and will corrupt the source tree. **ext4 is mandatory.**

### Automatic Setup (Recommended)
Run the provided script and follow the prompts:
```bash
cd ~/projects/androidtv-rock4cplus   # or wherever you cloned the repo
chmod +x scripts/*.sh
./scripts/00-setup-usb.sh
```

The script will:
1. List all available drives
2. Ask you to select the USB drive (e.g., `sdb`)
3. **WARNING: Erase all data** and format as ext4
4. Mount at `/mnt/aosp-build`
5. Add to `/etc/fstab` for auto-mount
6. Copy this repository to the USB drive
7. Create `.build-config` with the work directory path

### Manual Setup (If you prefer to format yourself)
If you want to format the USB drive manually before cloning:

```bash
# 1. Identify your USB drive (do NOT use your system drive!)
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

# 2. Unmount any existing partitions (replace sdb with your device)
sudo umount /dev/sdb* 2>/dev/null || true

# 3. Create a single ext4 partition
sudo parted -s /dev/sdb mklabel gpt
sudo parted -s /dev/sdb mkpart primary ext4 0% 100%

# 4. Format as ext4
sudo mkfs.ext4 -F -L AOSP_BUILD /dev/sdb1

# 5. Mount it
sudo mkdir -p /mnt/aosp-build
sudo mount /dev/sdb1 /mnt/aosp-build
sudo chown -R "$USER:$USER" /mnt/aosp-build

# 6. Add to fstab for auto-mount
UUID=$(sudo blkid -s UUID -o value /dev/sdb1)
echo "UUID=$UUID /mnt/aosp-build ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
```

After manual setup, you can clone directly onto the USB drive:
```bash
cd /mnt/aosp-build
git clone https://github.com/zdenkor/androidtv-rock4cplus.git
cd androidtv-rock4cplus
```

### After Setup
All source code will be stored at `/mnt/aosp-build/androidtv-rock4cplus/` on your USB drive. The `.build-config` file is automatically read by all other scripts.

### Manual Mount (if needed)
```bash
sudo mount /mnt/aosp-build
```

---

## Important Notes

1. **RK3399-T vs RK3399**: The ROCK 4C+ uses RK3399-T (lower-clocked). The device tree in `patches/` includes the correct OPP table (A72 @ 1.5GHz, A53 @ 1.0GHz).

2. **Build Time**: First build takes 4-8 hours. Subsequent builds are faster (incremental).

3. **Disk Space**: The source tree is ~80GB, build output adds ~50GB. Total: ~130GB minimum.

4. **Known Limitations**:
   - Widevine L3 only (no HD Netflix/Prime)
   - HDMI audio may need per-TV tuning
   - Wi-Fi firmware may need manual placement

---

## References

- [Radxa ROCK 4C+ Wiki](https://wiki.radxa.com/Rock4/4cplus)
- [Vicharak Android 12 BSP](https://github.com/vicharak-in/rockchip-android-manifest)
- [Advantech RK3399 Android 12 Guide](https://ess-wiki.advantech.com.tw/view/Android_BSP_User_Guide_for_rk3399_series_12.0)
- [AOSP Source](https://source.android.com/)
- [RK3399 TRM](https://opensource.rock-chips.com/wiki_RK3399)

# Android TV for Radxa ROCK 4C+

Build **Android TV 12** for the **Radxa ROCK 4C+** (Rockchip RK3399-T) from source using the Vicharak BSP.

> BSP: [Vicharak Android 12](https://github.com/vicharak-in/rockchip-android-manifest) — kernel 5.10, full Rockchip HALs, last updated Dec 2025.

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

---

## Quick Start

| Step | Script | Description |
|------|--------|-------------|
| 0 | `./scripts/00-setup-usb.sh` | Format & mount USB drive as ext4 |
| 1 | `./scripts/01-setup-environment.sh` | Install build dependencies & JDK 11 |
| 2 | `./scripts/02-download-source.sh` | Download AOSP + Rockchip BSP (~80GB) |
| 3 | `./scripts/03-configure-build.sh` | Configure for ROCK 4C+ & Android TV |
| 3b | `./scripts/06-preinstall-apps.sh` | (Optional) Preinstall apps into build |
| 4 | `./scripts/04-build-android.sh` | Build Android TV (4-8 hours) |
| 5 | `./scripts/05-flash-device.sh` | Flash to ROCK 4C+ |

```bash
chmod +x scripts/*.sh
./scripts/00-setup-usb.sh
./scripts/01-setup-environment.sh
./scripts/02-download-source.sh
./scripts/03-configure-build.sh
./scripts/06-preinstall-apps.sh   # optional
./scripts/04-build-android.sh
./scripts/05-flash-device.sh
```

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

### Step-by-Step

1. **Plug in your USB 3.0 drive** (SSD recommended for speed, 256GB+ minimum)

2. **In WSL2**, attach the USB drive:
   ```bash
   # From PowerShell (Admin), list USB devices:
   usbipd list

   # Share and attach the drive (replace <BUSID> with your drive's BUSID):
   usbipd bind --busid <BUSID>
   usbipd attach --wsl --busid <BUSID>
   ```

3. **In WSL2 terminal**, run the setup script:
   ```bash
   cd /mnt/c/Temp/AndroidTV\ for\ Radxa4C+/
   chmod +x scripts/00-setup-usb.sh
   ./scripts/00-setup-usb.sh
   ```

4. The script will:
   - List all available drives
   - Ask you to select the USB drive (e.g., `sdb`)
   - **WARNING: Erase all data** and format as ext4
   - Mount at `/mnt/aosp-build`
   - Add to `/etc/fstab` for auto-mount
   - Create `.build-config` with the work directory path

### After Setup
All source code will be stored at `/mnt/aosp-build/androidtv-rock4cplus/` on your USB drive. The `.build-config` file is automatically read by all other scripts.

### Manual Mount (if needed)
```bash
sudo mount /mnt/aosp-build
```

---

## Key Components

| Component | Source | Version |
|-----------|--------|---------|
| AOSP | Vicharak BSP | Android 12 |
| Linux Kernel | Rockchip | 5.10 |
| U-Boot | Rockchip | 2023+ |
| GPU (Mali-T860) | ARM | Panfrost / Mali |
| VPU | Rockchip | MPP |

---

## Android TV Features

This build is configured as Android TV with:

- **Leanback Launcher** — TV-optimized home screen
- **Projectivy Launcher** — Alternative clean launcher (preinstalled)
- **HDMI-CEC** — TV remote control support
- **IR Remote** — GPIO IR receiver support
- **Google Play** — Optional via MindTheGapps or NikGApps
- **Widevine L3** — SD streaming on Netflix, Prime Video, etc.

---

## Preinstalled Apps

Run `06-preinstall-apps.sh` to bake apps directly into the system image.

### Essential (recommended)
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

### Additional
| App | Purpose |
|-----|---------|
| **Aurora Store** | Anonymous Google Play Store client |
| **VLC** | Universal media player |
| **TiviMate** | IPTV player with EPG guide |
| **X-plore** | File manager with SMB/FTP/cloud |
| **Sideload Launcher** | Show sideloaded apps in TV launcher |
| **Background Apps** | Task killer / free RAM |
| **Aptoide TV** | Alternative app store for Android TV |

---

## Streaming & DRM

| Service | Max Quality | Method |
|---------|-------------|--------|
| YouTube | **4K HDR** | SmartTube (no DRM needed) |
| Netflix | 480p SD | Widevine L3 (built-in) |
| Prime Video | 480p SD | Widevine L3 |
| Local media | **4K HDR** | Kodi / VLC / Plex / Jellyfin |
| IPTV | Any | TiviMate / Kodi |

> **Widevine L1** (HD/4K Netflix) requires Google certification — not possible on DIY boards.

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

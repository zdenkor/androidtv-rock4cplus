# Troubleshooting Guide

## Repo Sync Errors

### prebuilts/sdk Fails (Corrupted AOSP Mirror)

**Symptoms**: `remote: error: Could not read ...` or `repository corruption on the remote side` on `platform/prebuilts/sdk`.

**Cause**: The AOSP mirror used by the manifest has a corrupted object. This is server-side.

**Solutions**:
```bash
cd /mnt/aosp-build/androidtv-rock4cplus

# Clone directly from Google's official source
rm -rf prebuilts/sdk
mkdir -p prebuilts
git clone --depth=1 https://android.googlesource.com/platform/prebuilts/sdk prebuilts/sdk

# Or use Tsinghua mirror (faster in Asia)
git clone --depth=1 https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/platform/prebuilts/sdk prebuilts/sdk

# Then resume sync
repo sync -j4 --no-clone-bundle
```

### GitLab Rate Limit

**Symptoms**: `Rate limit exceeded` from gitlab.com.

**Solutions**:
```bash
# Reduce parallelism
repo sync -j2 --no-clone-bundle

# Or single-threaded
repo sync -j1 --no-clone-bundle
```

---

## Debian-Specific Issues

### Missing `python` Command

**Symptoms**: `python: command not found` during build.

**Solutions**:
```bash
# Debian only ships python3 by default
sudo apt-get install -y python-is-python3
# Or create a symlink:
sudo ln -s /usr/bin/python3 /usr/bin/python
```

### Missing `libtinfo5` (Debian 12+)

**Symptoms**: `cannot find -ltinfo` or `libtinfo.so.5: cannot open`.

**Solutions**:
```bash
# Debian 12+ uses libtinfo6; some AOSP tools need libtinfo5
# Install from Debian 11 (bullseye) repo temporarily:
echo "deb http://deb.debian.org/debian bullseye main" | sudo tee /etc/apt/sources.list.d/bullseye.list
sudo apt-get update
sudo apt-get install -y libtinfo5 libncurses5
sudo rm /etc/apt/sources.list.d/bullseye.list
sudo apt-get update
```

### `python3-distutils` Not Found

**Symptoms**: `ModuleNotFoundError: No module named 'distutils'`.

**Solutions**:
```bash
sudo apt-get install -y python3-distutils python3-setuptools
```

---

## USB Drive Issues

### USB Drive Not Visible in WSL2

**Symptoms**: `lsblk` doesn't show the USB drive.

**Solutions**:
```powershell
# In PowerShell (Admin):
# List USB devices
usbipd list

# Share and attach to WSL (replace <BUSID>)
usbipd bind --busid <BUSID>
usbipd attach --wsl --busid <BUSID>

# If usbipd not installed:
winget install --interactive --exact dorssel.usbipd-win
```

### USB Drive Detaches After Reboot

**Symptoms**: Drive not mounted after WSL2 restart.

**Solutions**:
```bash
# Re-attach from PowerShell first, then mount:
sudo mount /mnt/aosp-build

# Or re-run the setup script (won't format if already ext4):
./scripts/00-setup-usb.sh
```

### Case-Sensitivity Errors

**Symptoms**: Build fails with "file not found" for files that exist.

**Cause**: Building on NTFS/exFAT instead of ext4.

**Solutions**:
```bash
# Check filesystem type
df -T /mnt/aosp-build

# Must show "ext4". If not, re-run:
./scripts/00-setup-usb.sh
```

### USB Drive Too Slow

**Symptoms**: Build takes excessively long.

**Solutions**:
- Use USB 3.0 port (blue) — USB 2.0 is too slow
- Use an SSD instead of HDD
- Use `mount -o noatime` for better performance
- Consider using an NVMe enclosure via USB-C

### Permission Denied on USB Drive

**Symptoms**: `Permission denied` when writing to `/mnt/aosp-build`.

**Solutions**:
```bash
# Fix ownership
sudo chown -R $USER:$USER /mnt/aosp-build

# Or remount with proper options
sudo mount -o remount,uid=$(id -u),gid=$(id -g) /mnt/aosp-build
```

---

## Common Build Issues

### 1. Out of Memory (OOM) During Build

**Symptoms**: Build fails with `Killed` or `Out of memory` errors.

**Solutions**:
```bash
# Increase swap
sudo fallocate -l 32G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Reduce parallel jobs
export JACK_SERVER_VM_ARGUMENTS="-Xmx4g"
make -j4  # Use fewer cores
```

### 2. Jack Server Issues

**Symptoms**: `Jack server failed to start` or `Communication error with Jack server`.

**Solutions**:
```bash
# Kill and restart Jack server
jack-admin kill-server
jack-admin start-server

# Or disable Jack entirely (Android 12 uses R8/D8)
export ANDROID_COMPILE_WITH_JACK=false
```

### 3. Missing Dependencies

**Symptoms**: `command not found: xxx` or `cannot find -lxxx`.

**Solutions**:
```bash
# Re-run the environment setup
./scripts/01-setup-environment.sh

# Common missing packages
sudo apt-get install -y \
    libssl-dev libncurses5-dev libelf-dev \
    bison flex device-tree-compiler
```

### 4. Python Version Issues

#### Python 2 print syntax error (Android 9)

**Symptoms**:
```
File "libcore/annotations/generate_annotated_java_files.py", line 34
    print '// Do not edit; ...'
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^
SyntaxError: Missing parentheses in call to 'print'. Did you mean print(...)?
```

**Cause**: Android 9 uses Python 2 scripts. Build on Ubuntu 18.04 LTS which has Python 2 native, or ensure `python` points to Python 2.

**Solution**: Run `01-setup-environment.sh` which installs Python 2 and symlinks `python → python2` for Android 9/11 builds.

#### General Python Version Issues

**Symptoms**: Other Python-related errors during build.

**Solutions**:
```bash
# Android 12 requires Python 3
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1
python --version  # Should show Python 3.x
```

### 5. Disk Space Issues

**Symptoms**: `No space left on device`.

**Solutions**:
```bash
# Check disk usage
df -h

# Clean build artifacts
cd ~/androidtv-rock4cplus
make clean

# Remove old builds
rm -rf out/

# Need at least 200GB free
```

### 6. Device Tree Compilation Errors

#### dtc-lexer.l: duplicate 'extern' error (GCC 10+)

**Symptoms**:
```
dtc-lexer.l:41:1: error: duplicate 'extern'
dtc-lexer.l:41:1: error: duplicate 'extern'
make[2]: *** [scripts/Makefile.host:108: scripts/dtc/dtc-lexer.lex.o] Error 1
```

**Cause**: GCC 10+ treats duplicate `extern` declarations as errors. The `dtc-lexer.l` file declares `YYLTYPE yylloc;` but `dtc-parser.tab.h` already has `extern YYLTYPE yylloc;`, causing a conflict.

**Solution**: The build script (`04-build-android.sh`) now automatically removes the redundant `YYLTYPE yylloc` declaration from both `dtc-lexer.l` and `dtc-lexer.lex.c`. If you're building manually:

```bash
cd kernel/scripts/dtc
# Remove the yylloc declaration (already declared in dtc-parser.tab.h)
sed -i '/YYLTYPE yylloc/d' dtc-lexer.l
sed -i '/YYLTYPE yylloc/d' dtc-lexer.lex.c
# Clean and rebuild
make -C /path/to/kernel ARCH=arm64 clean
```

#### General DTC Errors

**Symptoms**: Other DTC errors during kernel build.

**Solutions**:
```bash
# Check DTC version
dtc --version  # Should be >= 1.4.7

# Update DTC
sudo apt-get install --reinstall device-tree-compiler
```

### 7. Wi-Fi/Bluetooth Not Working

**Symptoms**: No Wi-Fi or Bluetooth after boot.

**Solutions**:
```bash
# Check firmware files exist
ls vendor/etc/firmware/fw_bcm43456c5_ag.bin
ls vendor/etc/firmware/nvram_ap6256.txt

# If missing, download from Radxa
git clone https://github.com/radxa/firmware.git
cp firmware/brcm/* vendor/etc/firmware/
```

### 8. HDMI No Output

**Symptoms**: Black screen on HDMI.

**Solutions**:
```bash
# Check HDMI connection
cat /sys/class/drm/card0-HDMI-A-1/status

# Force HDMI output in kernel command line
# Add to device tree:
# video=HDMI-A-1:1920x1080@60
```

### 9. eMMC Not Detected

**Symptoms**: Device doesn't boot from eMMC.

**Solutions**:
```bash
# Check if eMMC is detected in U-Boot
mmc list
mmc info

# Re-flash U-Boot to eMMC
rkdeveloptool db MiniLoaderAll.bin
rkdeveloptool ul MiniLoaderAll.bin
rkdeveloptool wl 0x40 idbloader.img
rkdeveloptool wl 0x4000 u-boot.itb
```

## Device-Specific Issues

### ROCK 4C+ Not Entering MaskROM Mode

1. Ensure USB-C cable supports data (not power-only)
2. Try different USB ports
3. Check with `lsusb` - should show `2207:330c` (Rockchip device)
4. Try shorting eMMC CLK to GND (pins on the eMMC module)

### Boot Loop

1. Check serial console output (115200 baud)
2. Verify `parameter.txt` partition layout
3. Try booting from SD card first
4. Check power supply (needs 5V/3A via USB-C)

## Getting Help

- [Radxa Community Forum](https://forum.radxa.com/)
- [Rockchip Linux IRC](https://opensource.rock-chips.com/wiki_IRC)
- [AOSP Building Help](https://source.android.com/docs/setup/build/building)

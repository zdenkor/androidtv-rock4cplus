# Prebuilt Bootloader Images (Fast Path)

This directory contains a **known-good** Rockchip boot chain extracted from
the official Radxa Android 11 reference image. The SD card flash script
(`scripts/05-flash-device.sh`) prefers these files over anything produced by
your own U-Boot build, so if your build is broken at the bootloader level you
can still produce a booting SD card.

## What's in here

| File | Size | Source | Purpose |
|------|------|--------|---------|
| `idbloader.img` | 230 KB | GPT image, LBA 64 | DDR init + miniloader (Rockchip BootROM entry point) |
| `uboot.img` | 4 MB | GPT image, LBA 16384 (`0x4000`) | U-Boot proper |
| `trust.img` | 4 MB | GPT image, LBA 24576 (`0x6000`) | ARM Trusted Firmware (BL31/BL32) |
| `dtbo.img` | 622 B | GPT image | Device Tree overlay (trimmed) |
| `vbmeta.img` | 141 B | GPT image | AVB verification metadata (disabled) |

**Total: ~8.6 MB.** Small enough to commit to git. The full reference image
(4.3 GB) is NOT included.

## Source

Extracted from:

```
C:\Temp\rock4cplus-gpt\Rock4CPlus-Android11-r12-20241202-gpt\
  Rock4CPlus-Android11-r12-20241202-gpt.img
```

- Vendor: **Radxa**
- Image: `Rock4CPlus-Android11-r12-20241202-gpt`
- Released: **2024-12-02**
- Hardware: Radxa ROCK 4C+ (RK3399-T, LPDDR4)

This image boots cleanly on the ROCK 4C+, so its boot chain is a safe
fallback.

## How it's used by the flash script

`scripts/05-flash-device.sh` looks for the bootloader files in this order
when flashing to SD card:

1. **`prebuilt/`** (this directory) — known-good Radxa reference
2. Rockchip build output in `rockdev/` or `out/target/product/rk3399*/`
3. rkbin prebuilts assembled via `loaderimage` (fallback)

To force the flash script to use only your own U-Boot build (skip these
prebuilts), just rename or move this directory aside before flashing.

## When NOT to use these

These bootloader images are tied to the **RK3399-T** silicon and **LPDDR4**
RAM on the ROCK 4C+. Do not use them on:

- Original RK3399 boards (different DDR init)
- Boards with DDR3 instead of LPDDR4
- Vicharak Android 12 builds that use a different kernel/DTB pair — the
  `idbloader` DDR timing must match the kernel's memory map, and mixing
  a Radxa 4.19 idbloader with a Vicharak 5.10 kernel usually works for
  DDR init but the device tree compiled into the kernel still has to
  describe the same board.

The Android partition images (`system.img`, `vendor.img`, `boot.img`)
from the reference image are **NOT** in this directory. Mixing the
reference `boot.img` (Radxa kernel 4.19) with a Vicharak-built
`system.img` (kernel 5.10) will cause boot loops because the kernel
version has to match what `boot.img` expects. If you need the reference
Android system itself, flash the full `Rock4CPlus-Android11-r12-20241202-gpt.img`
via `dd` to the SD card directly instead of using the build system.

## Regenerating

To re-extract these files from the reference image (or a similar one):

```bash
# From the project root, assuming the reference img is at
# C:/Temp/rock4cplus-gpt/Rock4CPlus-Android11-r12-20241202-gpt/
#  Rock4CPlus-Android11-r12-20241202-gpt.img

python3 - <<'EOF'
import os
src = r"C:/Temp/rock4cplus-gpt/Rock4CPlus-Android11-r12-20241202-gpt/Rock4CPlus-Android11-r12-20241202-gpt.img"
dst = "prebuilt"

# Partition LBAs (sector size 512)
parts = {
    "idbloader.img": (64, 64 + 1024),       # read up to 512 KB, trim trailing zeros
    "uboot.img":     (16384, 16384 + 8192), # 4 MB
    "trust.img":     (24576, 24576 + 8192), # 4 MB
    "dtbo.img":      (32768, 32768 + 8192), # 4 MB partition, dtbo is small
    "vbmeta.img":    (49152, 49152 + 2048), # 1 MB partition
}

with open(src, "rb") as f:
    for name, (start_lba, end_lba) in parts.items():
        f.seek(start_lba * 512)
        data = f.read((end_lba - start_lba) * 512)
        # trim trailing zeros
        end = len(data)
        while end > 0 and data[end-1] == 0:
            end -= 1
        # round up to sector
        padded = ((end + 511) // 512) * 512
        out = data[:padded] + b"\x00" * (padded - end)
        with open(os.path.join(dst, name), "wb") as o:
            o.write(out)
        print(f"{name}: {padded} bytes")
EOF
```

Verify the magic bytes match before trusting the result:

```bash
xxd prebuilt/idbloader.img | head -1   # should NOT be all zeros in the first 64 bytes
xxd prebuilt/uboot.img | head -1       # first 8 bytes: "LOADER  " or U-Boot SPL marker
xxd prebuilt/trust.img | head -1       # first 4 bytes: "BL3X" (ATF)
```

# rk3399-rock-4c-plus.dts.broken

This hand-rolled DTS was REMOVED because it caused a silent boot hang
(no blue LED, no logcat, board appears dead).

## What went wrong

The DTS was missing three nodes that AOSP 11 init REQUIRES:

  firmware { android { fstab, vbmeta } }  -- init reads this at boot
  aliases { mmc0, mmc1, serial0... }      -- udev needs for /dev/block/by-name/
  ddr_timing                              -- kernel dmc driver

The stock Radxa rk3399-rock-pi-4.dts (included in the kernel source) has
all three. The build script (04-build-android.sh line 473-476) already
has a fallback: when patches/rk3399-rock-4c-plus.dts is missing, it
copies the kernel's own rock-pi-4.dts as the 4c-plus file.

## The OPP table difference is harmless

The only thing our custom DTS added over the stock rock-pi-4 was the
RK3399-T OPP table (A72@1.5GHz vs 1.8GHz). The board boots fine at
the slightly wrong frequency — it's cosmetic, not a boot-killer.

## If you ever need the custom DTS back

It lives here as .broken for reference. Before reviving it, compare
against extracted-from-gpt/dtbs/stock-rock-4c-plus.dts (decompiled
from the vendor's working boot.img) and ensure ALL of these are present:

1. firmware -> android -> fstab + vbmeta
2. aliases (all of them)
3. ddr_timing (with real values, not placeholders)
4. reserved-memory -> ramoops, drm-logo (even if status=disabled)

The pure-Python DTB decompile recipe is at:
sd-card-boot-verify skill -> references/fdt-extract-decompile.md

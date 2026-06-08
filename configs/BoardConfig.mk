# Android TV 12 Build Configuration for Radxa ROCK 4C+
# Place this in: device/rockchip/rk3399/BoardConfig.mk

# ============================================================================
# Platform
# ============================================================================
TARGET_BOARD_PLATFORM := rk3399
TARGET_BOARD_PLATFORM_GPU := mali-t860
TARGET_BOARD_HARDWARE := rk30board
TARGET_BOARD_PLATFORM_PRODUCT := box

# ============================================================================
# Architecture
# ============================================================================
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53
TARGET_CPU_SMP := true

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53

# ============================================================================
# Kernel
# ============================================================================
BOARD_KERNEL_CMDLINE := console=ttyFIQ0,1500000 androidboot.hardware=rk30board androidboot.console=ttyFIQ0 androidboot.selinux=permissive init=/init rootwait earlycon=uart8250,mmio32,0xff1a0000 swiotlb=1 coherent_pool=1m cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory loop.max_part=7
BOARD_KERNEL_BASE := 0x00200000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_OFFSET := 0x00080000
BOARD_RAMDISK_OFFSET := 0x04000000
BOARD_SECOND_OFFSET := 0x00f00000
BOARD_TAGS_OFFSET := 0x0e880000

TARGET_PREBUILT_KERNEL := kernel/arch/arm64/boot/Image
TARGET_PREBUILT_DTB := kernel/arch/arm64/boot/dts/rockchip/rk3399-rock-4c-plus.dtb

# ============================================================================
# Partitions
# ============================================================================
BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2147483648
BOARD_VENDORIMAGE_PARTITION_SIZE := 536870912
BOARD_OEMIMAGE_PARTITION_SIZE := 268435456
BOARD_USERDATAIMAGE_PARTITION_SIZE := 4294967296  # 4GB baseline (grows to fill SD card via parameter.txt :grow flag)
BOARD_CACHEIMAGE_PARTITION_SIZE := 268435456
BOARD_METADATAIMAGE_PARTITION_SIZE := 16777216

BOARD_FLASH_BLOCK_SIZE := 4096
BOARD_ROOT_EXTRA_FOLDERS := metadata

# ============================================================================
# File Systems
# ============================================================================
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4

# ============================================================================
# Graphics
# ============================================================================
TARGET_USES_HWC2 := true
TARGET_BOARD_PLATFORM_GPU := mali-t860
BOARD_GPU_DRIVERS := mali-t860

# ============================================================================
# Android TV
# ============================================================================
PRODUCT_CHARACTERISTICS := tv
TARGET_HAS_LEANBACK := true

# ============================================================================
# Wi-Fi / Bluetooth
# ============================================================================
BOARD_WLAN_DEVICE := bcmdhd
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_bcmdhd
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_bcmdhd

# ============================================================================
# Audio
# ============================================================================
BOARD_USES_ALSA_AUDIO := true
BOARD_USES_GENERIC_AUDIO := true

# ============================================================================
# Camera (optional for TV)
# ============================================================================
# BOARD_CAMERA_SUPPORT := false

# ============================================================================
# DRM / Widevine
# ============================================================================
BOARD_WIDEVINE_OEMCRYPTO_LEVEL := 3

# ============================================================================
# SELinux
# ============================================================================
BOARD_SEPOLICY_DIRS += device/rockchip/common/sepolicy

# ============================================================================
# AVB (Android Verified Boot)
# ============================================================================
BOARD_AVB_ENABLE := true
BOARD_AVB_ROLLBACK_INDEX := 0

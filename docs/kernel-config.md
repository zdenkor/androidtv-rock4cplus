# Kernel Configuration for Android TV on ROCK 4C+

## Required Kernel Features for Android TV

### 1. Android Binder & Ashmem
```
CONFIG_ANDROID=y
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
CONFIG_ASHMEM=y
```

### 2. HDMI-CEC (Consumer Electronics Control)
```
CONFIG_DRM_DW_HDMI=y
CONFIG_DRM_DW_HDMI_CEC=y
CONFIG_MEDIA_CEC_SUPPORT=y
CONFIG_CEC_CORE=y
CONFIG_CEC_PIN=y
```

### 3. Graphics & Display
```
CONFIG_DRM_ROCKCHIP=y
CONFIG_ROCKCHIP_DRM_TVE=y
CONFIG_DRM_PANFROST=y          # Mali GPU (Panfrost driver)
CONFIG_MALI_MIDGARD=y           # Alternative: ARM Mali driver
CONFIG_MALI_EXPERT=y
CONFIG_MALI_PLATFORM_THIRDPARTY=y
CONFIG_MALI_PLATFORM_NAME="rk"
CONFIG_MALI_DEVFREQ=y
```

### 4. Input Devices (TV Remote, Gamepad)
```
CONFIG_INPUT_JOYSTICK=y
CONFIG_INPUT_TABLET=y
CONFIG_JOYSTICK_XPAD=y
CONFIG_JOYSTICK_PSXPAD_SPI=y
CONFIG_JOYSTICK_PSXPAD_SPI_FF=y
CONFIG_JOYSTICK_XPAD_FF=y
CONFIG_JOYSTICK_XPAD_LEDS=y

# IR Remote
CONFIG_IR_GPIO_CIR=y
CONFIG_IR_RC5_DECODER=y
CONFIG_IR_NEC_DECODER=y
CONFIG_IR_SONY_DECODER=y
CONFIG_IR_RC6_DECODER=y
CONFIG_RC_DEVICES=y
CONFIG_IR_GPIO_TX=y
```

### 5. Audio
```
CONFIG_SND_SOC_ROCKCHIP=y
CONFIG_SND_SOC_ROCKCHIP_I2S=y
CONFIG_SND_SOC_ROCKCHIP_SPDIF=y
CONFIG_SND_SOC_ROCKCHIP_HDMI=y
CONFIG_SND_SOC_ES8316=y          # Audio codec
CONFIG_SND_SOC_HDMI_CODEC=y
```

### 6. Wi-Fi & Bluetooth (AP6256)
```
CONFIG_WLAN_VENDOR_BROADCOM=y
CONFIG_BRCMUTIL=y
CONFIG_BRCMFMAC=y
CONFIG_BRCMFMAC_USB=y
CONFIG_BRCMFMAC_SDIO=y
CONFIG_BRCMFMAC_PCIE=y
CONFIG_BT=y
CONFIG_BT_HCIUART=y
CONFIG_BT_HCIUART_H4=y
CONFIG_BT_BCM=y
```

### 7. USB & Peripheral
```
CONFIG_USB=y
CONFIG_USB_XHCI_HCD=y
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_OHCI_HCD=y
CONFIG_USB_DWC3=y
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_F_FS=y
CONFIG_USB_CONFIGFS_F_ACC=y
CONFIG_USB_CONFIGFS_F_AUDIO_SRC=y
CONFIG_USB_CONFIGFS_F_MTP=y
CONFIG_USB_CONFIGFS_F_PTP=y
```

### 8. File Systems
```
CONFIG_EXT4_FS=y
CONFIG_EXT4_FS_POSIX_ACL=y
CONFIG_EXT4_FS_SECURITY=y
CONFIG_F2FS_FS=y
CONFIG_F2FS_FS_SECURITY=y
CONFIG_FUSE_FS=y
CONFIG_SDCARD_FS=y
CONFIG_VFAT_FS=y
CONFIG_EXFAT_FS=y
CONFIG_NTFS_FS=y
```

### 9. Network
```
CONFIG_NETFILTER=y
CONFIG_NF_NAT=y
CONFIG_BRIDGE=y
CONFIG_BRIDGE_NETFILTER=y
CONFIG_STP=y
CONFIG_LLC=y
CONFIG_TUN=y
```

## Building the Kernel

```bash
cd ~/androidtv-rock4cplus/kernel
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
make rockchip_defconfig
make -j$(nproc) Image
make rk3399-rock-4c-plus.dtb
```

## Kernel Command Line

```
console=ttyFIQ0,1500000
androidboot.hardware=rk30board
androidboot.console=ttyFIQ0
androidboot.selinux=permissive
init=/init
rootwait
earlycon=uart8250,mmio32,0xff1a0000
swiotlb=1
coherent_pool=1m
cgroup_enable=cpuset
cgroup_memory=1
cgroup_enable=memory
loop.max_part=7
```

## Verifying Kernel Features

After boot:
```bash
# Check HDMI-CEC
ls /dev/cec0

# Check GPU
cat /sys/kernel/debug/mali/gpu_memory

# Check Wi-Fi
dmesg | grep brcmfmac

# Check binder
ls /dev/binder
ls /dev/hwbinder
ls /dev/vndbinder
```

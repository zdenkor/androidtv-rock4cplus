# Device Tree Notes for Radxa ROCK 4C+ (RK3399-T)

## Overview

The ROCK 4C+ uses the **Rockchip RK3399-T** SoC, which is a lower-clocked variant of the RK3399. The device tree is based on the ROCK Pi 4 series with adjustments for the RK3399-T.

## Key Differences: RK3399 vs RK3399-T

| Parameter | RK3399 | RK3399-T |
|-----------|--------|----------|
| Cortex-A72 max freq | 1.8 GHz | 1.5 GHz |
| Cortex-A53 max freq | 1.4 GHz | 1.0 GHz |
| GPU max freq | 800 MHz | 650 MHz |
| DDR max freq | 933 MHz | 933 MHz |

## Device Tree Structure

```
rk3399-rock-4c-plus.dts
├── #include "rk3399.dtsi"           # Base RK3399 SoC
├── #include "rk3399-t-opp.dtsi"     # RK3399-T OPP table
├── #include "rk3399-linux.dtsi"     # Linux-specific config
└── Board-specific nodes:
    ├── chosen { }                   # Boot args, stdout
    ├── memory { }                   # RAM configuration
    ├── backlight { }                # Display backlight
    ├── hdmi { }                     # HDMI output
    ├── dp { }                       # DisplayPort
    ├── sdmmc { }                    # microSD card
    ├── sdio0 { }                    # Wi-Fi (AP6256)
    ├── sdhci { }                    # eMMC
    ├── usb { }                      # USB 2.0/3.0
    ├── pcie { }                     # M.2 slot
    ├── gpio-keys { }                # Power, recovery buttons
    └── leds { }                     # Status LEDs
```

## ROCK 4C+ Hardware Specs

| Component | Details |
|-----------|---------|
| SoC | Rockchip RK3399-T |
| RAM | 2GB / 4GB LPDDR4 |
| Storage | eMMC (optional) + microSD |
| Wi-Fi | AP6256 (802.11ac + BT 5.0) |
| Ethernet | Gigabit (RTL8211E) |
| HDMI | 2.0 up to 4K@60Hz |
| USB | 2x USB 3.0, 2x USB 2.0 |
| M.2 | M.2 M-Key (PCIe 2.0 x4) |
| GPIO | 40-pin header |

## CPU OPP Table for RK3399-T

```
cluster0 (A53):
  opp-600000000  @ 825mV
  opp-816000000  @ 850mV
  opp-1008000000 @ 925mV

cluster1 (A72):
  opp-600000000  @ 825mV
  opp-816000000  @ 850mV
  opp-1008000000 @ 875mV
  opp-1200000000 @ 950mV
  opp-1416000000 @ 1025mV
  opp-1512000000 @ 1075mV
```

## HDMI-CEC Configuration

For Android TV, HDMI-CEC should be enabled to allow TV remote control:

```dts
&hdmi {
    status = "okay";
    cec-enable = "true";
};

&hdmi_sound {
    status = "okay";
};
```

## IR Receiver

The ROCK 4C+ has an IR receiver on GPIO. Configure for Android TV remote:

```dts
&pwm3 {
    status = "okay";
    interrupts = <GIC_SPI 61 IRQ_TYPE_LEVEL_HIGH 0>;
    compatible = "rockchip,remotectl-pwm";
    remote_pwm_id = <3>;
    handle_cpu_id = <1>;
    remote_support_psci = <0>;
    
    ir_key1 {
        rockchip,usercode = <0xff00>;
        rockchip,key_table =
            <0xeb   KEY_POWER>,
            <0xa3   KEY_HOME>,
            <0xe3   KEY_BACK>,
            <0xbe   KEY_MENU>,
            <0xec   KEY_UP>,
            <0xed   KEY_DOWN>,
            <0xee   KEY_LEFT>,
            <0xef   KEY_RIGHT>,
            <0xb3   KEY_ENTER>;
    };
};
```

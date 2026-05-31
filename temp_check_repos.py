import urllib.request, socket
socket.setdefaulttimeout(15)
urls = [
    'https://github.com/rockchip-linux/hardware-interfaces',
    'https://github.com/rockchip-linux/hardware',
    'https://github.com/rockchip-linux/device',
    'https://github.com/rockchip-linux/hardware-rockchip',
    'https://github.com/rockchip-linux/hardware-rk3399',
    'https://github.com/rockchip-linux/android_device_rockchip_rk3399',
    'https://github.com/rockchip-linux/android_hardware_rockchip',
    'https://github.com/rockchip-linux/vendor_rockchip',
]
for url in urls:
    try:
        req = urllib.request.Request(url, method='HEAD')
        with urllib.request.urlopen(req) as r:
            print(url, r.status)
    except Exception as e:
        print(url, 'ERR', type(e).__name__, e)

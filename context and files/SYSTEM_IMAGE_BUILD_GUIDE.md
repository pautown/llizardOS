# System Image Build Guide for llizardgui-host

This guide covers everything needed to build a system image that boots llizardgui-host automatically on the Spotify Car Thing.

## Overview

| Component | Purpose |
|-----------|---------|
| **llizardgui-host** | Native raylib GUI application (DRM backend) |
| **mediadash-client** | Go BLE daemon for media bridging |
| **libMali.so** | Mali GPU driver (provides GBM, EGL, GLES) |
| **mali.ko** | Mali GPU kernel module |

---

## 1. Stock Files from CarThing Firmware

The Car Thing's stock firmware contains proprietary libraries needed for GPU and input handling.

### Extract Stock Files

```bash
cd supporting_projects/llizardOS/resources/stock-files
sudo ./download.sh
```

### Files Extracted to `output/`

**GPU/Graphics:**
- `libMali.so` - Mali GPU driver blob (provides GBM, EGL, GLESv2)
- `libdrm.so.2.4.0` - DRM/KMS library

**Input:**
- `libinput.so.10.13.0` - Input device handling
- `libevdev.so.2.2.0` - Event device library
- `libmtdev.so.1.0.0` - Multitouch library
- `libxkbcommon.so.0.0.0` - Keyboard mapping

**Images:**
- `libjpeg.so.9.3.0` - JPEG decoding
- `libpng16.so.16.36.0` - PNG decoding
- `libwebp.so.7.0.3` - WebP decoding (album art)

**Fonts:**
- `libfreetype.so.6.16.1` - Font rendering
- `libfontconfig.so.1.12.0` - Font discovery

**Other:**
- `libffi.so.7.1.0` - Foreign function interface
- `libatomic.so.1.2.0` - Atomic operations
- `libasound.so.2.0.0` - ALSA audio

**Kernel Modules:**
- `lib/modules/` - Including `mali.ko` for GPU

---

## 2. Library Symlinks

The stock libraries have version numbers. Create symlinks so applications can find them.

Add to your build script (or see `scripts/stages/00/50-stock-files.sh`):

```bash
# GPU/Graphics (libMali.so is a monolithic blob providing multiple APIs)
ln -sf libMali.so "$ROOTFS/usr/lib/libgbm.so"
ln -sf libMali.so "$ROOTFS/usr/lib/libgbm.so.1"
ln -sf libMali.so "$ROOTFS/usr/lib/libEGL.so.1.4"
ln -sf libEGL.so.1.4 "$ROOTFS/usr/lib/libEGL.so"
ln -sf libEGL.so.1.4 "$ROOTFS/usr/lib/libEGL.so.1"
ln -sf libMali.so "$ROOTFS/usr/lib/libGLESv2.so.2.0"
ln -sf libGLESv2.so.2.0 "$ROOTFS/usr/lib/libGLESv2.so"
ln -sf libGLESv2.so.2.0 "$ROOTFS/usr/lib/libGLESv2.so.2"
ln -sf libdrm.so.2.4.0 "$ROOTFS/usr/lib/libdrm.so.2"

# Input
ln -sf libinput.so.10.13.0 "$ROOTFS/usr/lib/libinput.so.10"
ln -sf libevdev.so.2.2.0 "$ROOTFS/usr/lib/libevdev.so.2"
ln -sf libmtdev.so.1.0.0 "$ROOTFS/usr/lib/libmtdev.so.1"
ln -sf libxkbcommon.so.0.0.0 "$ROOTFS/usr/lib/libxkbcommon.so.0"

# Images
ln -sf libjpeg.so.9.3.0 "$ROOTFS/usr/lib/libjpeg.so.9"
ln -sf libpng16.so.16.36.0 "$ROOTFS/usr/lib/libpng16.so.16"
ln -sf libwebp.so.7.0.3 "$ROOTFS/usr/lib/libwebp.so.7"

# Fonts
ln -sf libfreetype.so.6.16.1 "$ROOTFS/usr/lib/libfreetype.so.6"
ln -sf libfontconfig.so.1.12.0 "$ROOTFS/usr/lib/libfontconfig.so.1"

# Other
ln -sf libffi.so.7.1.0 "$ROOTFS/usr/lib/libffi.so.7"
ln -sf libatomic.so.1.2.0 "$ROOTFS/usr/lib/libatomic.so.1"
ln -sf libasound.so.2.0.0 "$ROOTFS/usr/lib/libasound.so.2"
```

---

## 3. Binaries and Plugins

### Build ARM Binaries

```bash
# Build llizardgui-host for CarThing
cd llizardgui-host
mkdir -p build-armv7-drm && cd build-armv7-drm
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchain-armv7.cmake -DPLATFORM=DRM ..
make -j$(nproc)
```

### Install to Image

```bash
# Main binary
install -m 755 build-armv7-drm/llizardgui-host "$ROOTFS/usr/bin/"

# Plugins
mkdir -p "$ROOTFS/usr/lib/llizardgui/plugins"
cp build-armv7-drm/*.so "$ROOTFS/usr/lib/llizardgui/plugins/"

# BLE client (statically linked Go binary - no dependencies)
install -m 755 supporting_projects/golang_ble_client/mediadash-client "$ROOTFS/usr/bin/"
```

---

## 4. Fonts

The SDK looks for fonts in these locations (in order):
1. `/var/local/fonts/`
2. `/tmp/fonts/`
3. `./fonts/`

```bash
mkdir -p "$ROOTFS/var/local/fonts"
cp fonts/ZegoeUI-U.ttf "$ROOTFS/var/local/fonts/"
```

---

## 5. Required Directories

```bash
mkdir -p "$ROOTFS/var/llizard"                    # Config storage
mkdir -p "$ROOTFS/var/mediadash/album_art_cache"  # Album art cache
mkdir -p "$ROOTFS/run/llizard"                    # XDG_RUNTIME_DIR (or create at boot)
```

---

## 6. Service Configuration (runit)

### llizardgui Service

Create `/etc/sv/llizardgui/run`:

```bash
#!/bin/sh
exec 2>&1

# Wait for dependencies
sv check dbus > /dev/null || exit 1
sv check redis > /dev/null || exit 1

# Load Mali GPU kernel module (CRITICAL - must load before starting GUI)
modprobe mali 2>/dev/null || \
  insmod /lib/modules/4.9.113/hardware/aml-4.9/arm/gpu/mali.ko 2>/dev/null || true

# Trigger input device udev rules
udevadm trigger --subsystem-match=input > /dev/null 2>&1
udevadm settle > /dev/null 2>&1

# Set up environment for DRM rendering
export XDG_RUNTIME_DIR="/run/llizard"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

# Run llizardgui-host from plugins directory
cd /usr/lib/llizardgui
exec /usr/bin/llizardgui-host
```

Make executable:
```bash
chmod +x "$ROOTFS/etc/sv/llizardgui/run"
```

### Enable Service

```bash
ln -s /etc/sv/llizardgui "$ROOTFS/var/service/"
```

### mediadash-client Service

Create `/etc/sv/mediadash-client/run`:

```bash
#!/bin/sh
exec 2>&1

sv check dbus > /dev/null || exit 1
sv check bluetoothd > /dev/null || exit 1

exec /usr/bin/mediadash-client
```

Enable:
```bash
chmod +x "$ROOTFS/etc/sv/mediadash-client/run"
ln -s /etc/sv/mediadash-client "$ROOTFS/var/service/"
```

---

## 7. Services to Remove (Optional)

If fully replacing Nocturne's web UI:

```bash
# seatd not needed for direct DRM rendering
rm "$ROOTFS/var/service/seatd" 2>/dev/null || true
rm -rf "$ROOTFS/etc/sv/seatd" 2>/dev/null || true

# Remove any web UI services
rm "$ROOTFS/var/service/chromium" 2>/dev/null || true
rm "$ROOTFS/var/service/weston" 2>/dev/null || true
rm "$ROOTFS/var/service/cage" 2>/dev/null || true
```

---

## 8. Summary Checklist

| Component | Destination | Source |
|-----------|-------------|--------|
| libMali.so + symlinks | `/usr/lib/` | Stock firmware via `download.sh` |
| mali.ko | `/lib/modules/.../gpu/` | Stock firmware via `download.sh` |
| Other .so libraries | `/usr/lib/` | Stock firmware via `download.sh` |
| llizardgui-host | `/usr/bin/` | `build-armv7-drm/` |
| Plugins (*.so) | `/usr/lib/llizardgui/plugins/` | `build-armv7-drm/` |
| mediadash-client | `/usr/bin/` | `golang_ble_client/` |
| ZegoeUI-U.ttf | `/var/local/fonts/` | `fonts/` |
| llizardgui service | `/etc/sv/llizardgui/run` | Create (see above) |
| Service symlink | `/var/service/llizardgui` | Link to `/etc/sv/` |

---

## 9. Boot Sequence

When the system boots:

1. **Kernel loads** → displays boot logo on framebuffer
2. **Init starts runit services** → starts dbus, redis, bluetoothd, etc.
3. **llizardgui service starts:**
   - Loads `mali.ko` kernel module
   - Triggers udev for input devices
   - Sets up XDG_RUNTIME_DIR
   - Executes `llizardgui-host`
4. **llizardgui-host takes over DRM** → replaces boot logo with GUI

---

## 10. Troubleshooting

### "Failed creating base context during opening of kernel driver"
The Mali kernel module isn't loaded. Ensure the service script loads it:
```bash
modprobe mali || insmod /lib/modules/4.9.113/hardware/aml-4.9/arm/gpu/mali.ko
```

### "libgbm.so.1: cannot open shared object file"
Missing symlink. Create it:
```bash
ln -sf libMali.so /usr/lib/libgbm.so.1
```

### Boot logo stays on screen
The GUI service isn't starting or is crashing. Check:
```bash
sv status llizardgui
cat /var/log/llizardgui/current  # if logging enabled
```

### Font warnings
Ensure fonts are installed to `/var/local/fonts/`:
```bash
ls -la /var/local/fonts/
```

---

## Related Files

- `scripts/stages/00/50-stock-files.sh` - Copies stock libraries and creates symlinks
- `scripts/stages/10/50-display.sh` - Installs llizardgui-host and plugins
- `scripts/services/llizardgui/run` - Service script
- `resources/stock-files/download.sh` - Downloads and extracts stock firmware

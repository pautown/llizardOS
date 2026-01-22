# LlizardOS

Custom firmware for the Spotify Car Thing that transforms discontinued hardware into a dedicated media companion with a native raylib-based GUI.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Build Prerequisites](#build-prerequisites)
- [Build Process](#build-process)
- [Build Stages](#build-stages)
- [Runtime Services](#runtime-services)
- [Flashing](#flashing)
- [Directory Structure](#directory-structure)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)

## Overview

LlizardOS repurposes abandoned Spotify Car Thing hardware into a dedicated media display. Unlike web-based alternatives, LlizardOS uses a native DRM GUI (llizardGUI) that renders directly to the display for minimal resource usage and fast boot times.

### Key Features

- **Native DRM Rendering** - No Weston/Chromium, direct GPU access via Mali driver
- **Media Display** - Album art, track information, playback controls
- **Physical Controls** - Dial and buttons for skip, pause, volume
- **Bluetooth Integration** - BLE GATT protocol via Mercury daemon
- **Plugin System** - Expandable functionality through Salamander plugins
- **Read-Only Root** - System partition is read-only for reliability

### Runtime Stack

| Component | Description |
|-----------|-------------|
| **llizardGUI** | Native raylib GUI application (DRM backend) |
| **Mercury** | Go BLE daemon bridging phone media to Redis |
| **Redis** | In-memory data store for media state |
| **BlueZ** | Bluetooth stack |

## Architecture

### Partition Layout

```
/dev/system_a  - Root filesystem (read-only, A/B slot)
/dev/system_b  - Root filesystem (read-only, A/B slot)
/dev/data      - Mounted at /var (read-write, persistent)
/dev/settings  - Mounted at /var/lib (read-write, persistent)
```

### Key Directories

```
/usr/bin/llizardGUI              - Main GUI application
/usr/bin/mercury                 - BLE media bridge daemon
/usr/lib/llizard/plugins/        - Plugin shared objects (.so)
/usr/lib/llizard/data/fonts/     - UI fonts
/var/llizard/                    - Runtime config storage
/etc/llizardOS/                  - Build info
```

## Build Prerequisites

### Using Docker (Recommended)

Docker handles all dependencies automatically. Required tools on host:

- Docker
- just (command runner)
- QEMU user-mode (for ARM emulation on x86_64)

### Manual Build Requirements

Install these tools on your system:

- `curl` - File downloads
- `zip`, `unzip` - Archive handling
- `genimage` - Disk image generation
- `m4` - Macro processor
- `xbps-install` - Void Linux package manager
- `mkpasswd` - Password hashing
- `patchelf` - ELF binary patching
- `rsync` - File synchronization

**Note:** xbps-install can be installed on any distro using the [static binaries](https://docs.voidlinux.org/xbps/troubleshooting/static.html).

## Build Process

### Quick Start (Docker)

```bash
# 1. Set up QEMU for ARM emulation (required on x86_64 hosts)
just docker-qemu

# 2. Build the firmware image
just docker-run
```

Output: `output/llizardOS_image_vX.X.X.zip`

### Manual Build

```bash
# 1. Set up QEMU if not on ARM
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# 2. Download stock CarThing files (requires root for loop mount)
cd resources/stock-files
sudo ./download.sh
cd ../..

# 3. Build the image
sudo ./build.sh
```

### Available Just Commands

```bash
just -l
# Available recipes:
#   docker-build  # Build the Docker image
#   docker-qemu   # Set up QEMU binfmt for ARM emulation
#   docker-run    # Build the firmware image (runs docker-build first)
#   lint          # Run pre-commit hooks
#   run           # Build directly (requires root, all deps installed)
```

### Build Configuration

Environment variables in `build.sh`:

| Variable | Default | Description |
|----------|---------|-------------|
| `LLIZARDOS_VERSION` | `v1.0.0` | Version string in output filename |
| `VOID_BUILD` | `20250202` | Void Linux rootfs version |
| `DEFAULT_HOSTNAME` | `llizardos` | Device hostname |
| `DEFAULT_ROOT_PASSWORD` | `llizardos` | Root SSH password |
| `SIZE_ROOT_FS` | `516M` | Root partition size |
| `STAGES` | `00 10 20 30 40` | Build stages to run |

## Build Stages

The build system runs 5 stages in sequence:

### Stage 00 - Prepare Root Filesystem

| Script | Purpose |
|--------|---------|
| `10-create-directories.sh` | Create basic directory structure |
| `20-cache.sh` | Restore xbps package cache |
| `30-xbps.sh` | Download Void rootfs, install base packages |
| `40-resolv.conf.sh` | Set up DNS for package downloads |
| `50-stock-files.sh` | Copy CarThing stock libraries, create symlinks |

**Key Actions:**
- Downloads Void Linux ARMv7l rootfs tarball
- Installs `base-llizardos` meta-package
- Copies proprietary libraries from stock CarThing firmware:
  - `libMali.so` - GPU driver (GBM, EGL, GLESv2)
  - `libdrm.so` - DRM/KMS
  - `libinput.so`, `libevdev.so`, `libmtdev.so` - Input handling
  - Image libraries (libjpeg, libpng, libwebp)
  - Font libraries (freetype, fontconfig)
- Creates required symlinks for versioned libraries

### Stage 10 - System Configuration

| Script | Purpose |
|--------|---------|
| `10-etc.sh` | SSH, hostname, root password, motd |
| `20-bins.sh` | Install system utilities |
| `30-core-services.sh` | First-boot script, filesystem mounts |
| `40-network.sh` | USB gadget, NetworkManager, dnsmasq |
| `50-display.sh` | Input udev rules, seatd, auto-brightness |
| `60-bluetooth.sh` | BlueZ, firmware, adapter configuration |
| `65-redis.sh` | Redis installation and configuration |

**Network Configuration:**
- USB RNDIS gadget for USB networking
- Static IP: `172.16.42.2` on usb0
- DNS: CloudFlare/Google fallback

**Redis Configuration:**
- Bound to localhost only
- Persistence disabled (ephemeral cache)
- 32MB memory limit with LRU eviction

### Stage 20 - LlizardOS Configuration

| Script | Purpose |
|--------|---------|
| `30-llizardgui.sh` | Install llizardGUI, Mercury, plugins, fonts |

**Installed Components:**
- `/usr/bin/llizardGUI` - Main GUI binary
- `/usr/bin/mercury` - BLE daemon
- `/usr/lib/llizard/plugins/*.so` - All plugins
- `/usr/lib/llizard/data/fonts/` - UI fonts
- Plugin data (flashcards questions, millionaire questions)
- runit service definitions

### Stage 30 - Cleanup

| Script | Purpose |
|--------|---------|
| `10-save-cache.sh` | Save xbps cache for faster rebuilds |
| `20-resolv.conf.sh` | Remove temporary DNS config |
| `30-clean-dirs.sh` | Remove unnecessary locales, man pages |
| `40-services.sh` | Enable services, remove unused agetty |

### Stage 40 - Image Creation

| Script | Purpose |
|--------|---------|
| `10-system-img.sh` | Generate ext4 system image via genimage |
| `20-update.sh` | Create update tarball (for OTA updates) |
| `30-copy.sh` | Assemble bootloader, partitions into zip |
| `40-output.sh` | Display final image sizes |

**Output Files:**
- `output/llizardOS_image_vX.X.X.zip` - Full flashable image
- `output/llizardOS_update_vX.X.X.tar.zst` - OTA update package

## Runtime Services

LlizardOS uses runit for service supervision. Services are defined in `scripts/services/`:

### Core Services

| Service | Dependency | Description |
|---------|------------|-------------|
| `llizardGUI` | dbus | Native GUI application (loads Mali module, runs from /usr/lib/llizard) |
| `mercury` | dbus, redis, bluetooth_adapter, bluetoothd | BLE media bridge daemon |
| `redis` | - | In-memory data store for media state |

### System Services

| Service | Description |
|---------|-------------|
| `usb-gadget` | USB RNDIS network gadget setup |
| `bluetooth_adapter` | Hardware init via btattach |
| `superbird_init` | CarThing-specific Bluetooth GPIO setup |
| `auto_brightness` | Ambient light sensor brightness control |

### Service Details

**llizardGUI** (`scripts/services/llizardGUI/run`):
```bash
# Key steps:
1. Load Mali GPU kernel module
2. Trigger udev for input devices
3. Set XDG_RUNTIME_DIR=/run/llizard
4. cd /usr/lib/llizard && exec llizardGUI
```

**Mercury** (`scripts/services/mercury/run`):
```bash
# Waits for Bluetooth hardware (hci0) to be ready
# up to 30 seconds before starting
```

## Flashing

### Requirements

- **Windows:** Terbium driver required
  ```powershell
  irm https://driver.terbium.app/get | iex
  ```

### Steps

1. Download `llizardOS_image_vX.X.X.zip` from build output or releases
2. Put Car Thing into burn mode: Hold buttons 1+4, then plug in USB
3. Flash using [Terbium](https://terbium.app)

### Post-Flash Access

```bash
# SSH access (after USB cable connected)
ssh root@172.16.42.2
# Password: llizardos

# Check service status
sv status llizardGUI
sv status mercury
sv status redis
```

## Directory Structure

```
llizardOS/
├── build.sh                    # Main build script
├── Dockerfile                  # Docker build environment
├── docker-entrypoint.sh        # Docker entry point
├── Justfile                    # Build commands
├── resources/
│   ├── config/                 # System configuration files
│   │   ├── bluetooth.conf      # BlueZ configuration
│   │   ├── fstab               # Filesystem mount table
│   │   ├── motd                # Login message
│   │   ├── sshd_config         # SSH daemon config
│   │   └── weston.ini          # (Legacy) Weston config
│   ├── firmware/brcm/          # Bluetooth firmware blobs
│   ├── flash/                  # Bootloader env and logo
│   ├── llizardgui/
│   │   ├── bins/               # Pre-built ARM binaries
│   │   │   ├── llizardGUI
│   │   │   ├── mercury
│   │   │   └── plugins/*.so
│   │   └── data/               # Plugin data files
│   │       ├── fonts/
│   │       ├── flashcards/
│   │       └── millionaire/
│   ├── m4/                     # genimage templates
│   ├── stock-files/            # CarThing proprietary files
│   │   ├── download.sh         # Downloads stock firmware
│   │   ├── extract/            # Raw partition dumps
│   │   └── output/             # Extracted libraries
│   └── xbps/                   # Custom xbps packages
├── scripts/
│   ├── build-helpers/          # Build utility scripts
│   ├── services/               # runit service definitions
│   │   ├── auto_brightness/
│   │   ├── bluetooth_adapter/
│   │   ├── llizardGUI/
│   │   ├── mercury/
│   │   ├── superbird_init/
│   │   └── usb-gadget/
│   ├── stages/                 # Build stage scripts
│   │   ├── 00/                 # Root filesystem setup
│   │   ├── 10/                 # System configuration
│   │   ├── 20/                 # LlizardOS installation
│   │   ├── 30/                 # Cleanup
│   │   └── 40/                 # Image generation
│   ├── firstboot.sh            # First boot initialization
│   ├── reset-data              # Factory reset /var
│   └── reset-settings          # Factory reset /var/lib
├── cache/                      # xbps package cache
└── output/                     # Build output directory
```

## Customization

### Adding Pre-built Binaries

Place ARM binaries in `resources/llizardgui/bins/`:

```bash
# Build llizardgui-host for CarThing
cd /path/to/llizardgui-host
mkdir -p build-armv7-drm && cd build-armv7-drm
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchain-armv7.cmake -DPLATFORM=DRM ..
make -j$(nproc)

# Copy to llizardOS resources
cp llizardgui-host /path/to/llizardOS/resources/llizardgui/bins/llizardGUI
cp *.so /path/to/llizardOS/resources/llizardgui/bins/plugins/
```

### Adding Fonts

Place TTF fonts in `resources/llizardgui/data/fonts/`.

### Adding Plugin Data

For plugins that need data files (questions, etc.):

```bash
# Example: flashcards plugin
mkdir -p resources/llizardgui/data/flashcards/questions/
cp your_questions.json resources/llizardgui/data/flashcards/questions/
```

### Modifying Services

Edit service scripts in `scripts/services/{service}/run`.

### Changing Root Password

Edit `DEFAULT_ROOT_PASSWORD` in `build.sh` or set environment variable:

```bash
DEFAULT_ROOT_PASSWORD="your_password" ./build.sh
```

### Adjusting Partition Size

Edit `SIZE_ROOT_FS` in `build.sh`:

```bash
SIZE_ROOT_FS="600M" ./build.sh
```

## Troubleshooting

### Build Fails: "Please run download.sh first"

Stock files not downloaded:
```bash
cd resources/stock-files
sudo ./download.sh
```

### GUI Not Starting

Check service status and logs:
```bash
ssh root@172.16.42.2
sv status llizardGUI
# Check if Mali module loaded
lsmod | grep mali
# Try manual load
insmod /lib/modules/4.9.113/hardware/aml-4.9/arm/gpu/mali.ko
```

### "libgbm.so.1: cannot open shared object file"

Missing symlink. On device:
```bash
ln -sf libMali.so /usr/lib/libgbm.so.1
```

### Mercury Not Connecting

Check Bluetooth status:
```bash
sv status bluetooth_adapter
sv status bluetoothd
hciconfig -a
bluetoothctl show
```

### Redis Connection Refused

```bash
sv status redis
redis-cli ping
```

### Boot Logo Stays On Screen

GUI service crashing. Check:
```bash
sv status llizardGUI
dmesg | tail -50
```

### Filesystem Full

System partition is read-only and sized at 516MB. If full during build:
1. Increase `SIZE_ROOT_FS` in build.sh
2. Check `scripts/stages/30/30-clean-dirs.sh` removes unnecessary files

### SSH Connection Refused

USB gadget may not be up:
```bash
# On host, check USB device appeared
lsusb | grep -i linux
# Check network interface
ip link show  # look for enp* or usb*
```

## Credits

This project is heavily inspired by [Nocturne](https://github.com/usenocturne/nocturne) and uses a modified version of their image build system. Thanks to:

- The Nocturne team
- [raspi-alpine/builder](https://gitlab.com/raspi-alpine/builder)
- [bishopdynamics](https://github.com/bishopdynamics)
- [Thing Labs](https://github.com/thinglabsoss/superbird-tool)

## License

This project is licensed under the Apache License 2.0.

---

> "Spotify" and "Car Thing" are trademarks of Spotify AB. This software is not affiliated with or endorsed by Spotify AB.

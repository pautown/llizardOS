<h1 align="center">
  <br>
  LlizardOS
  <br>
</h1>

<p align="center">A native firmware for the <a href="https://carthing.spotify.com" target="_blank">Spotify Car Thing</a> that transforms discontinued hardware into a dedicated media companion.</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#flashing">Flashing</a> •
  <a href="#building">Building</a> •
  <a href="#ecosystem">Ecosystem</a> •
  <a href="#credits">Credits</a>
</p>

## About

LlizardOS repurposes abandoned Spotify Car Thing hardware into a dedicated media display that connects to your phone via Bluetooth. It shows what's playing, provides tactile controls, and stays out of the way until needed.

Unlike web-based alternatives, LlizardOS uses a native DRM GUI that renders directly to the display for cold-blooded efficiency.

## Features

- **Media Display** - Shows album art, track information, and playback status
- **Physical Controls** - The device's dial and buttons enable skip, pause, and volume adjustment
- **Bluetooth Integration** - Connects to Janus (Android app) through BLE GATT protocol
- **Minimal Design** - Presents only essential information without unnecessary interface clutter
- **Plugin System** - Expandable functionality through Salamander plugins

## Flashing

> [!WARNING]
> Bricking the Car Thing is nearly impossible, but the risk is always there when flashing custom firmware.

### Requirements

- Terbium driver is required on Windows: `irm https://driver.terbium.app/get | iex` (Powershell)

### Steps

1. Download an installer zip file from [Releases](https://github.com/pautown/llizardOS/releases)
2. Plug in your Car Thing's USB while holding 1+4 (buttons at the top)
3. Follow the instructions on [Terbium](https://terbium.app) to flash your Car Thing using the downloaded zip file

## Building

### Using Docker (Recommended)

```bash
# Set up QEMU for ARM emulation (required on x86_64)
just docker-qemu

# Build the image
just run
```

The flashable image will be output to the `output/` directory.

### Manual Build

Requirements: `curl`, `zip/unzip`, `genimage`, `m4`, `xbps-install`, `mkpasswd`

xbps-install can be installed on any distro using the [static binaries](https://docs.voidlinux.org/xbps/troubleshooting/static.html).

> [!CAUTION]
> Do not extract the xbps-static tar to your rootfs without being careful or else you may end up with a broken system.
>
> `sudo tar --no-overwrite-dir --no-same-owner --no-same-permissions -xvf xbps-static-latest.x86_64-musl.tar.xz -C /`

If you are on an architecture other than arm64, qemu-user-static is required:
```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

Then build:
```bash
just run
```

### Available Commands

```
$ just -l
Available recipes:
  docker-qemu  # Set up QEMU binfmt for ARM emulation
  run          # Build the firmware image
  lint         # Run pre-commit hooks
```

## Ecosystem

LlizardOS functions within a larger architecture:

| Component | Description |
|-----------|-------------|
| **LlizardOS** | Native DRM-based firmware for Car Thing |
| **Janus** | Companion Android application managing the BLE connection |
| **Mercury** | BLE client running on the Car Thing hardware |
| **Salamanders** | Plugins that expand system capabilities |

## Credits

This project is heavily inspired by [Nocturne](https://github.com/usenocturne/nocturne) and uses their image build system. Thanks to the Nocturne team, [raspi-alpine/builder](https://gitlab.com/raspi-alpine/builder), [bishopdynamics](https://github.com/bishopdynamics), and [Thing Labs](https://github.com/thinglabsoss/superbird-tool) for their foundational work.

## License

This project is licensed under the **Apache** license.

---

> "Spotify" and "Car Thing" are trademarks of Spotify AB. This software is not affiliated with or endorsed by Spotify AB.

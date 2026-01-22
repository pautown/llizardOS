#!/bin/sh

# Path to pre-built ARM binaries
BINS_PATH="${RES_PATH}/llizardgui/bins"

# Create all directories first
# NOTE: /usr/lib/llizard is on system partition (not hidden by /var mounts)
mkdir -p "$ROOTFS_PATH"/usr/lib/llizard/plugins
mkdir -p "$ROOTFS_PATH"/usr/lib/llizard/data
mkdir -p "$ROOTFS_PATH"/var/llizard
mkdir -p "$ROOTFS_PATH"/etc/llizardOS

# Install all executable binaries from bins/ (excluding directories)
# This automatically picks up llizardGUI, mercury, and any future binaries
for bin in "$BINS_PATH"/*; do
    if [ -f "$bin" ]; then
        binname=$(basename "$bin")
        color_echo "    Installing binary: $binname" -Cyan
        install -m 755 "$bin" "$ROOTFS_PATH"/usr/bin/"$binname"
    fi
done

# Install all plugins from the plugins directory
if [ -d "$BINS_PATH/plugins" ]; then
    for plugin in "$BINS_PATH"/plugins/*.so; do
        if [ -f "$plugin" ]; then
            pluginname=$(basename "$plugin")
            color_echo "    Installing plugin: $pluginname" -Cyan
            install -m 755 "$plugin" "$ROOTFS_PATH"/usr/lib/llizard/plugins/"$pluginname"
        fi
    done
fi

# Install fonts to data directory
cp -r "$RES_PATH"/llizardgui/data/fonts "$ROOTFS_PATH"/usr/lib/llizard/data/

# Install plugin data directories (for plugins that need extra data files)
# Automatically finds and installs any data/<pluginname> directories
if [ -d "$RES_PATH/llizardgui/data" ]; then
    for datadir in "$RES_PATH"/llizardgui/data/*; do
        if [ -d "$datadir" ] && [ "$(basename "$datadir")" != "fonts" ]; then
            dirname=$(basename "$datadir")
            color_echo "    Installing plugin data: $dirname" -Cyan
            mkdir -p "$ROOTFS_PATH"/usr/lib/llizard/plugins/"$dirname"
            cp -r "$datadir"/* "$ROOTFS_PATH"/usr/lib/llizard/plugins/"$dirname"/
        fi
    done
fi

# Create build-info
echo "version: ${LLIZARDOS_VERSION:-dev}" > "$ROOTFS_PATH"/etc/llizardOS/build-info
echo "build_date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOTFS_PATH"/etc/llizardOS/build-info

# Fix permissions on all installed files
chmod 755 "$ROOTFS_PATH"/usr/lib/llizard/plugins/*.so
chown -R 0:0 "$ROOTFS_PATH"/usr/lib/llizard
chown -R 0:0 "$ROOTFS_PATH"/var/llizard
chown -R 0:0 "$ROOTFS_PATH"/etc/llizardOS

# Install runit services
cp -a "$SCRIPTS_PATH"/services/llizardGUI "$ROOTFS_PATH"/etc/sv/
cp -a "$SCRIPTS_PATH"/services/mercury "$ROOTFS_PATH"/etc/sv/

# Register services to start at boot
DEFAULT_SERVICES="${DEFAULT_SERVICES} llizardGUI mercury"

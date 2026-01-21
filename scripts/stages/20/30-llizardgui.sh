#!/bin/sh

# Path to pre-built ARM binaries
BUILD_OUTPUT_PATH="${SAVED_PWD}/context and files/image-build-output"

# Install llizardGUI binary (llizardgui-host -> llizardGUI)
install -m 755 "$BUILD_OUTPUT_PATH"/bins/llizardgui-host "$ROOTFS_PATH"/usr/bin/llizardGUI

# Install mercury (mediadash-client -> mercury)
install -m 755 "$BUILD_OUTPUT_PATH"/bins/mediadash-client "$ROOTFS_PATH"/usr/bin/mercury

# Create all directories first
# NOTE: /usr/lib/llizard is on system partition (not hidden by /var mounts)
mkdir -p "$ROOTFS_PATH"/usr/lib/llizard/plugins
mkdir -p "$ROOTFS_PATH"/usr/lib/llizard/data
mkdir -p "$ROOTFS_PATH"/var/llizard
mkdir -p "$ROOTFS_PATH"/etc/llizardOS

# Install plugins to system partition (read-only, not hidden by /var/lib mount)
cp "$BUILD_OUTPUT_PATH"/bins/plugins/*.so "$ROOTFS_PATH"/usr/lib/llizard/plugins/

# Install fonts to data directory (still in resources/llizardgui)
cp -r "$RES_PATH"/llizardgui/data/fonts "$ROOTFS_PATH"/usr/lib/llizard/data/

# Install plugin data files to plugins/ directory (where plugins expect them)
# Plugins search for data relative to working dir at plugins/<plugin>/questions/
if [ -d "$BUILD_OUTPUT_PATH/data/millionaire" ]; then
    mkdir -p "$ROOTFS_PATH"/usr/lib/llizard/plugins/millionaire
    cp -r "$BUILD_OUTPUT_PATH"/data/millionaire/* "$ROOTFS_PATH"/usr/lib/llizard/plugins/millionaire/
fi
if [ -d "$BUILD_OUTPUT_PATH/data/flashcards" ]; then
    mkdir -p "$ROOTFS_PATH"/usr/lib/llizard/plugins/flashcards
    cp -r "$BUILD_OUTPUT_PATH"/data/flashcards/* "$ROOTFS_PATH"/usr/lib/llizard/plugins/flashcards/
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

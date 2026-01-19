#!/bin/sh

# Install llizardGUI binary
install -m 755 "$RES_PATH"/llizardgui/bins/llizardGUI "$ROOTFS_PATH"/usr/bin/llizardGUI

# Install janus (BLE daemon)
install -m 755 "$RES_PATH"/llizardgui/bins/janus "$ROOTFS_PATH"/usr/bin/janus

# Create all directories first
# NOTE: /usr/lib/llizard is on system partition (not hidden by /var mounts)
mkdir -p "$ROOTFS_PATH"/usr/lib/llizard/plugins
mkdir -p "$ROOTFS_PATH"/usr/lib/llizard/data
mkdir -p "$ROOTFS_PATH"/var/llizard
mkdir -p "$ROOTFS_PATH"/etc/llizardOS

# Install plugins to system partition (read-only, not hidden by /var/lib mount)
cp "$RES_PATH"/llizardgui/bins/plugins/*.so "$ROOTFS_PATH"/usr/lib/llizard/plugins/

# Install data files (flashcards, millionaire questions, etc.)
cp -r "$RES_PATH"/llizardgui/data/* "$ROOTFS_PATH"/usr/lib/llizard/data/

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
cp -a "$SCRIPTS_PATH"/services/janus "$ROOTFS_PATH"/etc/sv/

# Register services to start at boot
DEFAULT_SERVICES="${DEFAULT_SERVICES} llizardGUI janus"

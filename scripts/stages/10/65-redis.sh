#!/bin/sh

# Install redis
xbps-install -r "$ROOTFS_PATH" -y redis

# Create redis data directory with proper permissions
mkdir -p "$ROOTFS_PATH"/var/lib/redis
chown 0:0 "$ROOTFS_PATH"/var/lib/redis
chmod 755 "$ROOTFS_PATH"/var/lib/redis

# Register redis service to start at boot
DEFAULT_SERVICES="${DEFAULT_SERVICES} redis"

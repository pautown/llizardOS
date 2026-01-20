#!/bin/sh

# Install redis
xbps-install -r "$ROOTFS_PATH" -y redis

# Create redis data directory with proper permissions
mkdir -p "$ROOTFS_PATH"/var/lib/redis
chown 0:0 "$ROOTFS_PATH"/var/lib/redis
chmod 755 "$ROOTFS_PATH"/var/lib/redis

# Configure Redis to disable persistence (CarThing data is ephemeral)
# This prevents "MISCONF" errors when the RDB directory isn't writable
cat > "$ROOTFS_PATH"/etc/redis/redis.conf << 'EOF'
# llizardOS Redis configuration
# Persistence disabled - CarThing uses Redis as ephemeral cache only

bind 127.0.0.1
port 6379
daemonize no

# Disable RDB persistence entirely
save ""
stop-writes-on-bgsave-error no

# Disable AOF persistence
appendonly no

# Memory management
maxmemory 32mb
maxmemory-policy allkeys-lru

# Logging
loglevel notice
logfile ""
EOF

# Register redis service to start at boot
DEFAULT_SERVICES="${DEFAULT_SERVICES} redis"

#!/bin/sh

mkdir -p "$UPDATE_PATH"/etc/llizardOS "$UPDATE_PATH"/usr/bin "$UPDATE_PATH"/usr/lib/llizard
cp -R "$ROOTFS_PATH"/etc/llizardOS/* "$UPDATE_PATH"/etc/llizardOS/

cp "$ROOTFS_PATH"/usr/bin/llizardGUI "$UPDATE_PATH"/usr/bin/
cp "$ROOTFS_PATH"/usr/bin/mercury "$UPDATE_PATH"/usr/bin/
cp -R "$ROOTFS_PATH"/usr/lib/llizard/plugins "$UPDATE_PATH"/usr/lib/llizard/
cp -R "$ROOTFS_PATH"/usr/lib/llizard/data "$UPDATE_PATH"/usr/lib/llizard/

chown -R 0:0 "$UPDATE_PATH"/*
tar -cf - -C "$UPDATE_PATH"/ . | zstd -9 -o "$IMAGE_PATH"/llizardOS_update_"$LLIZARDOS_VERSION".tar.zst

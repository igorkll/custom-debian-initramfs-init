#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi


apt install -y cloud-guest-utils
apt install -y e2fsprogs
apt install -y gdisk
apt install -y uuid-runtime
apt install -y sed
apt install -y mawk
apt install -y kexec-tools
apt install -y alsa-utils

cp custom_init.sh /usr/share/initramfs-tools/init
cp custom_init_hook.sh /etc/initramfs-tools/hooks/custom_init_hook.sh

chmod -R 755 etc
cp -R etc/. /etc/.

update-initramfs -u

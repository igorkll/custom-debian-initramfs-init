#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi


apt install cloud-guest-utils
apt install e2fsprogs
apt install gdisk
apt install uuid-runtime
apt install sed
apt install mawk
apt install kexec-tools
apt install alsa-utils

cp custom_init.sh /usr/share/initramfs-tools/init
cp custom_init_hook.sh /etc/initramfs-tools/hooks/custom_init_hook.sh

update-initramfs -u

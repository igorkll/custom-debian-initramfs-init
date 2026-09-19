#!/bin/sh
PREREQ=""

prereqs() {
    echo "$PREREQ"
}

case "$1" in
    prereqs)
        prereqs
        exit 0
        ;;
esac

. /usr/share/initramfs-tools/hook-functions

copy_exec /usr/sbin/mkswap /nativemkswap
copy_exec /usr/sbin/swapon /nativeswapon

if ! manual_add_modules zram; then
    echo "Warning: Could not add zram module to initramfs" >&2
fi

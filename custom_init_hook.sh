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

copy_exec /usr/bin/cp /usr/bin
copy_exec /usr/bin/rm /usr/bin
copy_exec /usr/bin/growpart /usr/bin
copy_exec /usr/bin/resize2fs /usr/bin

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
copy_exec /usr/bin/grep /usr/bin
copy_exec /usr/bin/flock /usr/bin
copy_exec /usr/bin/partx /usr/bin
copy_exec /usr/bin/sed /usr/bin
copy_exec /usr/bin/awk /usr/bin
copy_exec /usr/sbin/resize2fs /usr/sbin
copy_exec /usr/sbin/e2fsck /usr/sbin
copy_exec /usr/sbin/fsck /usr/sbin
copy_exec /usr/sbin/fsck.ext2 /usr/sbin
copy_exec /usr/sbin/fsck.ext4 /usr/sbin
copy_exec /usr/sbin/logsave /usr/sbin
copy_exec /usr/sbin/sfdisk /usr/sbin

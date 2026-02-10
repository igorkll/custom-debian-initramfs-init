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
copy_exec /usr/bin/rmdir /usr/bin
copy_exec /usr/bin/uuidgen /usr/bin
copy_exec /usr/bin/yes /usr/bin
copy_exec /usr/bin/tr /usr/bin
copy_exec /usr/sbin/resize2fs /usr/sbin
copy_exec /usr/sbin/e2fsck /usr/sbin
copy_exec /usr/sbin/fsck /usr/sbin
copy_exec /usr/sbin/fsck.ext2 /usr/sbin
copy_exec /usr/sbin/fsck.ext4 /usr/sbin
copy_exec /usr/sbin/logsave /usr/sbin
copy_exec /usr/sbin/sfdisk /usr/sbin
copy_exec /usr/sbin/sgdisk /usr/sbin
copy_exec /usr/sbin/blkid /usr/sbin
copy_exec /usr/sbin/tune2fs /usr/sbin
copy_exec /usr/sbin/kexec /usr/sbin
copy_exec /usr/bin/mount /nativemount

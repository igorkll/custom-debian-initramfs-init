#!/bin/sh

# Default PATH differs between shells, and is not automatically exported
# by klibc dash.  Make it consistent.
export PATH=/sbin:/usr/sbin:/bin:/usr/bin

if [ -z "$QUIET_RESTARTED" ]; then
	[ -d /proc ] || mkdir /proc
	mount -t proc -o nodev,noexec,nosuid proc /proc

	for x in $(cat /proc/cmdline); do
		case $x in
		quiet)
			quiet=y
			;;
		nokernellogs)
			echo 0 > /proc/sys/kernel/printk
			;;
		clear)
			printf "\033[2J\033[H"
			;;
		noCursorBlink)
			printf "\033[?25l"
			;;
		noctrlaltdel)
			echo 0 > /proc/sys/kernel/ctrl-alt-del
			;;
		nosysrq)
			echo 0 > /proc/sys/kernel/sysrq
			;;
		esac
	done

	if [ "$quiet" = "y" ]; then
		export QUIET_RESTARTED=1
		exec "$0" "$@" >/dev/null 2>&1
	fi
fi

for x in $(cat /proc/cmdline); do
	case $x in
	quiet)
		quiet=y
		;;
	initramfs.runsize=*)
		RUNSIZE="${x#initramfs.runsize=}"
		;;

	# custom init parameters
	earlysplash)
		EARLYSPLASH=true
		;;
	logoautohide)
		LOGOAUTOHIDE=true
		;;
	allow_updatescript)
		allow_updatescript=true
		;;
	esac
done

[ -d /dev ] || mkdir -m 0755 /dev
[ -d /root ] || mkdir -m 0700 /root
[ -d /sys ] || mkdir /sys
[ -d /tmp ] || mkdir /tmp
mkdir -p /var/lock
mount -t sysfs -o nodev,noexec,nosuid sysfs /sys
mount -t tmpfs -o "nodev,nosuid,size=${RUNSIZE:-10%},mode=1777" tmpfs /tmp

if [ "$quiet" != "y" ]; then
	quiet=n
	echo "Loading, please wait..."
fi
export quiet

# Note that this only becomes /dev on the real filesystem if udev's scripts
# are used; which they will be, but it's worth pointing out
mount -t devtmpfs -o nosuid,mode=0755 udev /dev

# Prepare the /dev directory
[ ! -h /dev/fd ] && ln -s /proc/self/fd /dev/fd
[ ! -h /dev/stdin ] && ln -s /proc/self/fd/0 /dev/stdin
[ ! -h /dev/stdout ] && ln -s /proc/self/fd/1 /dev/stdout
[ ! -h /dev/stderr ] && ln -s /proc/self/fd/2 /dev/stderr

mkdir /dev/pts
mount -t devpts -o noexec,nosuid,gid=5,mode=0620 devpts /dev/pts || true
mount -t tmpfs -o "nodev,noexec,nosuid,size=${RUNSIZE:-10%},mode=0755" tmpfs /run

plymouth_init() {
	mkdir -p -m 0755 /run/plymouth
	plymouthd --mode=boot --attach-to-session --pid-file=/run/plymouth/pid
	if [ "${USING_UPDATESCRIPT}" = "true" ]; then
		if [ -x "/updateroot/updatescript/updatethememode.sh" ]; then
			/updateroot/updatescript/updatethememode.sh
		else
			plymouth change-mode --system-upgrade
		fi
	fi
	plymouth --show-splash
}

get_uptime() {
	UPTIME=$(cat /proc/uptime)
	UPTIME=${UPTIME%%.*}
}

plymouth_init_and_check() {
	if [ -e /dev/fb0 ]; then
		plymouth_init
		PLYMOUTH_FAILED=false
		get_uptime
		PLYMOUTH_INIT_TIME="${UPTIME}"
	else
		# even so, we're still trying to initialize, we'll just try again later (for example, after loading the kernel modules)
		plymouth_init
		PLYMOUTH_FAILED=true
	fi
}

# initialization of plymouth has been moved to an earlier stage
# I'm not launching plymouth that early if the update system is allowed, as I don't know which logo to show yet
# it will start later when it will be clear whether the OS needs to be updated or not
if [ "${EARLYSPLASH}" = "true" ] && [ "${allow_updatescript}" != "true" ]; then
	plymouth_init_and_check
fi

# Export the dpkg architecture
export DPKG_ARCH=
. /conf/arch.conf

# Set modprobe env
export MODPROBE_OPTIONS="-qb"

# Export relevant variables
export ROOT=
export ROOTDELAY=
export ROOTFLAGS=
export ROOTFSTYPE=
export IP=
export DEVICE=
export BOOT=
export BOOTIF=
export UBIMTD=
export break=
export init=/sbin/init
export readonly=y
export rootmnt=/root
export debug=
export panic=
export blacklist=
export resume=
export resume_offset=
export noresume=
export drop_caps=
export fastboot=n
export forcefsck=n
export fsckfix=


# Bring in the main config
. /conf/initramfs.conf
for conf in conf/conf.d/*; do
	[ -f "${conf}" ] && . "${conf}"
done
. /scripts/functions

# Parse command line options
# shellcheck disable=SC2013
for x in $(cat /proc/cmdline); do
	case $x in
	init=*)
		init=${x#init=}
		;;
	root=*)
		ROOT=${x#root=}
		if [ -z "${BOOT}" ] && [ "$ROOT" = "/dev/nfs" ]; then
			BOOT=nfs
		fi
		;;
	rootflags=*)
		ROOTFLAGS="-o ${x#rootflags=}"
		;;
	rootfstype=*)
		ROOTFSTYPE="${x#rootfstype=}"
		;;
	rootdelay=*)
		ROOTDELAY="${x#rootdelay=}"
		case ${ROOTDELAY} in
		*[![:digit:].]*)
			ROOTDELAY=
			;;
		esac
		;;
	nfsroot=*)
		# shellcheck disable=SC2034
		NFSROOT="${x#nfsroot=}"
		;;
	ip=*)
		IP="${x#ip=}"
		;;
	boot=*)
		BOOT=${x#boot=}
		;;
	ubi.mtd=*)
		UBIMTD=${x#ubi.mtd=}
		;;
	resume=*)
		RESUME="${x#resume=}"
		;;
	resume_offset=*)
		resume_offset="${x#resume_offset=}"
		;;
	noresume)
		noresume=y
		;;
	drop_capabilities=*)
		drop_caps="-d ${x#drop_capabilities=}"
		;;
	panic=*)
		panic="${x#panic=}"
		;;
	ro)
		readonly=y
		;;
	rw)
		readonly=n
		;;
	debug)
		debug=y
		quiet=n
		if [ -n "${netconsole}" ]; then
			log_output=/dev/kmsg
		else
			log_output=/run/initramfs/initramfs.debug
		fi
		set -x
		;;
	debug=*)
		debug=y
		quiet=n
		set -x
		;;
	break=*)
		break=${x#break=}
		;;
	break)
		break=premount
		;;
	blacklist=*)
		blacklist=${x#blacklist=}
		;;
	netconsole=*)
		netconsole=${x#netconsole=}
		[ "$debug" = "y" ] && log_output=/dev/kmsg
		;;
	BOOTIF=*)
		BOOTIF=${x#BOOTIF=}
		;;
	fastboot|fsck.mode=skip)
		fastboot=y
		;;
	forcefsck|fsck.mode=force)
		forcefsck=y
		;;
	fsckfix|fsck.repair=yes)
		fsckfix=y
		;;
	fsck.repair=no)
		fsckfix=n
		;;
	splash*)
		SPLASH="true"
		;;
	nosplash*|plymouth.enable=0)
		SPLASH="false"
		;;

	# it doesn't seem to be working at all. So I'll make my own
	initramfs.clear)
		clear
		;;
	
	# custom init parameters
	loop=*)
		LOOP="${x#loop=}"
		;;
	loopflags=*)
		LOOPFLAGS="-o ${x#loopflags=}"
		;;
	loopfstype=*)
		LOOPFSTYPE="${x#loopfstype=}"
		;;
	loopreadonly)
		LOOPREADONLY=true
		;;
	
	makevartmp)
		makevartmp=true
		;;
	makehometmp)
		makehometmp=true
		;;
	makeroothometmp)
		makeroothometmp=true
		;;
		
	logodelay=*)
		LOGODELAY="${x#logodelay=}"
		case ${LOGODELAY} in
		*[![:digit:].]*)
			LOGODELAY=
			;;
		esac
		;;

	minlogotime=*)
		MINLOGOTIME="${x#minlogotime=}"
		case ${MINLOGOTIME} in
		*[![:digit:].]*)
			MINLOGOTIME=
			;;
		esac
		;;

	root_processing)
		ROOT_PROCESSING=y
		;;
	root_expand)
		ROOT_EXPAND=y
		;;
	root_changepartid)
		ROOT_CHANGEPARTID=y
		;;
	root_changefsuuid)
		ROOT_CHANGEFSUUID=y
		;;

	internal_init=*)
		INTERNAL_INIT="${x#internal_init=}"
		;;
	internal_init_noquiet)
		INTERNAL_INIT_NOQUIET=true
		;;

	crashkernelauto_part=*)
		crashkernelauto_part="${x#crashkernelauto_part=}"
		;;
	crashkernelauto_kernel=*)
		crashkernelauto_kernel="${x#crashkernelauto_kernel=}"
		;;
	crashkernelauto_initramfs=*)
		crashkernelauto_initramfs="${x#crashkernelauto_initramfs=}"
		;;
	crashkernelauto_args=*)
		crashkernelauto_args="${x#crashkernelauto_args=}"
		;;
	crashkernelauto_dtb=*)
		crashkernelauto_dtb="${x#crashkernelauto_dtb=}"
		;;

	rootsubdirectory=*)
		rootsubdirectory="${x#rootsubdirectory=}"
		;;
	realrootroot_ro)
		realrootroot_ro=y
		;;
	rootsubdirectory_ro)
		rootsubdirectory_ro=y
		;;
	preinit=*)
		preinit="${x#preinit=}"
		;;
	esac
done

# Default to BOOT=local if no boot script defined.
if [ -z "${BOOT}" ]; then
	BOOT=local
fi

if [ -n "${noresume}" ] || [ "$RESUME" = none ]; then
	noresume=y
else
	resume=${RESUME:-}
fi

mkdir -m 0700 /run/initramfs

if [ -n "$log_output" ]; then
	exec >"$log_output" 2>&1
	unset log_output
fi

maybe_break top

# Don't do log messages here to avoid confusing graphical boots
run_scripts /scripts/init-top

maybe_break modules
[ "$quiet" != "y" ] && log_begin_msg "Loading essential drivers"
[ -n "${netconsole}" ] && /sbin/modprobe netconsole netconsole="${netconsole}"
load_modules
[ "$quiet" != "y" ] && log_end_msg

# Always load local and nfs (since these might be needed for /etc or
# /usr, irrespective of the boot script used to mount the rootfs).
. /scripts/local
. /scripts/nfs
. "/scripts/${BOOT}"
parse_numeric "${ROOT}"

if [ -n "${crashkernelauto_part}" ] && [ -n "${crashkernelauto_kernel}" ] && [ -n "${crashkernelauto_initramfs}" ] && [ -n "${crashkernelauto_args}" ]; then
	local_device_setup "${crashkernelauto_part}" "kexec file system"

	KEXEC_FSTYPE=$(get_fstype "${DEV}")
	KEXEC_ARGS=$(printf '%s\n' "$crashkernelauto_args" | tr ',' ' ')

	mkdir -m 0700 /kernelroot
	if [ -n "$KEXEC_FSTYPE" ]; then
		mount -r -t "$KEXEC_FSTYPE" "$DEV" /kernelroot
	else
		mount -r "$DEV" /kernelroot
	fi

	if [ -n "${crashkernelauto_dtb}" ]; then
		kexec -p "/kernelroot/${crashkernelauto_kernel}" --initrd="/kernelroot/${crashkernelauto_initramfs}" --dtb="/kernelroot/${crashkernelauto_dtb}" --command-line="${KEXEC_ARGS}"
	else
		kexec -p "/kernelroot/${crashkernelauto_kernel}" --initrd="/kernelroot/${crashkernelauto_initramfs}" --command-line="${KEXEC_ARGS}"
	fi

	umount /kernelroot
	rmdir /kernelroot
fi

wait_minlogotime() {
	if [ -n "${MINLOGOTIME}" ]; then
		LOGO_UPTIME="${UPTIME}"

		if [ -n "${PLYMOUTH_INIT_TIME}" ]; then
			LOGO_UPTIME=$(( LOGO_UPTIME - PLYMOUTH_INIT_TIME ))
		fi

		if [ "${LOGO_UPTIME}" -lt "${MINLOGOTIME}" ]; then
			sleep $((MINLOGOTIME - LOGO_UPTIME))
		fi
	fi
}

wait_logodelay() {
	if [ -n "$LOGODELAY" ]; then
		sleep "$LOGODELAY"
	fi
}

if [ "${allow_updatescript}" = "true" ]; then
	if [ -n "$ROOT" ]; then
		# during the update, the root is always mounted as writable
		# otherwise, it wouldn't make sense on immune systems.
		# we also always use real rootfs for updatescript, even if "loop=" is used.
		# yes, if your OS is immutable, then you will have to temporarily remount the rootfs with write permissions in order to write the updatescript directory itself: mount -o remount,rw /
		old_readonly=$readonly
		readonly=n

		if [ "$BOOT" = "nfs" ]; then
			nfs_mount_root
		else
			local_mount_root
		fi

		readonly=$old_readonly

		mkdir -m 0700 /updateroot
		mount -n -o move "${rootmnt}" /updateroot

		if [ -d "/updateroot/updatescript" ] && [ -x "/updateroot/updatescript/updatescript.sh" ]; then
			USING_UPDATESCRIPT=true
			if [ "${EARLYSPLASH}" = "true" ]; then
				plymouth_init_and_check
			fi

			/updateroot/updatescript/updatescript.sh
			rm -rf /updateroot/updatescript

			wait_logodelay
			get_uptime
			wait_minlogotime

			echo b > /proc/sysrq-trigger
		else
			if [ "${EARLYSPLASH}" = "true" ]; then
				plymouth_init_and_check
			fi
		fi

		umount /updateroot
		rmdir /updateroot
	else
		if [ "${EARLYSPLASH}" = "true" ]; then
			plymouth_init_and_check
		fi
	fi
fi

if [ "${PLYMOUTH_FAILED}" = "true" ]
then
	plymouth_init_and_check
fi

starttime="$(_uptime)"
starttime=$((starttime + 1)) # round up
export starttime

if [ -z "${ROOT}" ] && [ -n "${INTERNAL_INIT}" ] && [ -x "${INTERNAL_INIT}" ]; then
	wait_logodelay
	wait_minlogotime

	if [ "${LOGOAUTOHIDE}" = "true" ]; then
		plymouth quit
	fi

	if [ "${INTERNAL_INIT_NOQUIET}" = "true" ] && [ "${quiet}" = "y" ]; then
		"${INTERNAL_INIT}" >/dev/console 2>/dev/console
	else
		"${INTERNAL_INIT}"
	fi
	sleep 20
	echo b > /proc/sysrq-trigger
fi

if [ "$ROOTDELAY" ]; then
	sleep "$ROOTDELAY"
fi

maybe_break premount
[ "$quiet" != "y" ] && log_begin_msg "Running /scripts/init-premount"
run_scripts /scripts/init-premount
[ "$quiet" != "y" ] && log_end_msg

maybe_break mount
log_begin_msg "Mounting root file system"

maybe_break mountroot
mount_top
mount_premount

if [ "${PLYMOUTH_FAILED}" = "true" ]
then
	plymouth_init_and_check
fi

# custom init paramenters
wait_logodelay

if [ -n "$ROOT" ] && [ -n "$ROOT_PROCESSING" ]; then
	local_device_setup "${ROOT}" "root file system"
	if echo "$DEV" | grep -Eq '^/dev/(nvme|mmcblk)'; then
		PART_NUM="${DEV##*p}"
		DISK="${DEV%p$PART_NUM}"
	else
		PART_NUM="${DEV##*[!0-9]}"
		DISK="${DEV%$PART_NUM}"
	fi

	flag_check_one() {
		if [ "$BOOT" = "nfs" ]; then
			nfs_mount_root
		else
			local_mount_root
		fi

		mkdir -m 0700 /flagcheck
		mount -n -o move "${rootmnt}" /flagcheck

		if [ -d "/flagcheck/$1" ]; then
			FLAGONE=false
		else
			FLAGONE=true
			mkdir -m 0000 "/flagcheck/$1"
		fi

		umount /flagcheck
		rmdir /flagcheck
	}

	if [ -n "$ROOT_CHANGEPARTID" ]; then
		flag_check_one "root_changepartuuid.flag"
		if [ "${FLAGONE}" = "true" ]; then
			log_begin_msg "Change id partition"
			ptable=$(blkid -o value -s PTTYPE "${DISK}" 2>/dev/null)
			case "$ptable" in
				gpt)
					sgdisk -u ${PART_NUM}:$(uuidgen) "${DISK}"
					;;
				dos)
					# ну нет PARTUUID у dos разметки, меняю id всего диска
					printf '0x%08x\n' $RANDOM$RANDOM | sfdisk --disk-id "${DISK}"
					;;
			esac
			partx -u "$DISK"
			log_end_msg
		fi
	fi

	if [ -n "$ROOT_CHANGEFSUUID" ]; then
		flag_check_one "root_changefsuuid.flag"
		if [ "${FLAGONE}" = "true" ]; then
			log_begin_msg "Change filesystem uuid"
			e2fsck -fy "$DEV"
			yes | tune2fs -U random -f "${DEV}"
			partx -u "$DISK"
			log_end_msg
		fi
	fi
	
	if [ -n "$ROOT_EXPAND" ]; then
		flag_check_one "root_expand.flag"
		if [ "${FLAGONE}" = "true" ]; then
			log_begin_msg "Expanding root partition"
			growpart "$DISK" "$PART_NUM"
			partx -u "$DISK"
			e2fsck -fy "$DEV"
			resize2fs "$DEV"
			log_end_msg
		fi
	fi
fi

if [ -n "$LOOP" ]; then
	mountroot()
	{
		log_begin_msg "Mount loop root filesystem"

		if [ -n "$ROOT" ]; then
			if [ "$BOOT" = "nfs" ]; then
				nfs_mount_root
			else
				local_mount_root
			fi

			mkdir -m 0700 /realroot
			mount -n -o move "${rootmnt}" /realroot
		fi

		if [ "$LOOPREADONLY" = "true" ]; then
			roflag=-r
		else
			roflag=-w
		fi

		FSTYPE="$LOOPFSTYPE"
		if [ -z "$FSTYPE" ] || [ "$FSTYPE" = "unknown" ]; then
			FSTYPE=$(/sbin/blkid -s TYPE -o value "$LOOP")
			[ -z "$FSTYPE" ] && FSTYPE="unknown"
		fi

		modprobe loop
		mknod /dev/loop-root b 7 0
		losetup /dev/loop-root "$LOOP"
		mount ${roflag} -t ${FSTYPE} ${LOOPFLAGS} /dev/loop-root "${rootmnt}"

		if [ -d "/realroot" ] && [ -d "${rootmnt}/realroot" ]; then
			mount -n -o move /realroot ${rootmnt}/realroot
		fi

		log_end_msg
	}
fi

mountroot
log_end_msg

if read_fstab_entry /usr; then
	log_begin_msg "Mounting /usr file system"
	mountfs /usr
	log_end_msg
fi

# Mount cleanup
mount_bottom
nfs_bottom
local_bottom

maybe_break bottom
[ "$quiet" != "y" ] && log_begin_msg "Running /scripts/init-bottom"
# We expect udev's init-bottom script to move /dev to ${rootmnt}/dev
run_scripts /scripts/init-bottom
[ "$quiet" != "y" ] && log_end_msg

if [ -n "$rootsubdirectory" ]; then
	log_begin_msg "rootsubdirectory bind"

	mkdir -m 0700 /realrootroot
	mount -n -o move "${rootmnt}" "/realrootroot"

	mount -o bind "/realrootroot/${rootsubdirectory}" /root
	if [ "$rootsubdirectory_ro" = "y" ]; then
		mount -o remount,bind,ro "/root"
	fi

	if [ -d "/root/realrootroot" ]; then
		mount -o bind /realrootroot "/root/realrootroot"
		if [ "$realrootroot_ro" = "y" ]; then
			mount -o remount,bind,ro "/root/realrootroot"
		fi
	fi

	log_end_msg
fi

if [ -n "${INTERNAL_INIT}" ] && [ -x "${INTERNAL_INIT}" ]; then
	wait_minlogotime

	if [ "${LOGOAUTOHIDE}" = "true" ]; then
		plymouth quit
	fi

	"${INTERNAL_INIT}"
	echo b > /proc/sysrq-trigger
fi

# Move /run to the root
mount -n -o move /run ${rootmnt}/run

validate_init() {
	run-init -n "${rootmnt}" "${1}"
}

# Check init is really there
if ! validate_init "$init"; then
	echo "Target filesystem doesn't have requested ${init}."
	init=
	for inittest in /sbin/init /etc/init /bin/init /bin/sh; do
		if validate_init "${inittest}"; then
			init="$inittest"
			break
		fi
	done
fi

# No init on rootmount
if ! validate_init "${init}" ; then
	panic "No init found. Try passing init= bootarg."
fi

maybe_break init

# don't leak too much of env - some init(8) don't clear it
# (keep init, rootmnt, drop_caps)
unset debug
unset MODPROBE_OPTIONS
unset DPKG_ARCH
unset ROOTFLAGS
unset ROOTFSTYPE
unset ROOTDELAY
unset ROOT
unset IP
unset BOOT
unset BOOTIF
unset DEVICE
unset UBIMTD
unset blacklist
unset break
unset noresume
unset panic
unset quiet
unset readonly
unset resume
unset resume_offset
unset noresume
unset fastboot
unset forcefsck
unset fsckfix
unset starttime

make_temp() {
	local_dirname=$1
	local_olddir="/${local_dirname}.old"
	local_target="${rootmnt}/${local_dirname}/"

	if [ -d "${local_target}" ]; then
		mkdir -p "$local_olddir"
		mount -t tmpfs tmpfs "$local_olddir"
		cp -a "${local_target}/." $local_olddir
		mount -t tmpfs -o mode=1777,nodev,nosuid tmpfs "$local_target"
		cp -a "${local_olddir}/." $local_target
		umount "$local_olddir"
		rmdir "$local_olddir"
	fi
}

# make /var tmpfs
if [ "$makevartmp" = "true" ]; then
	make_temp "var"
fi

# make /home tmpfs
if [ "$makehometmp" = "true" ]; then
	make_temp "home"
fi

# make /root tmpfs
if [ "$makeroothometmp" = "true" ]; then
	make_temp "root"
fi

# Move virtual filesystems over to the real filesystem
mount -n -o move /sys ${rootmnt}/sys
mount -n -o move /tmp ${rootmnt}/tmp
get_uptime
mount -n -o move /proc ${rootmnt}/proc

# custom init paramenters
wait_minlogotime

if [ "${LOGOAUTOHIDE}" = "true" ]; then
	plymouth quit
fi

if [ -n "$preinit" ] && [ -x "/root/${preinit}" ]; then
	"/root/${preinit}"
fi

# Chain to real filesystem
# shellcheck disable=SC2086,SC2094
exec run-init ${drop_caps} "${rootmnt}" "${init}" "$@" <"${rootmnt}/dev/console" >"${rootmnt}/dev/console" 2>&1
echo "Something went badly wrong in the initramfs."
panic "Please file a bug on initramfs-tools."


# custom-debian-initramfs-init
custom /init script for initramfs in debian, adding several useful parameters to the cmdline of the kernel

## kernel parameters
* clear - clears the terminal during initialization. does this as early as possible. the original script has initramfs.clear, but apparently it doesn't work
* noCursorBlink - prevents cursor blinking when loading
* earlysplash - an alternative way to initialize plymouth is to try to initialize plymouth as early as possible
* noctrlaltdel - disables support for ctrl+alt+del in the kernel as early as possible
* nosysrq - disables support for sysrq in the kernel as early as possible. As practice shows, sysrq=0 does not always work
* loop=/path - allows you to mount loop files (rootfs in .img file) as root (it seems like this already exists in ubuntu but not in debian) here is the path relative to the initramfs root, however, the real root is accessible via the path /realroot so you can mount the loop, which is located in the real root partition. also, if there is an empty realroot directory inside your loop rootfs, then the real root will be mounted there.
* loopflags= - flags that the loop will be mounted with (not necessary for the loop= to work)
* loopfstype= -  (not necessary for the loop= to work)
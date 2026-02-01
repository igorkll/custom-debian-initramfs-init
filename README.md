# custom-debian-initramfs-init
custom /init script for initramfs in debian, adding several useful parameters to the cmdline of the kernel

## kernel parameters
* clear - clears the terminal during initialization. does this as early as possible. the original script has initramfs.clear, but apparently it doesn't work
* noCursorBlink - prevents cursor blinking when loading
* earlysplash - an alternative way to initialize plymouth is to try to initialize plymouth as early as possible
* noctrlaltdel - disables support for ctrl+alt+del in the kernel as early as possible
* nosysrq - disables support for sysrq in the kernel as early as possible. As practice shows, sysrq=0 does not always work
* 
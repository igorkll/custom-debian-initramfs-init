# custom-debian-initramfs-init
custom /init script for initramfs in debian, adding several useful parameters to the cmdline of the kernel

## kernel parameters
* clear - clears the terminal during initialization. does this as early as possible. the original script has initramfs.clear, but apparently it doesn't work
* noCursorBlink - prevents cursor blinking when loading
* earlysplash - an alternative way to initialize plymouth is to try to initialize plymouth as early as possible. for plymouth to really work, you need the splash parameter right after quiet. in this case, you will get something like "quiet splash earlysplash"
* noctrlaltdel - disables support for ctrl+alt+del in the kernel as early as possible
* nosysrq - disables support for sysrq in the kernel as early as possible. As practice shows, sysrq=0 does not always work
* loop=/path - allows you to mount loop files (rootfs in .img file) as root (it seems like this already exists in ubuntu but not in debian) here is the path relative to the initramfs root, however, the real root is accessible via the path /realroot so you can mount the loop, which is located in the real root partition. also, if there is an empty realroot directory inside your loop rootfs, then the real root will be mounted there.
* loopflags= - flags that the loop will be mounted with (not necessary for the loop= to work)
* loopfstype= - the type of file system inside the loop file. can be determined automatically, not necessary for the loop= to work
* loopreadonly - it says that the loop needs to be mounted as readonly even if the real root is not readonly
* makevartmp - makes a tmpfs "/var" directory by copying the real contents into it. may be necessary for readonly file systems
* makehometmp - makes a tmpfs "/home" directory by copying the real contents into it. may be necessary for readonly file systems
* makeroothometmp - makes a tmpfs "/root" directory by copying the real contents into it. may be necessary for readonly file systems
* logodelay=10 - It was created to create a delay in system loading and the logo was displayed longer.
* minlogotime=10 - a more preferable option. sets exactly the minimum display time for the logo and does not make a stupid delay. it starts before of the init system, but after mounting, when the environment is almost ready.
* root_processing - enables additional processing of the root partition. It doesn't do anything by itself, but it's needed for other parameters.
* root_expand - expands the root partition to the maximum possible size on this disk. This is necessary if you are publishing a system image that can be written to any disk with an unknown size, and you need rootfs to take up all available space. you also need to add root_processing

## additional utilities that should also be in initramfs for this script to work properly
* rm
* cp
* growpart
* resize2fs
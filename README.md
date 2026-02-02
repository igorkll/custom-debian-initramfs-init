# custom-debian-initramfs-init
DOWNLOAD THE RELEASE, NOT THE REPOSITORY!  
WARNING!!! if you read this text from GITHUB page please, download a release and read description there. on github this text is DEV version (not released yet)  
custom /init script for initramfs in debian, adding several useful parameters to the cmdline of the kernel  
the parameters added here make the most sense for embedded devices  
it also allows you to mount rootfs from *.img (loop), including from real rootfs  
Attention! I have NO guarantee that this will go down to your system and won't break it. I warned you, I'm not responsible for anything  

## you may also be interested in
* https://github.com/igorkll/linux-embedded-patchs - a set of patches for using the linux kernel on embedded locked-down devices
* https://github.com/igorkll/syslbuild - creating custom embedded linux systems
* https://github.com/igorkll/WinBox-Maker - a program for creating embedded Windows images

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
* makevartmp - makes a tmpfs "/var" directory by copying the real contents into it. may be necessary for readonly filesystems
* makehometmp - makes a tmpfs "/home" directory by copying the real contents into it. may be necessary for readonly filesystems
* makeroothometmp - makes a tmpfs "/root" directory by copying the real contents into it. may be necessary for readonly filesystems
* logodelay=10 - It was created to create a delay in system loading and the logo was displayed longer.
* minlogotime=10 - a more preferable option. sets exactly the minimum display time for the logo and does not make a stupid delay. it starts before of the init system, but after mounting, when the environment is almost ready.
* logoautohide - automatically hides the logo just before the initialization system starts. it should be used if your userspace itself does not hide the logo
* root_processing - enables additional processing of the root partition. It doesn't do anything by itself, but it's needed for other parameters.
* root_expand - expands the root partition to the maximum possible size on this disk. This is necessary if you are publishing a system image that can be written to any disk with an unknown size, and you need rootfs to take up all available space. you also need to add root_processing
* allow_updatescript - allows the update system built into the script to work, which runs a custom script from the directory "/updatescript/updatescript.sh " the next time the system boots, and then deletes the entire directory. please note that at the time of your "updatescript.sh " the real rootfs is accessible via the path "/updateroot" since the initramfs files are located in "/"

## updating system
this script has a built-in update system that
it allows you to update the OS automatically by running your script at an early stage of OS boot
this is especially useful for embedded devices
to allow it to work, add the "allow_updatescript" flag to the kernel arguments
### how it works
* for this to work, it is necessary that the "allow_updatescript" flag be in the kernel arguments, you can leave it forever if you are going to use this functionality
* to use the update script, you need to create the "/updatescript" directory in the rootfs from the system itself, and in it the file "updatescript.sh"
* then initiate a reboot of the device
* custom-debian-init-script will run itself "updatescript.sh " from Ruth from initramfs
* then it will delete the entire "/updatescript" directory and reboot the device
* the directory is used so that you can use additional files when updating the system and they are automatically deleted at the end of the update
* please note that your update script will be executed from initramfs and the root directory "/" is initramfs, the real rootfs is currently located in "/updateroot"
* this also means that your additional files from the "updatescript" directory are available to your script via the path "/updateroot/updatescript/*"
* the real root is available to your script for writing on the path "/updateroot"

## additional utilities that should also be in initramfs for this script to work properly
"custom_init_hook.sh" copies the necessary files along with the dependencies to initramfs by itself
* rm
* cp
* grep
* growpart
* resize2fs
* e2fsck
* sfdisk
* flock
* partx
* sed
* awk
* fsck / fsck.ext2 / fsck.ext4
* logsave

## installation
* command: sudo apt install cloud-guest-utils
* command: sudo apt install e2fsprogs
* if you use "earlysplash" (alternative initialization of plymouth), then the "/usr/share/initramfs-tools/scripts/init-premount/plymouth" and "/usr/share/initramfs-tools/scripts/init-bottom/plymouth" files must be DELETED so that they do not conflict with the new initialization of plymouth. this will result in the logo not being displayed at all without earlysplash
* if your initialization system does not trigger plymouth quit, then you can either add this manually (for example, before starting a graphical session) or add a "logoautohide" kernel argument
* copy "custom_init.sh" to "/usr/share/initramfs-tools/init" and make executable
* copy "custom_init_hook.sh" to "/etc/initramfs-tools/hooks/custom_init_hook.sh" and make executable
* command: sudo update-initramfs -u

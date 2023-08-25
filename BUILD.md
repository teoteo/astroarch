This is the main bag to build an aarch64 ISO using arch linux that will be focused around astronomical software like kstars and indi.


**!!! DRAGONS AHEAD !!!**

**If you are here you likely know what you're going to do, this section is strictly for people who wants to test how to build the .img
 I package from scratch**


The guide is for the raspberry pi aarch64 version of arch linux but it should work with any version.

# How to build the ISO


## Prepare the SD card
Insert the SD card into your PC and check under which device name it presents itself (it may be `/dev/sdX` or `/dev/mmcblkX`), the guide will assume
it's `/dev/mmcblk0`, if your PC mounts the card automatically **you need to unmount it before proceeding**

The next commands assume that after `type X` an `enter` is given to confirm the command

- Run fdisk typing `sudo fdisk /dev/mmcblk0`
- type `o` this will wipe all the existing partitions from the card
- type `n` then `p` then `1`, when prompted for the first sector press `enter`, when prompted for the last sector type `+256M` (some guides report `100M` but from
personal experience that is not enough)
- type `t` and then type `0c` to modify the just created partition to `W95FAT LBA`
- type `n` then `p` and take note of the number under `End` this will be used as starting point for the next partition
- type `n` then `p` then `2`, when prompted for the `First sector` check if the default value is bigger than the number you noted before, if it's bigger confirm
with `enter` otherwise add 1 to the number annotated before and use it in this step
- confirm the `Last sector` with enter
- type `w` to write the changes to the card, this will also exit fdisk.
- type `sudo mkfs.vfat /dev/mmcblk0p1` (/dev/sdX1 for sd like devices)
- type `sudo mkfs.ext4 /dev/mmcblk0p2`

At this point the SD card is ready!

## Burn the iso to the SD card

We will proceed with moving the arch iso to the SD card

- `mkdir arch-install && cd arch-install`
- `mkdir boot`
- `mkdir root`
- `wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz`
- `sudo mount /dev/mmcblk0p1 boot/`
- `sudo mount /dev/mmcblk0p2 root/`
- `bsdtar -xpf ArchLinuxARM-rpi-aarch64-latest.tar.gz -C root`
- `sudo mv root/boot/* boot`
- `sudo sed -i 's/mmcblk0/mmcblk1/g' root/etc/fstab`
-  edit the file `root/etc/fstab` adding the following line `/dev/mmcblk1p2  /       ext4    defaults        0       0`
- `sudo umount boot/ root/`

Congratz! Your SD card is ready, insert it into your raspberry and boot it!

## First boot

Connect your raspberry pi to your netowork via an ethernet cable, you can ssh into it after the boot using `ssh alarm@IP_OF_YOUR_RASPBERRY` the password will
be `alarm`

You'll be dropped into `alarm` shell and now we can proceed:
- become sudo with `su -` the password is `root`
- type `curl https://raw.githubusercontent.com/MattBlack85/astroarch/main/boot.sh > boot.sh`
- type `bash boot.sh`

This is the only thing required, the rest of the procedure is fully automated!

## Repackaging .img file

Once astroarch has been fully bootstrapped the image can be repackaged to be distributed, before do so there is a one last step to achieve, the resize_once service must be enabled before repackaging cause otherwise the partition won't be expanded on the first boot, run `sudo systemctl enable resize_once`

Shutdown the raspberry pi, take the card and insert it into another pc, then using `pishrink` follow these steps:
- `sudo dd if=/dev/mmcblk0 of=astroarch.img bs=4M status=progress` this will take a snapshot of the SD card and crete a .img file
- `sudo ./pishrink.sh -z astroarch.img astroarch-X.X.X.img.gz`

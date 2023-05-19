# Setup Instructions for a new System (guideline)

Rough guidelines for setting up a new system with this repo as config.

Credit to [pimey-nixos] for giving me the idea to just write this down as a guide (for myself), and to provide a nice, non-convoluted, useful config as reference.

## Before: General Resources & Links

* pimey's nixos config is pretty nice: [pimey-nixos]
* `nixos-hardware` provides nice nixos-modules for, e.g., laptop models: https://github.com/NixOS/nixos-hardware

### (Optional) Creating a recovery USB stick from a pre-installed Windows

If the system had a pre-installed windows, it probably came without an explicit key, which is instead implicitly available from the recovery partition.
However, since we will be erasing this as well, we need to backup the recovery information before formatting the drive.

1. In Windows, search for something like "recovery medium" ("Wiederherstellungsmedium") in the start menu, and follow the steps to create a bootable USB stick with the recovery information.
2. If desired, use `usbimager` to copy the USB stick to an image file, so the stick can be used for something else again.

## Flashing a bootable USB stick and booting the installer

1. Download installer from official site, check "Older Releases" to also see unstable installers etc.
  - It's also possible to configure & build the installer manually, e.g., to boot a newer kernel (for wifi etc.).
2. Use `usbimager` to flash the iso to an usb stick
3. Boot from the usb stick.
  - If rebooting from windows, might be necessary to hold _shift_ while clicking shutdown, otherwise it might go into "fast boot" mode or something.
  - Will have to turn safe boot off for booting from the usb stick.
  - "Calamares" is the installer version with the nice GUI installer (useful for setting keyboard layout).
4. In the installer, setup wifi, and continue the dialog until the keyboard layout has been set (to de neo2); `setxkbmap` will not work since the installer is probably already running wayland.

## Formatting Partitions

### References:
* Basic ZFS install instructions, pretty useful: https://cheat.readthedocs.io/en/latest/nixos/zfs_install.html
* A bit more advanced ZFS instructions, also useful: https://ipetkov.dev/blog/installing-nixos-and-zfs-on-my-desktop/
* OpenZFS instructions, didn't like them very much: https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS.html

### Basic Steps

Use `gdisk`/`sgdisk` [Arch wiki](https://wiki.archlinux.org/title/GPT_fdisk) for this process.

Use `sgdisk -L` to list partition types.

Just using `gdisk` is super nice, very simple, also contains possibility to list & search for partition types while creating a partition! Use this!

`compression=on` automatically uses the "best" compression format instead; I just use that.
`-o acltype=posixacl` is required wherever `/var` is mounted, also just nice to have in general.

This script is from [pimey-nixos] (`partition.sh`), and contains the basic steps for a ZFS setup with encryption, but no swap.
Probably a good idea to execute these by hand, I like that better (for how rarely I will be doing it).
Also, just a useful reference, but I prefer `gdisk`, a swap partition, and the `acltype`-stuff, so also just a _guideline_.

```bash
#!/usr/bin/env bash
set -euo pipefail

sgdisk -n3:1M:+512M -t3:EF00 $DISK # type EF00 is EFI System Partition
sgdisk -n1:0:0 -t1:BF01 $DISK # type BF01 is "Solaris /usr & Mac ZFS", this is used everywhere

echo "Creating a ZFS setup on ${DISK}"
zpool create \
    -o ashift=12 \
    -o altroot="/mnt" \
    -O mountpoint=none \
    -O encryption=aes-256-gcm \
    -O keyformat=passphrase \
    -O atime=off \
    -O compression=lz4 \
    -O xattr=sa \
    zroot $DISK-part1

zfs create -o mountpoint=legacy zroot/root
zfs create -o mountpoint=legacy zroot/root/nixos
zfs create -o mountpoint=legacy zroot/home

mount -t zfs zroot/root/nixos /mnt
mkdir /mnt/home
mount -t zfs zroot/home /mnt/home

mkfs.vfat $DISK-part3
mkdir /mnt/boot
mount $DISK-part3 /mnt/boot
```

### Swap

If swap is desired, it has to be an unencrypted, non-ZFS partition/mountpoint.
This is not very cool, but otherwise hibernate is impossible/can break stuff.

### Swap size:
* Without hibernate, about sqrt(RAM); so 32GB Ram -> ~6-8 GB swap
* With hibernate, about RAM + sqrt(RAM); so 32GB Ram -> ~38-40 GB swap
* Got these numbers from some website, I think these were recommended Ubuntu numbers or something.

```bash
mkswap /dev/...
swapon /dev/...
```

## Set Up Installation

```bash
mkdir -p /mnt/home/felix
cd /mnt/home/felix
git clone https://github.com/futile/nix-config.git nixos # works, since repo is public :)
cd
nixos-generate-config --root /mnt
```

Wrangle generated files in `/mnt/etc/nixos` into this repo, creating a new host in `/hosts`, and adding an entry to `flake.nix`.

[pimey-nixos]: https://github.com/pimeys/nixos

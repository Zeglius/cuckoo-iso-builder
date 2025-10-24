#!/bin/bash

PS4='[$LINENO]+ '
set -x
shopt -s nullglob

SQUASHFS_CTR_IMG_ROOTFS=/rootfs
GRUB_FILE_PATH=${GRUB_FILE_PATH:?}
OUTPUT_ISO_FILE=/out/titanoboa.iso
export DRACUT_NO_XATTR=1

die() {
    echo >&2 "ERROR [${BASH_LINENO[1]}]: $*"
    exit 1
}

breakpoint() {
    echo >&2 "BREAKPOINT HIT"
    exit 0
}

dnf install --setopt=install_weak_deps=False -yq \
    dracut \
    dracut-live \
    kernel \
    grub2-efi \
    shim \
    xorriso \
    mtools \
    dosfstools \
    squashfs-tools

# Remove fallback efi
cp /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi # NOTE: remove this line if breaks bootloader

# Set grubx64.efi in the same directory as the shim.efi.
# In reality, EFI/BOOT/BOOTX64.EFI its a copy of shim.efi, and the later will default to boot the grubx64.efi in the same directory.
cp /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/grubx64.efi

mkdir -p /work
cd /work || die "Failed to create and change directory /work"

# Prepare directories
mkdir -p iso_files/{boot,LiveOS}

# Build initrd
kver=$(find /usr/lib/modules -maxdepth 1 -printf "%P" | head -1)
dracut \
    --kver="$kver" \
    --zstd \
    --reproducible \
    --no-hostonly \
    --no-hostonly-cmdline \
    --add "dmsquash-live dmsquash-live-autooverlay" \
    --force \
    iso_files/boot/initramfs.img

# Copy over the kernel
cp /boot/vmlinuz* iso_files/boot/vmlinuz

# Copy grub.cfg.
# We put the cfg file under EFI/fedora in the ISO 9660 filesystem
# because grubx64.efi is hardcoded to point there.
mkdir -p iso_files/EFI/fedora
cp "$GRUB_FILE_PATH" iso_files/EFI/fedora/grub.cfg

# Generate squashfs
mksquashfs "$SQUASHFS_CTR_IMG_ROOTFS" iso_files/LiveOS/squashfs.img -all-root -noappend

# Generate uefi.img
truncate -s 500M uefi.img
mkfs.fat -F32 uefi.img
mcopy -v -i uefi.img -s /boot/efi/EFI ::

# Generate iso
mkdir -p "$(dirname "${OUTPUT_ISO_FILE}")"
xorriso -as mkisofs \
    -R \
    -V "titanoboa_boot" \
    -partition_offset 16 \
    -appended_part_as_gpt \
    -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B ./uefi.img \
    -iso_mbr_part_type EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 \
    -e --interval:appended_partition_2:all:: \
    -no-emul-boot \
    -iso-level 3 \
    -o "${OUTPUT_ISO_FILE}" \
    iso_files

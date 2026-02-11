#!/bin/bash

PS4='[$LINENO]+ '
set -xeo pipefail
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
    grub2-efi-x64-cdboot \
    shim \
    xorriso \
    mtools \
    dosfstools \
    squashfs-tools \
    jq \
    /usr/lib/grub/i386-pc

# Prepare directories
mkdir -p /work/iso_files/{boot,LiveOS,images/pxeboot}

# Generate squashfs
mksquashfs "$SQUASHFS_CTR_IMG_ROOTFS" /work/iso_files/LiveOS/squashfs.img -all-root -noappend -e sysroot -e ostree

# Build initrd
kver=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version')
DRACUT_NO_XATTR=1 dracut \
    --kver="$kver" \
    --zstd \
    --reproducible \
    --no-hostonly \
    --no-hostonly-cmdline \
    --add "dmsquash-live dmsquash-live-autooverlay" \
    --force \
    /work/iso_files/images/pxeboot/initrd.img

# Copy over the kernel
cp -av /usr/lib/modules/"$kver"/vmlinuz /work/iso_files/images/pxeboot/vmlinuz

# Copy GRUB modules
mkdir -p /work/iso_files/boot/grub2
cp -avT /usr/lib/grub/i386-pc /work/iso_files/boot/grub2/i386-pc

# Copy EFI dir to /work
cp -avT /boot/efi/EFI /work/EFI

# Remove fallback efi
cp -avT /work/EFI/fedora/grubx64.efi /work/EFI/BOOT/fbx64.efi

# Copy grub.cfg to each bootloader
for dir in /work/EFI/*/ /work/iso_files/boot/grub2/; do
    cp "$GRUB_FILE_PATH" "$dir"
done

# Copy EFI to iso_files/EFI, because fedora requires it to be in the root of the ISO
cp -avT /work/EFI /work/iso_files/EFI

# Generate uefi.img
truncate -s 500M /work/uefi.img
mkfs.fat -F32 /work/uefi.img
mcopy -v -i /work/uefi.img -s /work/EFI ::

# Generate iso
mkdir -p "$(dirname "${OUTPUT_ISO_FILE}")"
xorriso -as mkisofs \
    -R \
    -V "titanoboa_boot" \
    -partition_offset 16 \
    -appended_part_as_gpt \
    -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B /work/uefi.img \
    -iso_mbr_part_type EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 \
    -e --interval:appended_partition_2:all:: \
    -no-emul-boot \
    -iso-level 3 \
    -o "${OUTPUT_ISO_FILE}" \
    /work/iso_files

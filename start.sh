#!/usr/bin/env bash

PS4='[$LINENO]+ '
set -x

_SCRIPTDIR=$(dirname "$0")

SQUASHFS_CTR_IMG=${SQUASHFS_CTR_IMG:?}

# Pull the image just to make sure it exists
podman image exists "${SQUASHFS_CTR_IMG}" || podman pull "${SQUASHFS_CTR_IMG}"

podman run \
    --rm \
    -it \
    --security-opt label=type:unconfined_t \
    --env GRUB_FILE_PATH=/grub.cfg \
    -v "$_SCRIPTDIR"/grub.cfg:/grub.cfg \
    -v "$_SCRIPTDIR"/build_iso.sh:/build_iso.sh \
    -v ./out:/out \
    --mount type=image,src="$SQUASHFS_CTR_IMG",dst=/rootfs \
    quay.io/fedora/fedora:42 /build_iso.sh

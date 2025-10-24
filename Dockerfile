ARG SQUASHFS_CTR_IMG=${SQUASHFS_CTR_IMG:-ghcr.io/ublue-os/bluefin}
ARG ISO_NAME=${ISO_NAME:-titanoboa.iso}


FROM ${SQUASHFS_CTR_IMG} AS squashfs_ctr_img_rootfs


FROM quay.io/fedora/fedora:latest AS boostrap
ARG SQUASHFS_CTR_IMG
ARG ISO_NAME
# START Build script params
ENV GRUB_FILE_PATH=/grub.cfg
ENV OUTPUT_ISO_FILE=/${ISO_NAME}
ENV DRACUT_NO_XATTR=1
ENV SQUASHFS_CTR_IMG_ROOTFS=/rootfs
# END Build script params
RUN --mount=type=cache,destination=/var/cache/libdnf \
    dnf install -yq \
    dracut \
    dracut-live \
    kernel \
    grub2-efi \
    shim \
    xorriso \
    mtools \
    dosfstools \
    squashfs-tools
COPY ./grub.cfg /grub.cfg
COPY ./build_iso.sh /build_iso.sh
RUN --mount=type=cache,destination=/var/cache/libdnf \
    --mount=type=bind,from=squashfs_ctr_img_rootfs,target=/rootfs \
    /build_iso.sh

FROM scratch AS iso
COPY --from=boostrap /${ISO_NAME} /${ISO_NAME}

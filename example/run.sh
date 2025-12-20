#!/bin/bash
set -x

SQUASHFS_CTR_IMG=localhost/myimage:latest

cd "$(dirname "$0")" || exit 1

podman build -t "$SQUASHFS_CTR_IMG" -f ./Containerfile .

cd ..

SQUASHFS_CTR_IMG="$SQUASHFS_CTR_IMG" ./start.sh

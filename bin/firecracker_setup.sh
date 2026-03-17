#!/bin/bash

# 1. Setup target directory
TARGET_DIR="${1:-/opt/karyon/firecracker}"
sudo mkdir -p "$TARGET_DIR"
sudo chown $USER:$USER "$TARGET_DIR" # Ensure you can write to it without sudo every time

ARCH="$(uname -m)"
release_url="https://github.com/firecracker-microvm/firecracker/releases"
latest_version=$(basename $(curl -fsSLI -o /dev/null -w %{url_effective} ${release_url}/latest))
CI_VERSION=${latest_version%.*}

# Get Kernel Key
latest_kernel_key=$(curl -s "http://spec.ccfc.min.s3.amazonaws.com/?prefix=firecracker-ci/$CI_VERSION/$ARCH/vmlinux-&list-type=2" \
    | grep -oP "(?<=<Key>)(firecracker-ci/$CI_VERSION/$ARCH/vmlinux-[0-9]+\.[0-9]+\.[0-9]{1,3})(?=</Key>)" \
    | sort -V | tail -1)

# Download kernel directly to target as 'vmlinux'
wget -O "$TARGET_DIR/vmlinux" "https://s3.amazonaws.com/spec.ccfc.min/${latest_kernel_key}"

# Get Rootfs Key
latest_ubuntu_key=$(curl -s "http://spec.ccfc.min.s3.amazonaws.com/?prefix=firecracker-ci/$CI_VERSION/$ARCH/ubuntu-&list-type=2" \
    | grep -oP "(?<=<Key>)(firecracker-ci/$CI_VERSION/$ARCH/ubuntu-[0-9]+\.[0-9]+\.squashfs)(?=</Key>)" \
    | sort -V | tail -1)

# Download and Extract (Temporary local work for squashfs manipulation)
wget -O "temp_rootfs.squashfs" "https://s3.amazonaws.com/spec.ccfc.min/$latest_ubuntu_key"
unsquashfs temp_rootfs.squashfs

# Patch SSH keys
ssh-keygen -f "$TARGET_DIR/id_rsa" -N ""
mkdir -p squashfs-root/root/.ssh
cp -v "$TARGET_DIR/id_rsa.pub" squashfs-root/root/.ssh/authorized_keys

# Create the final ext4 image in the target directory
truncate -s 1G "$TARGET_DIR/rootfs.ext4"
sudo mkfs.ext4 -d squashfs-root -F "$TARGET_DIR/rootfs.ext4"

# Cleanup temp files
rm -rf squashfs-root temp_rootfs.squashfs

# Set the exports for the current session and print them for your .bashrc
echo "--- CONFIGURATION COMPLETE ---"
export KARYON_FIRECRACKER_KERNEL="$TARGET_DIR/vmlinux"
export KARYON_FIRECRACKER_ROOTFS="$TARGET_DIR/rootfs.ext4"

echo "export KARYON_FIRECRACKER_KERNEL=$KARYON_FIRECRACKER_KERNEL"
echo "export KARYON_FIRECRACKER_ROOTFS=$KARYON_FIRECRACKER_ROOTFS"
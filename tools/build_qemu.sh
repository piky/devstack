#!/usr/bin/env bash
#
# build_qemu.sh
#
# Install QEMU and its dependencies.
#

# Echo commands
set -o xtrace

# Exit on error to stop unexpected errors
set -o errexit

function usage {
    echo "$0 - Install QEMU from tar releases."
    echo ""
    echo "Usage: $0 <QEMU_VERSION>"
    echo ""
    echo "Example: $0 2.1.0"
}

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import common functions and variables
source $TOP_DIR/functions
source $TOP_DIR/stackrc

# Find the cache dir
FILES=$TOP_DIR/files

# Nova hypervisor installed from sources directory
HYP_INSTALL_DIR=$DEST/hyp_inst_src

if [[ -z "$1" ]]; then
    usage
    exit 1
fi

QEMU_VERSION=$1

echo "Installing QEMU $QEMU_VERSION"

# If this value is not user defined, use the official link
QEMU_URL_BASE=${QEMU_URL_BASE:-http://wiki.qemu-project.org/download/}

# QEMU is released as .tar.bz2
QEMU_FILE=qemu-"$QEMU_VERSION".tar.bz2
QEMU_DIR="$DEST"/qemu-"$QEMU_VERSION"

QEMU_URL="$QEMU_URL_BASE""$QEMU_FILE"

echo "Installing QEMU dependencies"
if is_ubuntu; then
    sudo apt-get build-dep qemu -y
    if [[ ${DISTRO} =~ (precise) ]]; then
        sudo apt-get install dh-autoreconf -y
    fi
elif is_fedora || is_suse; then
    install_package yum-utils
    sudo yum-builddep qemu -y
fi

echo "Downloading the QEMU sources"
wget -N "$QEMU_URL" -P "$FILES"

if [[ ! -d "$QEMU_DIR" || "$RECLONE" = "yes" ]]; then
    echo "Configuring QEMU"
    tar -xf "$FILES"/"$QEMU_FILE" -C "$DEST"
    cd "$QEMU_DIR"
    ./configure --target-list=`uname -m`-softmmu --prefix="$HYP_INSTALL_DIR"
fi

echo "Compiling QEMU"
cd "$QEMU_DIR"
make -j"$(nproc)"
sudo make install

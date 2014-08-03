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

if [[ -z "$1" ]]; then
    usage
    exit 1
fi

QEMU_VERSION=$1

RECLONE=$(trueorfalse False $RECLONE)

echo "Installing QEMU $QEMU_VERSION"

# If this value is not user defined, use the official link
QEMU_URL_BASE=${QEMU_URL_BASE:-http://wiki.qemu-project.org/download/}

# QEMU is released as .tar.bz2
QEMU_FILE=qemu-"$QEMU_VERSION".tar.bz2
QEMU_SIG=qemu-"$QEMU_VERSION".tar.bz2.sig
QEMU_DIR="$DEST"/qemu-"$QEMU_VERSION"

QEMU_SRC_URL="$QEMU_URL_BASE""$QEMU_FILE"
QEMU_SIG_URL="$QEMU_URL_BASE""$QEMU_SIG"

echo "Installing QEMU build dependencies"
if is_ubuntu; then
    sudo apt-get build-dep qemu -y
    install_package gnupg2
    if [[ ${DISTRO} =~ (precise) ]]; then
        sudo apt-get install dh-autoreconf -y
    fi
elif is_fedora || is_suse; then
    install_package yum-utils gnupg2
    sudo yum-builddep qemu -y
fi

echo "Downloading the QEMU sources"
wget -N "$QEMU_SRC_URL" -P "$FILES"
echo "QEMU sources signature check"
wget -N "$QEMU_SIG_URL" -P "$FILES"
gpg2 --recv-keys --keyserver keys.fedoraproject.org 0xF108B584
cd "$FILES"
gpg2 --verify "$QEMU_SIG" "$QEMU_FILE"

if [[ ! -d "$QEMU_DIR" || "$RECLONE" = "True" ]]; then
    echo "Configuring QEMU"
    tar -xf "$FILES"/"$QEMU_FILE" -C "$DEST"
    cd "$QEMU_DIR"
    ./configure --target-list=`uname -m`-softmmu --prefix=/usr
fi

echo "Compiling QEMU"
cd "$QEMU_DIR"
make -j"$(nproc)"
sudo make install

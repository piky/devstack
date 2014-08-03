#!/usr/bin/env bash
#
# build_libvirt.sh
#
# Install libvirt and its dependencies.
#

# Echo commands
set -o xtrace

# Exit on error to stop unexpected errors
set -o errexit

function usage {
    echo "$0 - Install libvirt from tar releases."
    echo ""
    echo "Usage: $0 <LIBVIRT_VERSION>"
    echo ""
    echo "Example: $0 1.2.7"
    exit 1
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
fi

LIBVIRT_VERSION=$1

echo "Installing libvirt $LIBVIRT_VERSION"

# If this value is not user defined, use the official link
LIBVIRT_URL_BASE=${LIBVIRT_URL_BASE:-http://libvirt.org/sources/}

# libvirt is released as .tar.gz
LIBVIRT_FILE=libvirt-"$LIBVIRT_VERSION".tar.gz
LIBVIRT_DIR="$DEST"/libvirt-"$LIBVIRT_VERSION"

LIBVIRT_URL="$LIBVIRT_URL_BASE""$LIBVIRT_FILE"

echo "Installing libvirt dependencies"
if is_ubuntu; then
    sudo apt-get build-dep libvirt -y
    install_package python-guestfs
elif is_fedora || is_suse; then
    sudo yum install yum-utils -y
    sudo yum-builddep libvirt -y
    install_package python-libguestfs
fi

echo "Downloading the libvirt sources"
wget -N "$LIBVIRT_URL" -P "$FILES"

if [[ ! -d "$LIBVIRT_DIR" || "$RECLONE" = "yes" ]]; then
    echo "Configuring libvirt"
    tar -xf "$FILES"/"$LIBVIRT_FILE" -C "$DEST"
    cd "$LIBVIRT_DIR"
    ./configure --prefix="$DEST" --localstatedir=/var --libdir="$DEST"/lib --sysconfdir=/etc
fi

echo "Compiling libvirt"
cd "$LIBVIRT_DIR"
make -j"$(nproc)"
sudo make install

if is_ubuntu; then
    if [[ ! -f /etc/init/libvirtd.conf ]]; then
        sudo cp daemon/libvirtd.upstart /etc/init/libvirtd.conf
        sudo sed -i "s/\/usr\/sbin/"$(echo $LIBVIRT_DIR | sed 's/\//\\\//g')"\/daemon/g" /etc/init/libvirtd.conf
    fi
elif is_fedora; then
    if [[ ! -f /etc/init.d/libvirtd ]]; then
        sudo cp daemon/libvirtd.init /etc/init.d/libvirtd
    fi
fi
if [[ ! -f /usr/share/polkit-1/actions/org.libvirt.policy ]]; then
    sudo cp daemon/libvirtd.policy /usr/share/polkit-1/actions/org.libvirt.policy
fi

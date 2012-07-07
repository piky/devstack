#!/bin/bash

# **get_openvz_image.sh**

# Download and prepare Ubuntu OpenVZ image

CACHEDIR=${CACHEDIR:-/opt/stack/cache}

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import configuration
. $TOP_DIR/openrc

# TODO(deva): Find a better way to get admin user/tenant/pass
OS_USERNAME='admin'
OS_TENANT_NAME='admin'

# Exit on error to stop unexpected errors
set -o errexit
set -o xtrace

usage() {
   echo "Usage: $0 - Download and prepare Ubuntu OpenVZ image"
   echo ""
   exit 1
}

# Clean up any resources that may be in use
cleanup() {
    set +o errexit

    # Mop up temporary files
    if [ -n "$IMG_FILE_TMP" -a -e "$IMG_FILE_TMP" ]; then
        rm -f $IMG_FILE_TMP
    fi

    # Kill ourselves to signal any calling process
    trap 2; kill -2 $$
}

while getopts hr: c; do
    case $c in
        h)  usage
            ;;
    esac
done
shift `expr $OPTIND - 1`

IMG_FILE="ubuntu-11.10-x86_64.tar.gz"
IMG_FILE_URL="http://download.openvz.org/template/precreated/$IMG_FILE"
IMG_FILE_TMP=`mktemp $IMG_FILE.XXXXXX`

trap cleanup SIGHUP SIGINT SIGTERM SIGQUIT EXIT

# download the image
wget -nv -O $IMG_FILE_TMP $IMG_FILE_URL

# load the image into glance
glance image-create --is-public 1 --disk-format ami --name vz-template-ubuntu-11_10 < $IMG_FILE_TMP
rm -f $IMG_FILE_TMP

trap - SIGHUP SIGINT SIGTERM SIGQUIT EXIT

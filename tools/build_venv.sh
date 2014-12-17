#!/usr/bin/env bash
# tools/build_venv.sh - Build a Python Virtual Envirnment
#
# build_venv.sh venv-path [package [...]]

set -o errexit
set -o nounset

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0")/.. && pwd)
FILES=$TOP_DIR/files

# Import common functions
source $TOP_DIR/functions

GetDistro

VENV_PACKAGES=$FILES/venv-requirements.txt

DEST=${1:?venv-path required}
shift
PACKAGES="$@"

# INSTALL_PACKAGES is a list of packages to install into the venv
if [[ -r $VENV_PACKAGES ]]; then
    INSTALL_PACKAGES=$(cat $VENV_PACKAGES)
fi

set +o nounset
# Get system prereqs
install_package $(get_packages venv)

# test for virtualenv installed!

virtualenv $DEST
. $DEST/bin/activate
set -o nounset
set -o xtrace

for pkg in ${INSTALL_PACKAGES,/ } ${PACKAGES}; do
    pip install $pkg
done

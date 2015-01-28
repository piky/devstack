#!/usr/bin/env bash
#
# **tools/build_venv.sh** - Build a Python Virtual Envirnment
#
# build_venv.sh venv-path wheel-dir [package [...]]
#
# Assumes:
# - a useful pip is installed
# - virtualenv will be installed by pip
# - installs basic common prereq packages that require compilation
#   to allow quick copying of resulting venv as a baseline

set -o errexit
set -o nounset

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0")/.. && pwd)
FILES=$TOP_DIR/files

# Import common functions
source $TOP_DIR/functions

GetDistro

VENV_PACKAGE_FILE=$FILES/venv-requirements.txt

VENV_DEST=${1:?venv-path required}
shift
export WHEELHOUSE=${1:-.wheelhouse}
shift
PACKAGES="$@"

# INSTALL_PACKAGES is a list of packages to install into the venv
if [[ -r $VENV_PACKAGE_FILE ]]; then
    INSTALL_PACKAGES=$(cat $VENV_PACKAGE_FILE)
fi

set +o nounset
# Get system prereqs
install_package $(get_packages venv)

virtualenv $VENV_DEST

# Install modern pip
$VENV_DEST/bin/pip install -U pip wheel

export PIP_WHEEL_DIR=${PIP_WHEEL_DIR:-$WHEELHOUSE}
export PIP_FIND_LINKS=${PIP_FIND_LINKS:-file://$WHEELHOUSE}
for pkg in ${INSTALL_PACKAGES,/ } ${PACKAGES}; do
    $VENV_DEST/bin/pip wheel $pkg
    #pip_install_venv $VENV_DEST $pkg
done

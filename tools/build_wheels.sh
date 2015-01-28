#!/usr/bin/env bash
#
# **tools/build_wheels.sh** - Build a cache of Python wheels
#
# build_wheels.sh wheel-dir [package [...]]
#
# Builds wheels for all virtual env requirements listed in
# ``venv-requirements.txt`` plus any supplied on the command line.
#
# Assumes ``tools/install_pip.sh`` has been run and a suitable pip/setuptools is available.

# If TOP_DIR is set we're being sourced rather than running stand-alone
# or in a sub-shell
if [[ -z "$TOP_DIR" ]]; then

    set -o errexit
    set -o nounset

    # Keep track of the devstack directory
    TOP_DIR=$(cd $(dirname "$0")/.. && pwd)
    FILES=$TOP_DIR/files

    # Import common functions
    source $TOP_DIR/functions

    GetDistro

    trap err_trap ERR

fi

# Exit on any errors so that errors don't compound
function err_trap {
    local r=$?
    set +o xtrace

    rm -rf $VENV_DEST

    exit $r
}

# Get system prereqs
install_package $(get_packages venv)

# Get modern ``virtualenv``
pip_install virtualenv

export WHEELHOUSE=${1:-.wheelhouse}
export PIP_WHEEL_DIR=${PIP_WHEEL_DIR:-$WHEELHOUSE}
export PIP_FIND_LINKS=${PIP_FIND_LINKS:-file://$WHEELHOUSE}
shift

MORE_PACKAGES="$@"

# Prepare the workspace
VENV_PACKAGE_FILE=$FILES/venv-requirements.txt
VENV_DEST=$(mktemp -d ds-XXXX)
virtualenv $VENV_DEST

# Install modern pip and wheel
$VENV_DEST/bin/pip install -U pip wheel

# VENV_PACKAGES is a list of packages we want to pre-install
if [[ -r $VENV_PACKAGE_FILE ]]; then
    VENV_PACKAGES=$(grep -v '^#' $VENV_PACKAGE_FILE)
fi

for pkg in ${VENV_PACKAGES,/ } ${MORE_PACKAGES}; do
    $VENV_DEST/bin/pip wheel $pkg
done

rm -rf $VENV_DEST

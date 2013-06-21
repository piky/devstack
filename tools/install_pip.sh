#!/usr/bin/env bash

# **install_pip.sh**

# install_pip.sh [--force]
#
# Update pip and friends to a known common version.

FORCE=$1

GOOD_PIP_VERSION="1.4"

# If TOP_DIR is set we're being sourced rather than running stand-alone
# or in a sub-shell
if [[ -z "$TOP_DIR" ]]; then
    # Keep track of the devstack directory
    TOP_DIR=$(cd $(dirname "$0")/.. && pwd)

    # Import common functions
    source $TOP_DIR/functions

    # Determine what system we are running on.  This provides ``os_VENDOR``,
    # ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
    # and ``DISTRO``
    GetDistro
fi

# Import common functions
source $TOP_DIR/functions

GetDistro
echo "Distro: $DISTRO"

function get_versions() {
    PIP=$(which pip 2>/dev/null || which pip-python 2>/dev/null)
    if [[ -n $PIP ]]; then
        DISTRIBUTE_VERSION=$($PIP freeze | grep 'distribute==')
        SETUPTOOLS_VERSION=$($PIP freeze | grep 'setuptools==')
        PIP_VERSION=$($PIP --version | awk '{ print $2}')
        echo "pip: $PIP_VERSION  setuptools: $SETUPTOOLS_VERSION  distribute: $DISTRIBUTE_VERSION"
    fi
}

function setuptools_from_source() {
    curl https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py \
	| sudo python
}

function pip_from_source() {
    # try to be idempotent by removing old build dires and reinstalling
    sudo rm -rf /tmp/pip-build*
    curl https://raw.github.com/pypa/pip/master/contrib/get-pip.py \
	| sudo python - --force-reinstall
}


get_versions
if [[ -z $PIP || "$PIP_VERSION" != "$GOOD_PIP_VERSION" || -n $FORCE ]]; then
   
    setuptools_from_source
    pip_from_source

    get_versions
fi

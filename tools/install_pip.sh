#!/usr/bin/env bash

# **install_pip.sh**

# install_pip.sh [--force]
#
# Update pip and friends to a known common version
# Removes any vendor-packaged pip/setuptools/distribute and re-installs
# from source

FORCE=$1

GOOD_PIP_VERSION="1.4"

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

# Change dir to top of devstack
cd $TOP_DIR

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
    curl https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py | sudo python
}

function pip_from_source() {
    curl https://raw.github.com/pypa/pip/master/contrib/get-pip.py | sudo python
}


get_versions
if [[ -z $PIP || "$PIP_VERSION" != "$GOOD_PIP_VERSION" || -n $FORCE ]]; then

    # Eradicate any and all system packages
    uninstall_package python-setuptools python-pip
    # go looking for more???

    setuptools_from_source
    pip_from_source

    get_versions
fi

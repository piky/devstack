#!/usr/bin/env bash

# **install_pip.sh**

# install_pip.sh [--force]
#
# Update pip and friends to a known common version

# Assumptions:
# - currently we try to leave the system setuptools alone, install
#   the system package if it is not already present
# - update pip to $INSTALL_PIP_VERSION

FORCE=$1

INSTALL_PIP_VERSION="1.4"

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

# Change dir to top of devstack
cd $TOP_DIR

# Import common functions
source $TOP_DIR/functions

FILES=$TOP_DIR/files

SETUPTOOLS_EZ_SETUP_URL=https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py
PIP_GET_PIP_URL=https://raw.github.com/pypa/pip/master/contrib/get-pip.py
PIP_TAR_URL=https://pypi.python.org/packages/source/p/pip/pip-$INSTALL_PIP_VERSION.tar.gz

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
    if [[ ! -r $FILES/ez_setup.py ]]; then
        (cd $FILES; \
         curl -OR $SETUPTOOLS_EZ_SETUP_URL; \
        )
    fi
    sudo python $FILES/ez_setup.py
}

function pip_from_source() {
    if [[ ! -r $FILES/get-pip.py ]]; then
        (cd $FILES; \
            curl $PIP_GET_PIP_URL; \
        )
    fi
    sudo python $FILES/get-pip.py
}

function pip_from_tarball() {
    curl -O $PIP_TAR_URL
    tar xvfz pip-$INSTALL_PIP_VERSION.tar.gz
    cd pip-$INSTALL_PIP_VERSION
    sudo python setup.py install
}

if ! python -c "import setuptools"; then
    install_package python-setuptools
fi

get_versions
if [[ -z $PIP || "$PIP_VERSION" != "$INSTALL_PIP_VERSION" || -n $FORCE ]]; then

    # Eradicate any and all system packages
    uninstall_package python-pip

    pip_from_tarball

    get_versions
fi

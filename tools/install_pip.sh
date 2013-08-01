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

FILES=$TOP_DIR/files

SETUPTOOLS_EZ_SETUP_URL=https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py
PIP_GET_PIP_URL=https://raw.github.com/pypa/pip/master/contrib/get-pip.py
PIP_TAR_URL=https://pypi.python.org/packages/source/p/pip/pip-$GOOD_PIP_VERSION.tar.gz

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
    sudo python $FILES/get-pip.py.py
}

function pip_from_tarball() {
    curl -O $PIP_TAR_URL
    tar xvfz pip-$GOOD_PIP_VERSION.tar.gz
    cd pip-$GOOD_PIP_VERSION
    sudo python setup.py install
}

get_versions
if [[ -z $PIP || "$PIP_VERSION" != "$GOOD_PIP_VERSION" || -n $FORCE ]]; then

    # Eradicate any and all system packages
    uninstall_package python-setuptools python-pip
    # go looking for more???

    setuptools_from_source
    pip_from_tarball

    get_versions
fi

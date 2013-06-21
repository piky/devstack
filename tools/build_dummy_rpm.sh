#!/usr/bin/env bash 

set -x

# **build_dummy_rpm.sh**

# Some distributions (Fedora based) have a pip/setuptools that
# automatically installs packages into /usr (rather than somewhere
# private like /usr/local).  The packaged pip will therefore overwrite
# packaged files from other rpms; and rpm packaged files will
# overwrite pip-installed files ... the end result is usually a mess.
#
# We can't remove python-setuptools rpm package, because its
# dependency flows through to many other packages.  But we can't leave
# it around or it gets in the way.
#
# This creates a dummy rpm which provides & obsoletes
# python-setuptools and python-pip.  These packages are then installed
# from upstream directly by devstack.
#
# build_dummy_rpm.sh

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

install_package rpm-build

rpmbuild -bb ${TOP_DIR}/tools/rpm-dummy/devstack-dummy.${DISTRO}.spec

devstack_dummy_rpm=~/rpmbuild/RPMS/x86_64/devstack-dummy-1.x86_64.rpm

if [[ ! $(rpm -qi devstack-dummy) ]]; then
    install_package --obsoletes -y "${devstack_dummy_rpm}"
else
    sudo yum reinstall --obsoletes -y "${devstack_dummy_rpm}"
fi

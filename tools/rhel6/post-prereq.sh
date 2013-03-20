#!/usr/bin/env bash

# **rhel6 post-prereq**

# Extra workarounds for rhel6

# Pre-install dbus and restart; otherwise it may get dragged in as a
# dependency and you may hit a bug where the uuid isn't generated
# because the service was never started (PR#598200), causing issues
# for Nova stopping later on complaining that
# '/var/lib/dbus/machine-id' doesn't exist.
install_package dbus
service messagebus restart

# RH#924038; keyring fails without this pre-installed
pip_install hgtools

# python-crypto conflicts with required pycrypto
uninstall_package python-crypto
# and requires gcc to build...
install_package gcc
# pre-install it now
pip_install pycrypto

# remove local version & install pip version of lxml for nova which
# wants >=2.3
uninstall_package python-lxml
sudo yum-builddep -y python-lxml
pip_install lxml

# many of the python-* openstack projects specify prettytable <0.7,
# but some other pip installations may have unversioned prettytable
# requirements; so if they install first then we end up with a later
# verison which therefore causes dependency issues later.  Installing
# the RHEL one gives up 0.6(something) which keeps everyone happy.
install_package python-prettytable


# Local variables:
# mode: Shell-script
# End:

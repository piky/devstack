#!/usr/bin/env bash

# **rhel6 post-prereq**

# Extra workarounds for rhel6

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

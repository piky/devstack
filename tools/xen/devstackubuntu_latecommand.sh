#!/bin/bash
set -eux

# Install basics
apt-get update
apt-get install -y cracklib-runtime curl wget ssh openssh-server tcpdump ethtool
apt-get install -y git sudo python-netaddr coreutils

curl --no-sessionid -L -o tools.deb @XS_TOOLS_URL@
dpkg -i tools.deb
rm tools.deb

# Need to set barrier=0 to avoid a Xen bug
# https://bugs.launchpad.net/ubuntu/+source/linux/+bug/824089
sed -i -e 's/errors=/barrier=0,errors=/' /etc/fstab

# Allow root to login with a password
sed -i -e 's/.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config


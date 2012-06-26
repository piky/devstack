#!/bin/bash
#
# install_ubuntu_template.sh
#
# this creates Ubuntu Server 32bit and 64bit templates
# on Xenserver 5.6.x, 6.0.x and 6.1.x
# Net install only
#
# Original Author: David Markey <david.markey@citrix.com>
# Author: Renuka Apte <renuka.apte@citrix.com>
#
# This is not an officially supported guest OS on XenServer 6.0.2 and below.

BASE_DIR=$(cd $(dirname "$0") && pwd)
source $BASE_DIR/../../../localrc

PRESEED_URL=${1:-"http://images.ansolabs.com/devstackubuntupreseed.cfg"}

TEMPLATE_NAME=${TEMPLATE_NAME:-"Ubuntu 12.04 for DevStack"}
DEBIAN_RELEASE=${DEBIAN_RELEASE:-"precise"}

NETINSTALL_LOCALE=${NETINSTALL_LOCALE:-en_US}
NETINSTALL_KEYBOARD=${NETINSTALL_KEYBOARD:-us}
NETINSTALL_IFACE=${NETINSTALL_IFACE:-eth3}

BUILTIN_TEMPLATE=$(xe template-list name-label=Debian\ Squeeze\ 6.0\ \(32-bit\) --minimal)
if [[ -z $BUILTIN_TEMPLATE ]]; then
    echo "Cant find Squeeze 32bit template."
    exit 1
fi

arches=("32-bit" "64-bit")
for arch in ${arches[@]} ; do
    echo "Attempting $TEMPLATE_NAME ($arch)"
    if [[ -n $(xe template-list name-label="$TEMPLATE_NAME ($arch)" params=uuid --minimal) ]] ; then
        echo "$TEMPLATE_NAME ($arch)" already exists, Skipping
    else
        if [ -z $NETINSTALLIP ]; then
            echo "NETINSTALLIP not set in localrc"
            exit 1
        fi
        # Some of these settings can be found in example preseed files
        # however these need to be answered before the netinstall
        # is ready to fetch the preseed file, and as such must be here
        # to get a fully automated install
        pvargs="-- quiet console=hvc0 partman/default_filesystem=ext3 locale=${NETINSTALL_LOCALE} console-setup/ask_detect=false keyboard-configuration/layoutcode=${NETINSTALL_KEYBOARD} netcfg/choose_interface=${NETINSTALL_IFACE} netcfg/get_hostname=os netcfg/get_domain=os auto url=${PRESEED_URL}"
        if [ "$NETINSTALLIP" != "dhcp" ]; then
            netcfgargs="netcfg/disable_autoconfig=true netcfg/get_nameservers=${NAMESERVERS} netcfg/get_ipaddress=${NETINSTALLIP} netcfg/get_netmask=${NETMASK} netcfg/get_gateway=${GATEWAY} netcfg/confirm_static=true"
            pvargs="${pvargs} ${netcfgargs}"
        fi
        new_uuid=$(xe vm-clone uuid=$BUILTIN_TEMPLATE new-name-label="$TEMPLATE_NAME ($arch)")
        xe template-param-set uuid=$new_uuid \
         other-config:install-methods=http,ftp \
         other-config:install-repository=http://archive.ubuntu.net/ubuntu \
         PV-args="$pvargs" \
         other-config:debian-release="$DEBIAN_RELEASE" \
         other-config:default_template=true

        if [[ "$arch" == "32-bit" ]] ; then
            xe template-param-set uuid=$new_uuid \
                other-config:install-arch="i386"
        else
            xe template-param-set uuid=$new_uuid \
                other-config:install-arch="amd64"
        fi
        echo "Success"
    fi
done

echo "Done"

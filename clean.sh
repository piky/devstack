#!/usr/bin/env bash

# **clean.sh**

# ``clean.sh`` does its best to eradicate traces of a Grenade
# run except for the following:
# - both base and target code repos are left alone
# - packages (system and pip) are left alone

# This means that all data files are removed.  More??

# Keep track of the current devstack directory.
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions

FILES=$TOP_DIR/files

# Load local configuration
source $TOP_DIR/stackrc

# Get the variables that are set in stack.sh
if [[ -r $TOP_DIR/.stackenv ]]; then
    source $TOP_DIR/.stackenv
fi

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro


# Import database library
source $TOP_DIR/lib/database
source $TOP_DIR/lib/rpc_backend

source $TOP_DIR/lib/oslo
source $TOP_DIR/lib/tls
source $TOP_DIR/lib/horizon
source $TOP_DIR/lib/keystone
source $TOP_DIR/lib/glance
source $TOP_DIR/lib/nova
source $TOP_DIR/lib/gantt
source $TOP_DIR/lib/cinder
source $TOP_DIR/lib/swift
source $TOP_DIR/lib/ceilometer
source $TOP_DIR/lib/heat
source $TOP_DIR/lib/neutron
source $TOP_DIR/lib/baremetal
source $TOP_DIR/lib/ldap

# Extras Source
# --------------

# Phase: source
if [[ -d $TOP_DIR/extras.d ]]; then
    for i in $TOP_DIR/extras.d/*.sh; do
        [[ -r $i ]] && source $i source
    done
fi

# See if there is anything running...
# need to adapt when run_service is merged
SESSION=$(screen -ls | awk '/[0-9].stack/ { print $1 }')
if [[ -n "$SESSION" ]]; then
    # Let unstack.sh do its thing first
    $TOP_DIR/unstack.sh --all
fi

# Run extras
# ==========

# Phase: clean
if [[ -d $TOP_DIR/extras.d ]]; then
    for i in $TOP_DIR/extras.d/*.sh; do
        [[ -r $i ]] && source $i clean
    done
fi

# Clean projects
cleanup_oslo
cleanup_cinder
cleanup_glance
cleanup_keystone
cleanup_nova
cleanup_neutron
cleanup_swift

if is_service_enabled ldap; then
    cleanup_ldap
fi

# Do the hypervisor cleanup until this can be moved back into lib/nova
if [[ -r $NOVA_PLUGINS/hypervisor-$VIRT_DRIVER ]]; then
    cleanup_nova_hypervisor
fi

# cinder doesn't always clean up the volume group as it might be used elsewhere...
# clean it up if it is a loop device
VG_DEV=$(sudo losetup -j $DATA_DIR/${VOLUME_GROUP}-backing-file | awk -F':' '/backing-file/ { print $1}')
if [[ -n "$VG_DEV" ]]; then
    sudo losetup -d $VG_DEV
fi

#if mount | grep $DATA_DIR/swift/drives; then
#  sudo umount $DATA_DIR/swift/drives/sdb1
#fi


# Clean out /etc
sudo rm -rf /etc/keystone /etc/glance /etc/nova /etc/cinder /etc/swift

# Clean out tgt
sudo rm /etc/tgt/conf.d/*

# Clean up the message queue
cleanup_rpc_backend
cleanup_database

# Clean up networking...
# should this be in nova?
# FIXED_IP_ADDR in br100

# Clean up files
rm -f $TOP_DIR/.stackenv

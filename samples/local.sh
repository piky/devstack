#!/usr/bin/env bash

# Sample ``local.sh`` for user-configurable tasks to run automatically
# at the sucessful conclusion of ``stack.sh``.

# NOTE: Copy this file to the root ``devstack`` directory for it to
# work properly.

# This is a collection of some of the things we have found to be useful to run
# after stack.sh to tweak the OpenStack configuration that DevStack produces.
# These should be considered as samples and are unsupported DevStack code.

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Use openrc + stackrc + localrc for settings
source $TOP_DIR/stackrc

# Destination path for installation ``DEST``
DEST=${DEST:-/opt/stack}

# Create A Flavor
# ---------------

# nova-manage creates the flavor
NOVA_MANAGE=$DEST/nova/bin/nova-manage 

# Name of new flavor
# set in ``localrc`` with ``DEFAULT_INSTANCE_TYPE=m1.micro``
MI_NAME=m1.micro

# Create micro flavor if not present
if [[ -z `$NOVA_MANAGE instance_type list | grep $MI_NAME` ]]; then
    $NOVA_MANAGE instance_type create $MI_NAME 128 1 0 0 6 0 1
fi

# Import ssh keys
# ---------------

# Import keys from the current user into the default OpenStack user (usually
# ``demo``)

# Get OpenStack auth
source $TOP_DIR/openrc

# Add first keypair found in localhost:$HOME/.ssh
for i in $HOME/.ssh/id_rsa.pub $HOME/.ssh/id_dsa.pub; do
    if [[ -f $i ]]; then
        nova keypair-add --pub_key=$i `hostname`
        break
    fi
done

# Other Uses
# ----------

# Add tcp/22 to default security group


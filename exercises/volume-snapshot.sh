#!/usr/bin/env bash

# Test nova volume snapshotting with the nova command from python-novaclient

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# Settings
# ========

# Keep track of the current directory
EXERCISE_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $EXERCISE_DIR/..; pwd)

# Import common functions
source $TOP_DIR/functions

# Import configuration
source $TOP_DIR/openrc

# Import exercise configuration
source $TOP_DIR/exerciserc

# Instance type to create
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}

# Boot this image, use first AMi image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# Launching a server
# ==================

# List servers for tenant:
nova list

# Images
# ------

# Nova has a **deprecated** way of listing images.
nova image-list
IMAGE=`glance -f index | egrep $DEFAULT_IMAGE_NAME | head -1 | cut -d" " -f1`

# determinine instance type
# -------------------------

# List of instance types:
nova flavor-list

INSTANCE_TYPE=`nova flavor-list | grep $DEFAULT_INSTANCE_TYPE | cut -d"|" -f2`
if [[ -z "$INSTANCE_TYPE" ]]; then
    # grab the first flavor in the list to launch if default doesn't exist
   INSTANCE_TYPE=`nova flavor-list | head -n 4 | tail -n 1 | cut -d"|" -f2`
fi

NAME="myserver"

VM_UUID=`nova boot --flavor $INSTANCE_TYPE --image $IMAGE $NAME | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`

# Testing
# =======

# First check if it spins up (becomes active and responds to ping on
# internal ip).  If you run this script from a nova node, you should
# bypass security groups and have direct access to the server.

# Waiting for boot
# ----------------

# check that the status is active within ACTIVE_TIMEOUT seconds
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova show $VM_UUID | grep status | grep -q ACTIVE; do sleep 1; done"; then
    echo "server didn't become active!"
    exit 1
fi


# Volumes
# -------

VOL_NAME="myvol-$(openssl rand -hex 4)"
VOL_SNAP_NAME="volsnap-$(openssl rand -hex 4)"

# Verify it doesn't exist
if [[ -n "`nova volume-list | grep $VOL_NAME | head -1 | cut -d'|' -f3 | sed 's/ //g'`" ]]; then
    echo "Volume $VOL_NAME already exists"
    exit 1
fi

if [[ -n "`nova volume-list | grep $VOL_SNAP_NAME | head -1 | cut -d'|' -f3 | sed 's/ //g'`" ]]; then
    echo "Volume $VOL_SNAP_NAME already exists"
    exit 1
fi


# Create a new volume
nova volume-create --display_name $VOL_NAME --display_description "test volume: $VOL_NAME" 1
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep available; do sleep 1; done"; then
    echo "Volume $VOL_NAME not created"
    exit 1
fi

# Get volume ID
VOL_ID=`nova volume-list | grep $VOL_NAME | head -1 | cut -d'|' -f2 | sed 's/ //g'`

# Attach to server
DEVICE=/dev/vdb
nova volume-attach $VM_UUID $VOL_ID $DEVICE
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep in-use; do sleep 1; done"; then
    echo "Volume $VOL_NAME not attached to $NAME"
    exit 1
fi

VOL_ATTACH=`nova volume-list | grep $VOL_NAME | head -1 | cut -d'|' -f7 | sed 's/ //g' | tr -d ' '`
if [[ "$VOL_ATTACH" != $VM_UUID ]]; then
    echo "Volume not attached to correct instance"
    exit 1
fi

# Detach volume from server
nova volume-detach $VM_UUID $VOL_ID
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep available; do sleep 1; done"; then
    echo "Volume $VOL_NAME not detached from $NAME"
    exit 1
fi


# Create snapshot of volume
nova volume-snapshot-create $VOL_ID --display_name $VOL_SNAP_NAME
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-snapshot-list | grep $VOL_SNAP_NAME | grep available; do sleep 1; done"; then
    echo "Volume snapshot, $VOL_SNAP_NAME did not become available"
    exit 1
fi
SNAPSHOT_ID=`nova volume-snapshot-list | grep $VOL_SNAP_NAME | head -1 | cut -d'|' -f2 | sed 's/ //g'`

exit
# Delete volume snapshot
nova volume-snapshot-delete $SNAPSHOT_ID
# FIXME - the timeout check on this line is broken
if ! timeout $VOLUME_DELETE_TIMEOUT sh -c "while nova volume-snapshot-list | grep $VOL_SNAP_NAME; do sleep 1; done"; then
    echo "Volume snapshot, $VOL_SNAP_NAME, was not deleted"
    exit 1
fi

# Delete volume
nova volume-delete $VOL_ID
# FIXME - the timeout check on this line is broken
if ! timeout $VOLUME_DELETE_TIMEOUT sh -c "while nova volume-list | grep $VOL_NAME; do sleep 1; done"; then
    echo "Volume $VOL_NAME not deleted"
    exit 1
fi

# shutdown the server
nova delete $NAME

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"

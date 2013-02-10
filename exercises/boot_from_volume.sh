#!/usr/bin/env bash

# **boot_from_volume.sh**

# This script demonstrates how to boot from a volume.  It does the following:
#  *  Create a bootable volume
#  *  Boot a volume-backed instance

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

# Import quantum functions if needed
if is_service_enabled quantum; then
    source $TOP_DIR/lib/quantum
fi

# Import exercise configuration
source $TOP_DIR/exerciserc

# If cinder is not enabled we exit with exitcode 55 so that
# the exercise is skipped
is_service_enabled cinder || exit 55

# Boot this image, use first AMI image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# Instance type
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}

# BFV size
DEFAULT_BFV_SIZE=${DEFAULT_BFV_SIZE:-2}

# Create bootable volume
# =================

# Grab the id of the image to launch
IMAGE=`glance image-list | egrep " $DEFAULT_IMAGE_NAME " | get_field 1`
die_if_not_set IMAGE "Failure getting image"

# Determinine instance type
INSTANCE_TYPE=`nova flavor-list | grep $DEFAULT_INSTANCE_TYPE | cut -d"|" -f2`
if [[ -z "$INSTANCE_TYPE" ]]; then
    # grab the first flavor in the list to launch if default doesn't exist
   INSTANCE_TYPE=`nova flavor-list | head -n 4 | tail -n 1 | cut -d"|" -f2`
fi

# Instance and volume names
VOL_NAME=${VOL_NAME:-test_bfv}
INSTANCE_NAME=${INSTANCE_NAME:-bfv_instance}


# Create a new volume
cinder create --image-id $IMAGE --display_name $VOL_NAME --display_description "test bootable volume: $VOL_NAME" $DEFAULT_BFV_SIZE
if [[ $? != 0 ]]; then
    echo "Failure creating volume $VOL_NAME"
    exit 1
fi

start_time=`date +%s`
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! cinder list | grep $VOL_NAME | grep available; do sleep 1; done"; then
    echo "Volume $VOL_NAME not created"
    exit 1
fi
end_time=`date +%s`
echo "Completed cinder create in $((end_time - start_time)) seconds"

VOLUME_ID=`cinder list | grep $VOL_NAME  | get_field 1`

# Boot instance from volume!  This is done with the --block_device_mapping param.
# The format of mapping is:
# <dev_name>=<id>:<type>:<size(GB)>:<delete_on_terminate>
# Leaving the middle two fields blank appears to do-the-right-thing
VOL_VM_UUID=`nova boot --flavor $INSTANCE_TYPE --image $IMAGE --block-device-mapping vda=$VOLUME_ID $INSTANCE_NAME | grep ' id ' | get_field 2`
die_if_not_set VOL_VM_UUID "Failure launching $INSTANCE_NAME"

# Check that the status is active within ACTIVE_TIMEOUT seconds
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova show $VOL_VM_UUID | grep status | grep -q ACTIVE; do sleep 1; done"; then
    echo "server didn't become active!"
    exit 1
fi

# Delete the instance
nova delete $VOL_VM_UUID || \
    die "Failure deleting instance $VOL_VM_UUID"

# Wait fo the delete of the instance
if ! timeout $ACTIVE_TIMEOUT sh -c "while nova show $VOL_VM_UUID | grep status; do sleep 1; done"; then
    echo "server didn't delete within timeout!"
    exit 1
fi

# Delete volume
start_time=`date +%s`
cinder delete $VOLUME_ID || die "Failure deleting volume $VOL_NAME"
if ! timeout $ACTIVE_TIMEOUT sh -c "while cinder list | grep $VOL_NAME; do sleep 1; done"; then
    echo "Volume $VOL_NAME not deleted"
    exit 1
fi
end_time=`date +%s`
echo "Completed cinder delete in $((end_time - start_time)) seconds"

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"

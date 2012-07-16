#!/usr/bin/env bash

# **ec2_create_image.sh**

# This script demonstrates how to create an image from a booted-from-volume instance.
# It does the following:
#  *  Create a 'builder' instance
#  *  Attach a volume to the instance
#  *  Format and install an os onto the volume
#  *  Detach volume from builder, and then boot volume-backed instance
#  *  Create an image from the volume-backed instance
#  *  Run an EC2-style instance from that image

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

# Import EC2 configuration
source $TOP_DIR/eucarc

# Import exercise configuration
source $TOP_DIR/exerciserc

# Boot this image, use first AMI image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# Instance type
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}

# Instance and volume names
INSTANCE_NAME=${INSTANCE_NAME:-builder_instance}
VOL_INSTANCE_NAME=${VOL_INSTANCE_NAME:-test_vol_instance}
VOL_NAME=${VOL_NAME:-test_volume}
SNAPSHOT_NAME=${SNAPSHOT_NAME:-test_snapshot}

# Key names
KEY_NAME=test_key
KEY_FILE=key.pem

# Device path for mounted volume
DEVICE=/dev/vdb

# Builder directories
STAGING_DIR=/tmp/stage
CIRROS_DIR=/tmp/cirros

# Allow additional time for startup
ACTIVE_TIMEOUT=120

# Functions
# =========

function await_state {
    [ $3 ] && CMD="${3}-show" || CMD="show"
    if ! timeout $ACTIVE_TIMEOUT sh -c "while ! eval nova $CMD $1 | grep status | grep -q $2; do sleep 1; done"; then
        [ $3 ] && TYPE="${3}" || TYPE="server"
        echo "$TYPE $1 didn't become $2"
        exit 1
    fi
}

function await_termination {
    [ $2 ] && CMD="${2}-show" || CMD="show"
    if ! timeout $ACTIVE_TIMEOUT sh -c "while eval nova $CMD $1; do sleep 1; done"; then
        [ $2 ] && TYPE="${2}" || TYPE="server"
        echo "$TYPE $1 didn't do away"
        exit 1
    fi
}

function await_ssh {
    echo "test" > /tmp/test
    if ! timeout $ACTIVE_TIMEOUT sh -c "while ! scp -o StrictHostKeyChecking=no -i $KEY_FILE /tmp/test cirros@$1:/tmp; do sleep 1; done"; then
        echo "address $1 not ssh-able"
        exit 1
    fi
}

function as_bytes {
    echo $1 | sed -e 's/b//i;s/k/*1024/i;s/m/*1024^2/i;s/g/*1024^3/i;s/t/*1024^4/i' | bc
}

# Ensure sufficient volume space
# ==============================

[ `as_bytes $VOLUME_BACKING_FILE_SIZE` -gt `as_bytes "5120M"` ] || exit 55

# Clean-up from previous runs
# ===========================

# Delete the builder and volume-backed servers
nova delete $VOL_INSTANCE_NAME || true
nova delete $INSTANCE_NAME || true
await_termination $VOL_INSTANCE_NAME
await_termination $INSTANCE_NAME

# Delete the old snapshot
nova volume-snapshot-delete $SNAPSHOT_NAME || true
await_termination $SNAPSHOT_NAME "volume-snapshot"

# Delete the old volume
nova volume-delete $VOL_NAME || true
await_termination $VOL_NAME "volume"

# Launch builder server
# =====================

# Grab the id of the image to launch
IMAGE=`glance image-list | egrep " $DEFAULT_IMAGE_NAME " | get_field 1`
die_if_not_set IMAGE "Failure getting image"

# Determinine instance type
INSTANCE_TYPE=`nova flavor-list | grep $DEFAULT_INSTANCE_TYPE | cut -d"|" -f2`
if [[ -z "$INSTANCE_TYPE" ]]; then
    # grab the first flavor in the list to launch if default doesn't exist
   INSTANCE_TYPE=`nova flavor-list | head -n 4 | tail -n 1 | cut -d"|" -f2`
fi

# Setup Keypair
nova keypair-delete $KEY_NAME || true
nova keypair-add $KEY_NAME > $KEY_FILE
chmod 600 $KEY_FILE

# Boot the builder instance
VM_UUID=`nova boot --flavor $INSTANCE_TYPE --image $IMAGE --key_name $KEY_NAME $INSTANCE_NAME | grep ' id ' | get_field 2`
die_if_not_set VM_UUID "Failure launching $INSTANCE_NAME"

# check that the status is active within ACTIVE_TIMEOUT seconds
await_state $VM_UUID "ACTIVE"

IP_ADDRESS=`nova show $VM_UUID | grep 'private network' | get_field 2`

# Ensure ssh connections accepted on builder instance
await_ssh $IP_ADDRESS

# Create bootable volume
# ======================

# Create our volume
nova volume-create --display_name=$VOL_NAME 1
await_state $VOL_NAME "available" "volume"

VOLUME_ID=`nova volume-list | grep $VOL_NAME  | get_field 1`
nova volume-attach $INSTANCE_NAME $VOLUME_ID $DEVICE
await_state $VOL_NAME "in-use" "volume"

# The following script builds our bootable volume.
# To do this, ssh to the builder instance, mount volume, and build a volume-backed image.
ssh -o StrictHostKeyChecking=no -i $KEY_FILE cirros@$IP_ADDRESS << EOF
set -o errexit
set -o xtrace
sudo mkdir -p $STAGING_DIR
sudo mkfs.ext3 -b 1024 $DEVICE 1048576
sudo mount $DEVICE $STAGING_DIR
# The following lines create a writable empty file so that we can scp
# the actual file
sudo touch $STAGING_DIR/cirros-0.3.0-x86_64-rootfs.img.gz
sudo chown cirros $STAGING_DIR/cirros-0.3.0-x86_64-rootfs.img.gz
EOF

# Download cirros
if [ ! -e cirros-0.3.0-x86_64-rootfs.img.gz ]; then
    wget http://images.ansolabs.com/cirros-0.3.0-x86_64-rootfs.img.gz
fi

# Copy cirros onto the volume
scp -o StrictHostKeyChecking=no -i $KEY_FILE cirros-0.3.0-x86_64-rootfs.img.gz cirros@$IP_ADDRESS:$STAGING_DIR

# Unpack cirros into volume
ssh -o StrictHostKeyChecking=no -i $KEY_FILE cirros@$IP_ADDRESS << EOF
set -o errexit
set -o xtrace
cd $STAGING_DIR
sudo mkdir -p $CIRROS_DIR
sudo gunzip cirros-0.3.0-x86_64-rootfs.img.gz
sudo mount cirros-0.3.0-x86_64-rootfs.img $CIRROS_DIR

# Copy cirros into our volume
sudo cp -pr $CIRROS_DIR/* $STAGING_DIR/

cd
sync
sudo umount $CIRROS_DIR
# The following typically fails.  Don't know why.
sudo umount $STAGING_DIR || true
EOF

# Detach the volume from the builder instance
nova volume-detach $INSTANCE_NAME $VOLUME_ID
await_state $VOL_NAME "available" "volume"

# Snapshot the bootable volume
nova volume-snapshot-create --display_name $SNAPSHOT_NAME $VOLUME_ID
SNAPSHOT_ID=`nova volume-snapshot-list | grep test_snapshot | get_field 1`
await_state $SNAPSHOT_NAME "available" "volume-snapshot"

# Boot from snapshot
# ==================

# Boot instance from a snapshot of the bootable volume, via the --block_device_mapping option.
# The format of mapping is:
# <dev_name>=<id>:<type>:<size(GB)>:<delete_on_terminate>
# 'snap' refers to the snapshot type, whereas the size field may be left empty
VOL_VM_UUID=`nova boot --flavor $INSTANCE_TYPE --image $IMAGE --block_device_mapping vda=${SNAPSHOT_ID}:snap::0 --security_groups=$SECGROUP --key_name $KEY_NAME $VOL_INSTANCE_NAME | grep ' id ' | get_field 2`
die_if_not_set VOL_VM_UUID "Failure launching $VOL_INSTANCE_NAME"
await_state $VOL_VM_UUID "ACTIVE"

# Create image
# ============

# Find the EC2-style instance ID for booted-from-volume server
VOL_EC2_INSTANCE_ID=`euca-describe-instances | awk '/INSTANCE/ {print $2}' | sort | tail -1`

# Create an image from the running volume-backed instance
CREATED_IMAGE_ID=`euca-create-image -n image_from_booted_vol --no-reboot $VOL_EC2_INSTANCE_ID | awk '{print $2}'`

# Launch another EC2-style instance from created image
CREATED_IMAGE_INSTANCE_ID=`euca-run-instances -t $DEFAULT_INSTANCE_TYPE -k $KEY_NAME $CREATED_IMAGE_ID | awk '/INSTANCE/ {print $2}'`

# Boot from created image
# =======================

# Retrieve the nova UUID of the instance launched from created image
CREATED_IMAGE_INSTANCE_UUID=`euca-describe-instances | awk "/\<$CREATED_IMAGE_INSTANCE_ID\>/ {print \\$4}" | cut -d- -f2-`
await_state $CREATED_IMAGE_INSTANCE_UUID "ACTIVE"

# Retrieve the private IP address of the instance launched from created image
CREATED_IMAGE_INSTANCE_IP_ADDRESS=`nova show $CREATED_IMAGE_INSTANCE_UUID | grep 'private network' | get_field 2`

# Gratuitous sleep, probably hiding a race condition :/
sleep 1

# Ensure ssh connections accepted on instance launched from created image
await_ssh $CREATED_IMAGE_INSTANCE_IP_ADDRESS

# Clean up after test run
# =======================

# Terminate instance launched from created image
VOL_FROM_IMAGE_ID=`nova volume-list | grep $CREATED_IMAGE_INSTANCE_UUID | get_field 1`
#euca-terminate-instances $CREATED_IMAGE_INSTANCE_ID
#    die "Failure terminating instance $CREATED_IMAGE_INSTANCE_ID"
nova delete $CREATED_IMAGE_INSTANCE_UUID || \
    die "Failure deleting instance volume $CREATED_IMAGE_INSTANCE_UUID"
await_termination $CREATED_IMAGE_INSTANCE_UUID

# Delete volume from image snapshot
await_state $VOL_FROM_IMAGE_ID "available" "volume"
nova volume-delete $VOL_FROM_IMAGE_ID || \
    die "Failure deleting instance volume $VOL_FROM_IMAGE_ID"
await_termination $VOL_FROM_IMAGE_ID "volume"

# Delete volume backed instance
VOL_FROM_SNAPSHOT_ID=`nova volume-list| grep $VOL_VM_UUID | get_field 1`
nova delete $VOL_INSTANCE_NAME || \
    die "Failure deleting instance volume $VOL_INSTANCE_NAME"
await_termination $VOL_INSTANCE_NAME

# Delete the original snapshot
nova volume-snapshot-delete $SNAPSHOT_NAME || \
    die "Failure deleting snapshot $SNAPSHOT_NAME"
await_termination $SNAPSHOT_NAME "volume-snapshot"

# Delete internal snapshot
INTERNAL_SNAPSHOT_ID=`nova volume-snapshot-list | grep $VOL_FROM_SNAPSHOT_ID | get_field 1`
nova volume-snapshot-delete $INTERNAL_SNAPSHOT_ID || \
    die "Failure deleting snapshot $INTERNAL_SNAPSHOT_ID"
await_termination $INTERNAL_SNAPSHOT_ID "volume-snapshot"

# Delete volume from original snapshot
await_state $VOL_FROM_SNAPSHOT_ID "available" "volume"
nova volume-delete $VOL_FROM_SNAPSHOT_ID || \
    die "Failure deleting instance volume $VOL_FROM_SNAPSHOT_ID"
await_termination $VOL_FROM_SNAPSHOT_ID "volume"

# Delete the original volume
nova volume-delete $VOL_NAME || \
    die "Failure deleting volume $VOLUME_NAME"
await_termination $VOL_NAME "volume"

# Delete the builder instance
nova delete $INSTANCE_NAME || \
    die "Failure deleting instance $INSTANCE_NAME"
await_termination $INSTANCE_NAME

# Delete the created image
CREATED_IMAGE_UUID=`glance image-list | grep "image_from_booted_vol" | get_field 1`
glance image-delete $CREATED_IMAGE_UUID

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"

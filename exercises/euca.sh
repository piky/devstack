#!/usr/bin/env bash

# **euca.sh**

# we will use the ``euca2ools`` cli tool that wraps the python boto
# library to test ec2 compatibility

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
VOLUME_ZONE=cinder
VOLUME_SIZE=1
ATTACH_DEVICE=/dev/vdc

# Import common functions
source $TOP_DIR/functions

# Import EC2 configuration
source $TOP_DIR/eucarc

# Import exercise configuration
source $TOP_DIR/exerciserc

# Instance type to create
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}


# Launching a server
# ==================

# Find a machine image to boot
IMAGE=`euca-describe-images | grep machine | cut -f2 | head -n1`

# Define secgroup
SECGROUP=euca_secgroup

# Add a secgroup
if ! euca-describe-groups | grep -q $SECGROUP; then
    euca-add-group -d "$SECGROUP description" $SECGROUP
    if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! euca-describe-groups | grep -q $SECGROUP; do sleep 1; done"; then
        echo "Security group not created"
        exit 1
    fi
fi

# Launch it
INSTANCE=`euca-run-instances -g $SECGROUP -t $DEFAULT_INSTANCE_TYPE $IMAGE | grep INSTANCE | cut -f2`
die_if_not_set INSTANCE "Failure launching instance"

# Assure it has booted within a reasonable time
if ! timeout $RUNNING_TIMEOUT sh -c "while ! euca-describe-instances $INSTANCE | grep -q running; do sleep 1; done"; then
    echo "server didn't become active within $RUNNING_TIMEOUT seconds"
    exit 1
fi

# Allocate floating address
FLOATING_IP=`euca-allocate-address | cut -f2`
die_if_not_set FLOATING_IP "Failure allocating floating IP"

# Associate floating address
euca-associate-address -i $INSTANCE $FLOATING_IP || \
    die "Failure associating address $FLOATING_IP to $INSTANCE"

# Authorize pinging
euca-authorize -P icmp -s 0.0.0.0/0 -t -1:-1 $SECGROUP || \
    die "Failure authorizing rule in $SECGROUP"

# Test we can ping our floating ip within ASSOCIATE_TIMEOUT seconds
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! ping -c1 -w1 $FLOATING_IP; do sleep 1; done"; then
    echo "Couldn't ping server with floating ip"
    exit 1
fi

# Revoke pinging
euca-revoke -P icmp -s 0.0.0.0/0 -t -1:-1 $SECGROUP || \
    die "Failure revoking rule in $SECGROUP"

# Release floating address
euca-disassociate-address $FLOATING_IP || \
    die "Failure disassociating address $FLOATING_IP"

# Wait just a tick for everything above to complete so release doesn't fail
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while euca-describe-addresses | grep $INSTANCE | grep -q $FLOATING_IP; do sleep 1; done"; then
    echo "Floating ip $FLOATING_IP not disassociated within $ASSOCIATE_TIMEOUT seconds"
    exit 1
fi

# Release floating address
euca-release-address $FLOATING_IP || \
    die "Failure releasing address $FLOATING_IP"

# Wait just a tick for everything above to complete so terminate doesn't fail
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while euca-describe-addresses | grep -q $FLOATING_IP; do sleep 1; done"; then
    echo "Floating ip $FLOATING_IP not released within $ASSOCIATE_TIMEOUT seconds"
    exit 1
fi

VOLUME=`euca-create-volume -z $VOLUME_ZONE -s $VOLUME_SIZE | grep VOLUME | cut -f2`
if [[ $? != 0 ]]; then
    echo "Failure in euca-create-volume"
    exit 1
fi
if ! timeout $VOLUME_TIMEOUT sh -c "while ! euca-describe-volumes | grep $VOLUME | grep available; do sleep 1; done"; then
    echo "euca-create-volume failed"                                                                                                                                     
    exit 1
fi

# Attach volume
#FIXME(jdg) Timing issues with the euca commands
ATTACH=`euca-attach-volume -i $INSTANCE -d $ATTACH_DEVICE $VOLUME`
if [[ $? != 0 ]]; then
    echo "Failure in euca-attach-volume"
    exit 1
fi
if ! timeout $VOLUME_TIMEOUT sh -c "while ! euca-describe-volumes | grep $VOLUME | grep in-use; do sleep 1; done"; then
    echo "euca-create-volume failed"
    exit 1
fi

# Detach volume
DETACH=`euca-detach-volume $VOLUME | grep VOLUME | cut -f2`
if [[ $? != 0 ]]; then
    echo "Failure in euca-detach-volume"
    exit 1
fi
if ! timeout $VOLUME_TIMEOUT sh -c "while ! euca-describe-volumes | grep $VOLUME | grep available; do sleep 1; done"; then
    echo "euca-detach-volume failed"
    exit 1
fi

# Snapshot volume
SNAP=`euca-create-snapshot $VOLUME | grep SNAPSHOT | cut -f2`
if [[ $? != 0 ]]; then
    echo "Failure in euca-create-snapshot"
    exit 1
fi
if ! timeout $VOLUME_TIMEOUT sh -c "while ! euca-describe-snapshots | grep $VOLUME; do sleep 1; done"; then
    echo "euca-create-snapshot failed"
    exit 1
fi

# Delete snapshot
SNAPD=`euca-delete-snapshot $SNAP | grep $SNAP| cut -f2`
if [[ $? != 0 ]]; then
    echo "Failure in euca-delete-snapshot"
    exit 1
fi
if ! timeout $VOLUME_DELETE_TIMEOUT sh -c "while euca-describe-snapshots | grep $SNAP; do sleep 1; done"; then
    echo "euca-delete-snapshot failed"
    exit 1
fi

# Delete volume
VOLD=`euca-delete-volume $VOLUME | grep VOLUME | cut -f2`
if [[ $? != 0 ]]; then
    echo "Failure in euca-delete-volume"
    exit 1
fi
if ! timeout $VOLUME_DELETE_TIMEOUT sh -c "while euca-describe-volumes | grep $VOLUME; do sleep 1; done"; then
    echo "euca-delete-volume failed"
    exit 1
fi

# Terminate instance
euca-terminate-instances $INSTANCE || \
    die "Failure terminating instance $INSTANCE"

# Assure it has terminated within a reasonable time
if ! timeout $TERMINATE_TIMEOUT sh -c "while euca-describe-instances $INSTANCE | grep -q running; do sleep 1; done"; then
    echo "server didn't terminate within $TERMINATE_TIMEOUT seconds"
    exit 1
fi

# Delete group
euca-delete-group $SECGROUP || \
    die "Failure deleting security group $SECGROUP"

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"

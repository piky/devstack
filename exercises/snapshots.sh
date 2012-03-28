#!/usr/bin/env bash

# **snapshots.sh**

# Test snapshotting via the command line.

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# settings
# ========

# Use openrc + stackrc + localrc for settings
pushd $(cd $(dirname "$0")/.. && pwd)
source ./openrc
popd

# Max time to wait for snapshot to be saved
SNAPSHOT_TIMEOUT=${SNAPSHOT_TIMEOUT:-600}

# Max time to wait while vm goes from build to active state
ACTIVE_TIMEOUT=${ACTIVE_TIMEOUT:-60}

# Max time till the vm is bootable
BOOT_TIMEOUT=${BOOT_TIMEOUT:-30}

# Max time to wait for proper association and dis-association.
ASSOCIATE_TIMEOUT=${ASSOCIATE_TIMEOUT:-15}

# Instance type to create
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.small}

# Boot this image, use first AMi image if unset
#DEFAULT_IMAGE_NAME=natty-server-cloudimg-amd64
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-oneiric-server-cloudimg-amd64}

# Set security group or default to default
SECGROUP=${SECGROUP:-default}

# Launching a server
# ==================

# List servers for tenant:
nova list

# Images
# ------

# Nova has a **deprecated** way of listing images.
nova image-list
IMAGE=`nova image-list | egrep $DEFAULT_IMAGE_NAME | grep -v kernel | head -1 | cut -d" " -f2`


# determinine instance type
# -------------------------

# List of instance types:
nova flavor-list

# Get the flavor id
INSTANCE_TYPE=`nova flavor-list | grep $DEFAULT_INSTANCE_TYPE | cut -d"|" -f2`
if [[ -z "$INSTANCE_TYPE" ]]; then
    # grab the first flavor in the list to launch if default doesn't exist
   INSTANCE_TYPE=`nova flavor-list | head -n 4 | tail -n 1 | cut -d"|" -f2`
fi

NAME="myserver"
NEW_NAME="myserver_snapshot"

# Verify secgroup can ping and allow ssh connections
SEC_GROUP_RULES=( $( nova secgroup-list-rules $SECGROUP | grep -v "+" | grep -v "IP Protocol" | cut -d "|" -f3 | tr -d ' ') )
HAS_SSH=0
HAS_PING=0
for rule in "${SEC_GROUP_RULES[@]}"
do
    if [ "$rule" == "-1" ]; then
        HAS_PING=1
    elif [ "$rule" == "22" ]; then
        HAS_SSH=1
    fi
done

if [ "$HAS_SSH" == "0" ]; then
    nova secgroup-add-rule $SECGROUP tcp 22 22 0.0.0.0/00
fi

if [ "$HAS_PING" == "0" ]; then
    nova secgroup-add-rule $SECGROUP icmp -1 -1 0.0.0.0/00
fi



# Add keypair so that we can ssh and create a file

HAS_KEYPAIR=`nova keypair-list | grep snapshot_key | cut -d '|' -f2 | tr -d ' '`
echo $HAS_KEYPAIR
if [ "$HAS_KEYPAIR" != "" ]; then
    nova keypair-delete snapshot_key
fi

PUBLIC_KEY=''
if [ -e '/tmp/snapshot_key' ] || [ -e '/tmp/snapshot_key.pub' ]; then
    rm /tmp/snapshot_key*
fi
ssh-keygen -t rsa -P "" -f /tmp/snapshot_key

nova keypair-add --pub_key /tmp/snapshot_key.pub snapshot_key

VM_UUID=`nova boot --key_name snapshot_key --flavor $INSTANCE_TYPE --image $IMAGE --security_groups=$SECGROUP $NAME | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`
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

# get the IP of the server
IP=`nova show $VM_UUID | grep "private network" | cut -d"|" -f3`

# add floating IP
set +e
function in_dont_use() {
    DONT_USE=( "50.56.12.240" "50.56.12.241" "50.56.12.242" "50.56.12.243" "50.56.12.247" )
    local_dummy_var=""
    for i in "${DONT_USE[@]}"
    do
        if [ "$i" == "$1" ] ; then
            return 1
        fi
    done
    return 0
}

HAS_IP=1
EXTERNAL_IP=""
while [ "$HAS_IP" == "1" ]
do
    IPS_ARRAY=( $( nova floating-ip-list | grep None | cut -d "|" -f2 | tr -d ' ') )    
    for ip in "${IPS_ARRAY[@]}"
    do
        in_dont_use $ip
        HAS_IP=$?
        echo $HAS_IP
        if [ "$HAS_IP" == "0" ]
        then
            EXTERNAL_IP="$ip"
            break
        fi
    done
    if [ "$EXTERNAL_IP" == "" ]
    then
        EXTERNAL_IP=$(nova floating-ip-create | grep None | cut -d "|" -f2 | tr -d ' ')
        HAS_IP=0
    fi
done

set -e

nova add-floating-ip $VM_UUID $EXTERNAL_IP

# sometimes the first ping fails (10 seconds isn't enough time for the VM's
# network to respond?), so let's ping for a default of 15 seconds with a
# timeout of a second for each ping.
if ! timeout $BOOT_TIMEOUT sh -c "while ! ping -c1 -w1 $EXTERNAL_IP; do sleep 1; done"; then
    echo "Couldn't ping server"
    exit 1
fi

# Create file on server then make a snapshot of the instance

HAS_SNAPSHOT=`nova image-list | grep snapshot_exercise_snapshot | cut -d '|' -f2 | tr -d ' '`
if [ "$HAS_SNAPSHOT" != "" ]; then
    nova image-delete snapshot_exercise_snapshot
fi

sleep 10
ssh -i /tmp/snapshot_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/nul ubuntu@$EXTERNAL_IP 'touch test_file'

nova image-create $VM_UUID snapshot_exercise_snapshot

# check that the status is active within ACTIVE_TIMEOUT seconds and set variable for image id
if ! timeout $SNAPSHOT_TIMEOUT sh -c "while ! nova image-show snapshot_exercise_snapshot | grep status | grep ACTIVE; do sleep 1; done"; then
    echo "Snapshot didn't become active!"
    exit 1
fi
IMAGE_ID=`nova image-list | grep snapshot_exercise_snapshot | cut -d '|' -f2 | tr -d ' '`

# shutdown the server
nova remove-floating-ip $VM_UUID $EXTERNAL_IP
#nova delete $VM_UUID


VM_UUID=`nova boot --key_name snapshot_key --flavor $INSTANCE_TYPE --image $IMAGE_ID --security_groups=$SECGROUP $NEW_NAME | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`

# check that the status is active within ACTIVE_TIMEOUT seconds
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova show $VM_UUID | grep status | grep -q ACTIVE; do sleep 1; done"; then
    echo "server didn't become active!"
    exit 1
fi

# Add the floating ip
nova add-floating-ip $VM_UUID $EXTERNAL_IP
sleep 10

# Check that the previously created file exists in snapshot instance
CHECK_FOR_FILE=`ssh -i /tmp/snapshot_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/nul ubuntu@$EXTERNAL_IP 'ls test_file'`
if [ "$CHECK_FOR_FILE" == "test_file" ]; then
    echo "Snapshot looks good"
fi

# Clean up
nova remove-floating-ip $VM_UUID $EXTERNAL_IP
nova delete $VM_UUID
nova keypair-delete snapshot_key
rm /tmp/snapshot_key*


set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"



#!/usr/bin/env bash

# Copyright 2012 Cisco Systems
# @author: Debo~ Dutta, Cisco Systems

# Warn if quantum is not enabled

if [[ ! "$ENABLED_SERVICES" =~ "q-svc" ]]; then
    echo "WARNING: Running quantum test without enabling quantum"
fi 

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# Settings
# ========

# Use openrc + stackrc + localrc for settings
pushd $(cd $(dirname "$0")/.. && pwd)
source ./openrc
popd

# Max time to wait while vm goes from build to active state
ACTIVE_TIMEOUT=${ACTIVE_TIMEOUT:-30}

# Max time till the vm is bootable
BOOT_TIMEOUT=${BOOT_TIMEOUT:-60}

# Max time to wait for proper association and dis-association.
ASSOCIATE_TIMEOUT=${ASSOCIATE_TIMEOUT:-15}

# Max time to wait before delete VMs and delete Networks 
VM_NET_DELETE_TIMEOUT=${VM_NET_TIMEOUT:-10}

# Instance type to create
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}

# Boot this image, use first AMi image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# Security group name
SECGROUP=${SECGROUP:-test_secgroup}

# Default floating IP pool name
DEFAULT_FLOATING_POOL=${DEFAULT_FLOATING_POOL:-nova}

# Additional floating IP pool and range
TEST_FLOATING_POOL=${TEST_FLOATING_POOL:-test}

# Get a token for clients that don't support service catalog
# ==========================================================

# manually create a token by querying keystone (sending JSON data).  Keystone
# returns a token and catalog of endpoints.  We use python to parse the token
# and save it.

TOKEN=`curl -s -d  "{\"auth\":{\"passwordCredentials\": {\"username\": \"$NOVA_USERNAME\", \"password\": \"$NOVA_PASSWORD\"}}}" -H "Content-type: application/json" http://$HOST_IP:5000/v2.0/tokens | python -c "import sys; import json; tok = json.loads(sys.stdin.read()); print tok['access']['token']['id'];"`

# Launching a server
# ==================

# List servers for tenant:
nova list

# Images
# ------

# Nova has a **deprecated** way of listing images.
nova image-list

# But we recommend using glance directly
glance -f -A $TOKEN index

# Grab the id of the image to launch
IMAGE=`glance -f -A $TOKEN index | egrep $DEFAULT_IMAGE_NAME | head -1 | cut -d" " -f1`

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

# grab admin ID from keystone
KEYSTONE_MANAGE=/opt/stack/keystone/bin/keystone-manage
ADMINID=`$KEYSTONE_MANAGE list_tenants | grep " admin " | awk '{print $2}'`

# create networks
nova-manage --flagfile=/opt/stack/nova/bin/nova.conf  network create --label=admin-net1  --fixed_range_v4=11.0.0.0/24 --project_id=$ADMINID --priority=1
nova-manage --flagfile=/opt/stack/nova/bin/nova.conf  network create --label=admin-net2  --fixed_range_v4=12.0.0.0/24 --project_id=$ADMINID --priority=2
NETID1=`nova-manage network list | grep 11.0.0.2 | awk '{print $9}'`
NETID2=`nova-manage network list | grep 12.0.0.2 | awk '{print $9}'`

VM_UUID1=`nova boot --flavor $INSTANCE_TYPE --image $IMAGE --nic net-id=$NETID1 $NAME | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`
VM_UUID2=`nova boot --flavor $INSTANCE_TYPE --image $IMAGE --nic net-id=$NETID2 $NAME | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`
VM_UUID3=`nova boot --flavor $INSTANCE_TYPE --image $IMAGE --nic net-id=$NETID1 --nic net-id=$NETID2 $NAME | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`

# Testing
# =======

# First check if it spins up (becomes active and responds to ping on
# internal ip).  If you run this script from a nova node, you should
# bypass security groups and have direct access to the server.

# Waiting for boot
# ----------------

# check that the status is active within ACTIVE_TIMEOUT seconds
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova show $VM_UUID1 | grep status | grep -q ACTIVE; do sleep 1; done"; then
    echo "server didn't become active!"
    exit 1
fi

# get the IP of the server
IP1=`nova show $VM_UUID1 | grep "admin-net1" | cut -d"|" -f3`
IP2=`nova show $VM_UUID2 | grep "admin-net2" | cut -d"|" -f3`
IP31=`nova show $VM_UUID3 | grep "admin-net1" | cut -d"|" -f3`
IP32=`nova show $VM_UUID3 | grep "admin-net2" | cut -d"|" -f3`

# for single node deployments, we can ping private ips
MULTI_HOST=${MULTI_HOST:-0}
if [ "$MULTI_HOST" = "0" ]; then
    # sometimes the first ping fails (10 seconds isn't enough time for the VM's
    # network to respond?), so let's ping for a default of 15 seconds with a
    # timeout of a second for each ping.
    if ! timeout $BOOT_TIMEOUT sh -c "while ! ping -c1 -w1 $IP1; do sleep 1; done"; then
        echo "Couldn't ping server"
        exit 1
    fi
    if ! timeout $BOOT_TIMEOUT sh -c "while ! ping -c1 -w1 $IP2; do sleep 1; done"; then
        echo "Couldn't ping server"
        exit 1
    fi
    if ! timeout $BOOT_TIMEOUT sh -c "while ! ping -c1 -w1 $IP31; do sleep 1; done"; then
        echo "Couldn't ping server"
        exit 1
    fi
else
    # On a multi-host system, without vm net access, do a sleep to wait for the boot
    sleep $BOOT_TIMEOUT
fi

# shutdown the servers
nova delete $VM_UUID1
nova delete $VM_UUID2
nova delete $VM_UUID3
sleep $VM_NET_DELETE_TIMEOUT
# delete networks we created
nova-manage --flagfile=/opt/stack/nova/bin/nova.conf  network delete --uuid $NETID1
nova-manage --flagfile=/opt/stack/nova/bin/nova.conf  network delete --uuid $NETID2


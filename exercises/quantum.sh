#!/usr/bin/env bash
#

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

#------------------------------------------------------------------------------
# Environment
#------------------------------------------------------------------------------

# Use openrc + stackrc + localrc for settings
pushd $(cd $(dirname "$0")/.. && pwd)
source ./openrc
popd

#------------------------------------------------------------------------------
# Various default parameters.
#------------------------------------------------------------------------------

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

#------------------------------------------------------------------------------
# Nova settings.
#------------------------------------------------------------------------------
NOVA_USERNAME=demo
NOVA_PASSWORD=nova
NOVA_MANAGE=/opt/stack/nova/bin/nova-manage
NOVA=/usr/local/bin/nova
NOVA_CONF=/etc/nova/nova.conf

#------------------------------------------------------------------------------
# Mysql settings.
#------------------------------------------------------------------------------
MYSQL_HOST=localhost
MYSQL="/usr/bin/mysql --skip-column-name --host=$MYSQL_HOST"
MYSQL_PASSWORD=nova

#------------------------------------------------------------------------------
# Keystone settings.
#------------------------------------------------------------------------------
KEYSTONE_MANAGE=/opt/stack/keystone/bin/keystone-manage
KEYSTONE="keystone"
# KEYSTONE="/usr/local/bin/keystone --username=admin --password=$NOVA_PASSWORD
# --auth_url=http://localhost:5000/v2.0"

#------------------------------------------------------------------------------
# Get a token for clients that don't support service catalog
#------------------------------------------------------------------------------

# manually create a token by querying keystone (sending JSON data).  Keystone
# returns a token and catalog of endpoints.  We use python to parse the token
# and save it.

TOKEN=`curl -s -d  "{\"auth\":{\"passwordCredentials\": {\"username\": \"$NOVA_USERNAME\", \"password\": \"$NOVA_PASSWORD\"}}}" -H "Content-type: application/json" http://$HOST_IP:5000/v2.0/tokens | python -c "import sys; import json; tok = json.loads(sys.stdin.read()); print tok['access']['token']['id'];"`

#------------------------------------------------------------------------------
# Other settings.
#------------------------------------------------------------------------------
OVS_HOSTS="192.168.95.138"

#------------------------------------------------------------------------------
# Various functions.
#------------------------------------------------------------------------------
function get_image_id {
    local IMAGE_ID=`glance -f -A $TOKEN index | egrep $DEFAULT_IMAGE_NAME | head -1 | cut -d" " -f1`
    echo "$IMAGE_ID"
}

function get_tenant_id {
    local TENANT_NAME=$1
    local QUERY="select id from tenant where name='$TENANT_NAME'"
    local TENANT_ID=`echo $QUERY | $MYSQL -u root -p$MYSQL_PASSWORD keystone`
    echo "$TENANT_ID"
}

function get_user_id {
    local USER_NAME=$1
    local QUERY="select id from user where name='$USER_NAME'"
    local USER_ID=`echo $QUERY | $MYSQL -u root -p$MYSQL_PASSWORD keystone`
    echo "$USER_ID"
}

function get_role_id {
    local ROLE_NAME=$1
    local QUERY="select id from role where name='$ROLE_NAME'"
    local ROLE_ID=`echo $QUERY | $MYSQL -u root -p$MYSQL_PASSWORD keystone`
    echo "$ROLE_ID"
}

function get_network_id {
    local NETWORK_NAME=$1
    local QUERY="select uuid from networks where label='$NETWORK_NAME'"
    local NETWORK_ID=`echo $QUERY | $MYSQL -u root -p$MYSQL_PASSWORD nova`
    echo "$NETWORK_ID"
}

function get_flavor_id {
    local INSTANCE_TYPE=$1
    local QUERY="select flavorid from instance_types where name='$INSTANCE_TYPE'"
    local FLAVOR_ID=`echo $QUERY | $MYSQL -u root -p$MYSQL_PASSWORD nova`
    echo "$FLAVOR_ID"
}

function add_tenant {
    local TENANT=$1
    local USER=$3
    local PASSWORD=$2

    $KEYSTONE tenant-create --name=$TENANT
    $KEYSTONE user-create --name=$USER --pass=${PASSWORD} \
        --email=$USER@example.com

    local USER_ID=$(get_user_id $USER)
    local TENANT_ID=$(get_tenant_id $TENANT)

    $KEYSTONE user-role-add --user $USER_ID --role $(get_role_id Member) --tenant_id $TENANT_ID
    $KEYSTONE user-role-add --user $USER_ID --role $(get_role_id sysadmin) --tenant_id $TENANT_ID
    $KEYSTONE user-role-add --user $USER_ID --role $(get_role_id netadmin) --tenant_id $TENANT_ID

    # TODO(del): add EC2 credentials.
    # $KEYSTONE ec2-create-credentials --tenant_id=$TENANT_ID \
        # --user_id=$USER_ID
}

#------------------------------------------------------------------------------
# "Create" functions
#------------------------------------------------------------------------------
function update_db {
    for H in OVS_HOSTS
    do
        $MYSQL -u root -p$MYSQL_PASSWORD -e"grant usage on *.* to root@'$H' identified by '$MYSQL_PASSWORD'; flush privileges;"
    done
}

function create_tenants {
    add_tenant demo1 nova demo1
    add_tenant demo2 nova demo2
}

function create_networks {
    $NOVA_MANAGE --flagfile=$NOVA_CONF network create \
        --label=public-net1 \
        --fixed_range_v4=11.0.0.0/24

    $NOVA_MANAGE --flagfile=$NOVA_CONF network create \
        --label=demo1-net1 \
        --fixed_range_v4=12.0.0.0/24 \
        --project_id=$(get_tenant_id demo1) \
        --priority=1

    $NOVA_MANAGE --flagfile=$NOVA_CONF network create \
        --label=demo2-net1 \
        --fixed_range_v4=13.0.0.0/24 \
        --project_id=$(get_tenant_id demo2) \
        --priority=1
}

function create_vms {
    PUBLIC_NET1_ID=$(get_network_id public-net1)
    DEMO1_NET1_ID=$(get_network_id demo1-net1)
    DEMO2_NET1_ID=$(get_network_id demo2-net1)

    export OS_TENANT_NAME=demo1
    export OS_USERNAME=demo1
    export OS_PASSWORD=nova
    VM_UUID1=`$NOVA boot --flavor $(get_flavor_id m1.tiny) \
        --image $(get_image_id) \
        --nic net-id=$PUBLIC_NET1_ID \
        --nic net-id=$DEMO1_NET1_ID \
        demo1-server1 | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`

    export OS_TENANT_NAME=demo2
    export OS_USERNAME=demo2
    export OS_PASSWORD=nova
    VM_UUID2=`$NOVA boot --flavor $(get_flavor_id m1.tiny) \
        --image $(get_image_id) \
        --nic net-id=$PUBLIC_NET1_ID \
        --nic net-id=$DEMO2_NET1_ID \
        demo2-server1 | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`

    $NOVA boot --flavor $(get_flavor_id m1.tiny) \
        --image $(get_image_id) \
        --nic net-id=$PUBLIC_NET1_ID \
        --nic net-id=$DEMO2_NET1_ID \
        demo2-server2
}

function ping_vms {

    sleep 5
    export OS_TENANT_NAME=demo1
    export OS_USERNAME=demo1
    export OS_PASSWORD=nova
    # get the IP of the servers
    PUBLIC_IP1=`nova show $VM_UUID1 | grep public-net1 | awk '{print $5}'`
    export OS_TENANT_NAME=demo2
    export OS_USERNAME=demo2
    export OS_PASSWORD=nova
    PUBLIC_IP2=`nova show $VM_UUID2 | grep public-net1 | awk '{print $5}'`

    echo "Sleeping for 60s to let the VMs come up"
    sleep 60 # Lower this if you are not using qemu - as VMs are created quicker
    MULTI_HOST=${MULTI_HOST:-0}
    if [ "$MULTI_HOST" = "0" ]; then
        # sometimes the first ping fails (10 seconds isn't enough time for the VM's
        # network to respond?), so let's ping for a default of 15 seconds with a
        # timeout of a second for each ping.
        if ! timeout $BOOT_TIMEOUT sh -c "while ! ping -c1 -w1 $PUBLIC_IP1; do sleep 1; done"; then
            echo "Couldn't ping server"
            exit 1
        fi
        if ! timeout $BOOT_TIMEOUT sh -c "while ! ping -c1 -w1 $PUBLIC_IP2; do sleep 1; done"; then
            echo "Couldn't ping server"
            exit 1
        fi
    else
        # On a multi-host system, without vm net access, do a sleep to wait for the boot
        sleep $BOOT_TIMEOUT
    fi
}

function grab_commit_ids {
    n a debuCOMMIT_ID_FILE=~/`date '+%Y%m%d%H%M%S'`-devstack-commit-ids
    pushd ..
    echo devstack `git log | head -1` >> ${COMMIT_ID_FILE}
    popd

    for repo in /opt/stack/*
    do
        cd $repo
        echo $repo `git log | head -1` >> ${COMMIT_ID_FILE}
    done
}

function all {
    update_db
    create_tenants
    create_networks
    create_vms
    ping_vms
    grab_commit_ids
}

#------------------------------------------------------------------------------
# Test functions.
#------------------------------------------------------------------------------
function test_functions {
    IMAGE=$(get_image_id)
    echo $IMAGE

    TENANT_ID=$(get_tenant_id demo) 
    echo $TENANT_ID

    FLAVOR_ID=$(get_flavor_id m1.tiny) 
    echo $FLAVOR_ID

    NETWORK_ID=$(get_network_id private) 
    echo $NETWORK_ID
}

#------------------------------------------------------------------------------
# Usage and main.
#------------------------------------------------------------------------------
usage() {
    echo "$0: [-h]"
    echo "  -h, --help     Display help message"
    echo "  -n, --net      Create networks"
    echo "  -v, --vm       Create vms"
    echo "  -t, --tenant   Create tenants"
    echo "  -T, --test     Test functions"
    echo "  -c, --commits  Get commit ids"
}

main() {
    if [ $# -eq 0 ] ; then
        usage
        exit
    fi

    echo Description
    echo
    echo Copyright 2012, Cisco Systems
    echo Copyright 2012, Nicira Networks, Inc.
    echo 
    echo Please direct any questions to dedutta@cisco.com, dlapsley@nicira.com
    echo

    while [ "$1" != "" ]; do
        case $1 in
            -h | --help )   usage
                            exit
                            ;;
            -n | --net )    create_networks
                            exit
                            ;;
            -v | --vm )     create_vms
                            exit
                            ;;
            -t | --tenant ) create_tenants
                            exit
                            ;;
            -p | --ping )   ping_vms
                            exit
                            ;;
            -T | --test )   test_functions
                            exit
                            ;;
            -c | --commits ) grab_commit_ids
                            exit
                            ;;
            -a | --all )    all
                            exit
                            ;;
            * )             usage
                            exit 1
        esac
        shift
    done
}


#-------------------------------------------------------------------------------
# Kick off script.
#-------------------------------------------------------------------------------
echo $*
main -a

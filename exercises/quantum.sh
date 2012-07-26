#!/usr/bin/env bash
#

# **quantum.sh**

# We will use this test to perform integration testing of nova and
# other components with Quantum.

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

#------------------------------------------------------------------------------
# Quantum config check
#------------------------------------------------------------------------------
# Warn if quantum is not enabled
if [[ ! "$ENABLED_SERVICES" =~ "q-svc" ]]; then
    echo "WARNING: Running quantum test without enabling quantum"
fi

#------------------------------------------------------------------------------
# Environment
#------------------------------------------------------------------------------

# Keep track of the current directory
EXERCISE_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $EXERCISE_DIR/..; pwd)

# Import common functions
source $TOP_DIR/functions

# Import configuration
source $TOP_DIR/openrc

# Import exercise configuration
source $TOP_DIR/exerciserc

# If quantum is not enabled we exit with exitcode 55 which mean
# exercise is skipped.
is_service_enabled quantum || exit 55

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
VM_NET_DELETE_TIMEOUT=${VM_NET_TIMEOUT:-15}

# Instance type to create
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}

# Boot this image, use first AMi image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# OVS Hosts
OVS_HOSTS=${DEFAULT_OVS_HOSTS:-"localhost"}

# Default Quantum Port
Q_PORT=${Q_PORT:-9696}

# Default Quantum Host
Q_HOST=${Q_HOST:-localhost}

# Default admin token
Q_ADMIN_TOKEN=${Q_ADMIN_TOKEN:-ADMIN}

#------------------------------------------------------------------------------
# Nova settings.
#------------------------------------------------------------------------------
NOVA_MANAGE=$DEST/nova/bin/nova-manage
NOVA=`which nova`

#------------------------------------------------------------------------------
# Mysql settings.
#------------------------------------------------------------------------------
MYSQL="/usr/bin/mysql --skip-column-name --host=$MYSQL_HOST"

#------------------------------------------------------------------------------
# Keystone settings.
#------------------------------------------------------------------------------
KEYSTONE="keystone"

#------------------------------------------------------------------------------
# Get a token for clients that don't support service catalog
#------------------------------------------------------------------------------

# manually create a token by querying keystone (sending JSON data).  Keystone
# returns a token and catalog of endpoints.  We use python to parse the token
# and save it.

TOKEN=`keystone token-get | grep ' id ' | awk '{print $4}'`

#------------------------------------------------------------------------------
# Various functions.
#------------------------------------------------------------------------------
function get_image_id {
    local IMAGE_ID=$(glance image-list | egrep " $DEFAULT_IMAGE_NAME " | get_field 1)
    echo "$IMAGE_ID"
}

function get_tenant_id {
    local TENANT_NAME=$1
    local TENANT_ID=`keystone tenant-list | grep $TENANT_NAME | awk '{print $2}'`
    echo "$TENANT_ID"
}

function get_user_id {
    local USER_NAME=$1
    local USER_ID=`keystone user-list | grep $USER_NAME | awk '{print $2}'`
    echo "$USER_ID"
}

function get_role_id {
    local ROLE_NAME=$1
    local ROLE_ID=`keystone role-list | grep $ROLE_NAME | awk '{print $2}'`
    echo "$ROLE_ID"
}

function get_network_id {
    local NETWORK_NAME=$1
    local NETWORK_ID=`quantum net-list | grep $NETWORK_NAME | awk '{print $4}'`
    echo "$NETWORK_ID"
}

function get_flavor_id {
    local INSTANCE_TYPE=$1
    local FLAVOR_ID=`nova flavor-list | grep $INSTANCE_TYPE | awk '{print $2}'`
    echo "$FLAVOR_ID"
}

function add_tenant {
    local TENANT=$1
    local USER=$3
    local PASSWORD=$2

    $KEYSTONE tenant-create --name=$TENANT
    $KEYSTONE user-create --name=$USER --pass=${PASSWORD}

    local USER_ID=$(get_user_id $USER)
    local TENANT_ID=$(get_tenant_id $TENANT)

    $KEYSTONE user-role-add --user-id $USER_ID --role-id $(get_role_id Member) --tenant_id $TENANT_ID
    $KEYSTONE user-role-add --user-id $USER_ID --role-id $(get_role_id admin) --tenant_id $TENANT_ID
    $KEYSTONE user-role-add --user-id $USER_ID --role-id $(get_role_id anotherrole) --tenant_id $TENANT_ID
}

function remove_tenant {
    local TENANT=$1
    local TENANT_ID=$(get_tenant_id $TENANT)
    if [ "a$TENANT_ID" != "a" ]; then
       $KEYSTONE tenant-delete $TENANT_ID
    fi
}

function remove_user {
    local USER=$1
    local USER_ID=$(get_user_id $USER)
    if [ "a$USER_ID" != "a" ]; then
       $KEYSTONE user-delete $USER_ID
    fi
}


#------------------------------------------------------------------------------
# "Create" functions
#------------------------------------------------------------------------------

function create_tenants {
    add_tenant demo1 nova demo1
    add_tenant demo2 nova demo2
}

function delete_tenants_and_users {
    remove_user demo1
    remove_user demo2
    remove_tenant demo1
    remove_tenant demo2
}

function create_networks {
    local TENANT_ID=$(get_tenant_id 'demo1')
    NET_ID=$(quantum net-create --os_token $Q_ADMIN_TOKEN --os_url http://$Q_HOST:$Q_PORT --tenant_id $TENANT_ID demo1-net1 | grep ' id ' | get_field 2)
    quantum subnet-create --os_token $Q_ADMIN_TOKEN --os_url http://$Q_HOST:$Q_PORT --tenant_id $TENANT_ID --ip_version 4 --gateway  12.0.0.1 $NET_ID 12.0.0.0/24

    local TENANT_ID=$(get_tenant_id 'demo2')
    NET_ID=$(quantum net-create --os_token $Q_ADMIN_TOKEN --os_url http://$Q_HOST:$Q_PORT --tenant_id $TENANT_ID demo2-net1 | grep ' id ' | get_field 2)
    quantum subnet-create --os_token $Q_ADMIN_TOKEN --os_url http://$Q_HOST:$Q_PORT --tenant_id $TENANT_ID --ip_version 4 --gateway  13.0.0.1 $NET_ID 13.0.0.0/24
}

function create_vms {
    DEMO1_NET1_ID=$(get_network_id demo1-net1)
    DEMO2_NET1_ID=$(get_network_id demo2-net1)

    VM_UUID1=`$NOVA --os_username demo1 --os_password nova --os_tenant_name demo1 \
        --os_auth_url http://${SERVICE_HOST}:5000/v2.0 boot \
        --flavor $(get_flavor_id m1.tiny) \
        --image $(get_image_id) \
        demo1-server1 | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`
    die_if_not_set VM_UUID1 "Failure launching demo1-server1"
    if ! timeout $ACTIVE_TIMEOUT sh -c "while ! $NOVA --os_username demo1 --os_password nova --os_tenant_name demo1 \
                                                           --os_auth_url http://${SERVICE_HOST}:5000/v2.0 show $VM_UUID1 | grep ACTIVE ; do sleep 1; done"; then
       echo "Couldn't create server"	
       exit 1
    fi

    VM_UUID2=`$NOVA --os_username demo2 --os_password nova --os_tenant_name demo2 \
        --os_auth_url http://${SERVICE_HOST}:5000/v2.0 boot \
        --flavor $(get_flavor_id m1.tiny) \
        --image $(get_image_id) \
        demo2-server1 | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`
    die_if_not_set VM_UUID2 "Failure launching demo2-server1"
    if ! timeout $ACTIVE_TIMEOUT sh -c "while ! $NOVA --os_username demo2 --os_password nova --os_tenant_name demo2 \
                                                           --os_auth_url http://${SERVICE_HOST}:5000/v2.0 show $VM_UUID2 | grep ACTIVE ; do sleep 1; done"; then
       echo "Couldn't create server"	
       exit 1
    fi
}

function ping_vms {
    # get the IP of the servers
    IP1=`$NOVA --os_username demo1 --os_password nova --os_tenant_name demo1 \
         --os_auth_url http://${SERVICE_HOST}:5000/v2.0 show $VM_UUID1 | grep network | awk '{print $5}'`

    IP2=`$NOVA --os_username demo2 --os_password nova --os_tenant_name demo2 \
         --os_auth_url http://${SERVICE_HOST}:5000/v2.0 show $VM_UUID2 | grep network | awk '{print $5}'`

    MULTI_HOST=`trueorfalse False $MULTI_HOST`
    if [ "$MULTI_HOST" = "False" ]; then
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
    else
        # On a multi-host system, without vm net access, do a sleep to wait for the boot
        sleep $BOOT_TIMEOUT
    fi
}

function shutdown_vms {
    $NOVA --os_username demo1 --os_password nova --os_tenant_name demo1 --os_auth_url http://${SERVICE_HOST}:5000/v2.0 delete $VM_UUID1
    if ! timeout $VM_NET_DELETE_TIMEOUT sh -c "while $NOVA --os_username demo1 --os_password nova --os_tenant_name demo1 \
                                                           --os_auth_url http://${SERVICE_HOST}:5000/v2.0 list | grep $VM_UUID1; do sleep 1; done"; then
       echo "Couldn't delete server"	
       exit 1
    fi

    $NOVA --os_username demo2 --os_password nova --os_tenant_name demo2 --os_auth_url http://${SERVICE_HOST}:5000/v2.0 delete $VM_UUID2
    if ! timeout $VM_NET_DELETE_TIMEOUT sh -c "while $NOVA --os_username demo2 --os_password nova --os_tenant_name demo2 \
                                                           --os_auth_url http://${SERVICE_HOST}:5000/v2.0 list | grep $VM_UUID2; do sleep 1; done"; then
       echo "Couldn't delete server"	
       exit 1
    fi
}

function delete_networks {
    DEMO1_NET1_ID=$(get_network_id demo1-net1)
    DEMO2_NET1_ID=$(get_network_id demo2-net1)
    quantum net-delete $DEMO1_NET1_ID
    quantum net-delete $DEMO2_NET1_ID
}

function all {
    create_tenants
    create_networks
    create_vms
    ping_vms
    shutdown_vms
    delete_networks
    delete_tenants_and_users
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

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"

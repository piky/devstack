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
#set -o errexit
set -o errtrace
trap failed ERR
failed() {
    local r=$?
    set +o errtrace
    set +o xtrace
    echo "Faild to execute"
    echo "Staring cleanup..."
    delete_all
    echo "Finish cleanup"
    exit $r
}

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

QUANTUM=quantum

#------------------------------------------------------------------------------
# Various default parameters.
#------------------------------------------------------------------------------

# Time to wait between boots to avoid overwhelming small systems
INTER_BOOT_PAUSE=${INTER_BOOT_PAUSE:-10}

# Max time to wait while vm goes from build to active state
ACTIVE_TIMEOUT=${ACTIVE_TIMEOUT:-30}

# Max time till the vm is bootable
BOOT_TIMEOUT=${BOOT_TIMEOUT:-60}

# Max time to wait before delete VMs and delete Networks
VM_NET_DELETE_TIMEOUT=${VM_NET_DELETE_TIMEOUT:-10}

# Instance type to create
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}

# Boot this image, use first AMi image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# OVS Hosts
OVS_HOSTS=${DEFAULT_OVS_HOSTS:-"localhost"}

#------------------------------------------------------------------------------
# Quantum settings.
#------------------------------------------------------------------------------
QUANTUM=quantum

#------------------------------------------------------------------------------
# Nova settings.
#------------------------------------------------------------------------------
NOVA_MANAGE=/opt/stack/nova/bin/nova-manage
NOVA=/usr/local/bin/nova
NOVA_CONF=/etc/nova/nova.conf

#------------------------------------------------------------------------------
# Test settings
#------------------------------------------------------------------------------

TENANTS="DEMO1,DEMO2"

PUBLIC_NAME="admin"
DEMO1_NAME="demo1"
DEMO2_NAME="demo2"

PUBLIC_NET_CIDR="200.0.0.0/24"
DEMO1_NET_CIDR="190.0.0.0/24"
DEMO2_NET_CIDR="190.0.1.0/24"

PUBLIC_NET_GATEWAY="200.0.0.1"
DEMO1_NET_GATEWAY="190.0.0.1"
DEMO2_NET_GATEWAY="190.0.1.1"

PUBLIC_NUM_VM=1
DEMO1_NUM_VM=1
DEMO2_NUM_VM=2

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
function foreach_tenant {
    COMMAND=$1
    for TENANT in ${TENANTS//,/ };do
        eval ${COMMAND//%TENANT%/$TENANT}
    done
}

function foreach_tenant_vm {
    COMMAND=$1
    for TENANT in ${TENANTS//,/ };do
        eval 'NUM=$'"${TENANT}_NUM_VM"
        for i in `seq $NUM`;do
            local COMMAND_LOCAL=${COMMAND//%TENANT%/$TENANT}
            COMMAND_LOCAL=${COMMAND_LOCAL//%NUM%/$i}
            eval $COMMAND_LOCAL
        done
    done
}

function get_image_id {
    local IMAGE_ID=$(glance image-list | egrep " $DEFAULT_IMAGE_NAME " | get_field 1)
    echo "$IMAGE_ID"
}

function get_tenant_id {
    local TENANT_NAME=$1
    local TENANT_ID=`keystone tenant-list | grep " $TENANT_NAME " | head -n 1 | get_field 1`
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
    local NETWORK_NAME="$1-net"
    local NETWORK_ID=`quantum net-list -F id  -- --name=$NETWORK_NAME | awk "NR==4" | awk '{print $2}'`
    echo $NETWORK_ID
}

function get_flavor_id {
    local INSTANCE_TYPE=$1
    local FLAVOR_ID=`nova flavor-list | grep $INSTANCE_TYPE | awk '{print $2}'`
    echo "$FLAVOR_ID"
}

function confirm_server_active {
    local VM_UUID=$1
    if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova show $VM_UUID | grep status | grep -q ACTIVE; do sleep 1; done"; then
    echo "server '$VM_UUID' did not become active!"
    false
fi

}

function add_tenant {
    local TENANT=$1
    local USER=$2

    $KEYSTONE tenant-create --name=$TENANT
    $KEYSTONE user-create --name=$USER --pass=${ADMIN_PASSWORD}

    local USER_ID=$(get_user_id $USER)
    local TENANT_ID=$(get_tenant_id $TENANT)

    $KEYSTONE user-role-add --user-id $USER_ID --role-id $(get_role_id Member) --tenant-id $TENANT_ID
}

function remove_tenant {
    local TENANT=$1
    local TENANT_ID=$(get_tenant_id $TENANT)

    $KEYSTONE tenant-delete $TENANT_ID
}

function remove_user {
    local USER=$1
    local USER_ID=$(get_user_id $USER)

    $KEYSTONE user-delete $USER_ID
}



#------------------------------------------------------------------------------
# "Create" functions
#------------------------------------------------------------------------------

function create_tenants {
    source $TOP_DIR/openrc admin admin
    add_tenant demo1 demo1 demo1
    add_tenant demo2 demo2 demo2
}

function delete_tenants_and_users {
    source $TOP_DIR/openrc admin admin
    remove_user demo1
    remove_tenant demo1
    remove_user demo2
    remove_tenant demo2
}

function create_network {
    local TENANT=$1
    local GATEWAY=$2
    local CIDR=$3
    local NAME="${TENANT}-net"
    source $TOP_DIR/openrc admin admin
    local TENANT_ID=$(get_tenant_id $TENANT)
    source $TOP_DIR/openrc $TENANT $TENANT
    local NET_ID=$($QUANTUM net-create --tenant_id $TENANT_ID $NAME| grep ' id ' | awk '{print $4}' )
    $QUANTUM subnet-create --ip_version 4 --tenant_id $TENANT_ID --gateway $GATEWAY $NET_ID $CIDR
}

function create_networks {
    foreach_tenant 'create_network ${%TENANT%_NAME} ${%TENANT%_NET_GATEWAY} ${%TENANT%_NET_CIDR}'

    #TODO(nati) test security group function
    # allow ICMP for both tenant's security groups
    #source $TOP_DIR/openrc demo1 demo1
    #$NOVA secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    #source $TOP_DIR/openrc demo2 demo2
    #$NOVA secgroup-add-rule default icmp -1 -1 0.0.0.0/0
}

function create_vm {
    local TENANT=$1
    local NUM=$2
    source $TOP_DIR/openrc $TENANT $TENANT
    local NET_ID=$(get_network_id $TENANT)
    #TODO (nati) Add multi-nic test
    #TODO (nati) Add public-net test
    local VM_UUID=`$NOVA boot --flavor $(get_flavor_id m1.tiny) \
        --image $(get_image_id) \
        --nic net-id=$NET_ID \
        $TENANT-server$NUM | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`
    die_if_not_set VM_UUID "Failure launching $TENANT-server$NUM" VM_UUID
    sleep $INTER_BOOT_PAUSE
    confirm_server_active $VM_UUID

}

function create_vms {
    foreach_tenant_vm 'create_vm ${%TENANT%_NAME} %NUM%'
}

function ping_ip {
    local IP=$1
    if ! timeout $BOOT_TIMEOUT sh -c "while ! ping -c1 -w1 $IP; do sleep 1; done"; then
        echo "Couldn't ping server"
        exit 1
    fi
}

function check_vm {
    local TENANT=$1
    local NUM=$2
    source $TOP_DIR/openrc $TENANT $TENANT
    local IP=`nova show ${TENANT}-server$NUM | grep ${TENANT}-net | awk '{print $5}'`
    die_if_not_set IP "Failure to get IP"
    ping_ip $IP
    # TODO (nati) test ssh connection
    # TODO (nati) test private network connection using test-agent
    # TODO (nati) test inter connection between vm
    # TODO (nati) test namespace dhcp
    # TODO (nati) test dhcp host routes
    # TODO (nati) test multi-nic
    # TODO (nati) test L3 forwarding
    # TODO (nati) test floating ip
    # TODO (nati) test security group
}

function check_vms {
    foreach_tenant_vm 'check_vm ${%TENANT%_NAME} %NUM%'
}

function shutdown_vm {
    local TENANT=$1
    local NUM=$2
    source $TOP_DIR/openrc $TENANT $TENANT
    nova delete ${TENANT}-server$NUM
}

function shutdown_vms {
    foreach_tenant_vm 'shutdown_vm ${%TENANT%_NAME} %NUM%'
}

function delete_network {
    local TENANT=$1
    source $TOP_DIR/openrc admin admin
    local TENANT_ID=$(get_tenant_id $TENANT)
    for res in port subnet net;do
        quantum ${res}-list -F id -F tenant_id | grep $TENANT_ID | awk '{print $2}' | xargs -I % quantum ${res}-delete %
    done
}

function delete_networks {
   foreach_tenant 'delete_network ${%TENANT%_NAME}'
   #TODO(nati) add secuirty group check after it is implemented
   # source $TOP_DIR/openrc demo1 demo1
   # nova secgroup-delete-rule default icmp -1 -1 0.0.0.0/0
   # source $TOP_DIR/openrc demo2 demo2
   # nova secgroup-delete-rule default icmp -1 -1 0.0.0.0/0
}

function create_all {
    create_tenants
    create_networks
    create_vms
}

function delete_all {
    shutdown_vms
    # make sure VM ports are torn down before removing nets
    sleep $VM_NET_DELETE_TIMEOUT
    delete_networks
    delete_tenants_and_users
}

function all {
    create_all
    check_vms
    delete_all
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

    NETWORK_ID=$(get_network_id admin)
    echo $NETWORK_ID
}

#------------------------------------------------------------------------------
# Usage and main.
#------------------------------------------------------------------------------
usage() {
    echo "$0: [-h]"
    echo "  -h, --help              Display help message"
    echo "  -t, --tenant            Create tenants"
    echo "  -n, --net               Create networks"
    echo "  -v, --vm                Create vms"
    echo "  -c, --check             Check connection"
    echo "  -x, --delete-tenants    Delete tenants"
    echo "  -y, --delete-nets       Delete networks"
    echo "  -z, --delete-vms        Delete vms"
    echo "  -T, --test              Test functions"
}

main() {

    echo Description
    echo
    echo Copyright 2012, Cisco Systems
    echo Copyright 2012, Nicira Networks, Inc.
    echo Copyright 2012, NTT MCL, Inc.
    echo
    echo Please direct any questions to dedutta@cisco.com, dan@nicira.com, nachi@nttmcl.com
    echo


    if [ $# -eq 0 ] ; then
        # if no args are provided, run all tests
        all
    else

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
                -c | --check )   check_vms
                                exit
                                ;;
                -T | --test )   test_functions
                                exit
                                ;;
                -x | --delete-tenants ) delete_tenants_and_users
                                exit
                                ;;
                -y | --delete-nets ) delete_networks
                                exit
                                ;;
                -z | --delete-vms ) shutdown_vms
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
    fi
}


#-------------------------------------------------------------------------------
# Kick off script.
#-------------------------------------------------------------------------------
echo $*
main $*

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"

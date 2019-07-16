#!/bin/bash
#
#
# NOTE(gmann): This script is used in 'devstack-ipv6' zuul job to verify that services are deployed
# on IPv6 properly or not. This will capture if any service's devstack plugins is missing the
# required setting to listen on IPv6 address. This is run as post-run of zuul job so any child
# job can expand the IPv6 verification specific to project via defining new post-run script which
# will run along with this base script.
# If there are more common verification for IPv6 then we can always extent this script.

# Keep track of the DevStack directory
TOP_DIR=$(cd $(dirname "$0")/.. && pwd)
echo $TOP_DIR
source $TOP_DIR/stackrc
source $TOP_DIR/openrc admin admin

function verify_devstack_ipv6_setting {
    if [[ "$SERVICE_IP_VERSION" != 6 ]]; then
        echo $SERVICE_IP_VERSION "SERVICE_IP_VERSION is not set to 6 which is must for devstack to deploy services with IPv6 address."
        exit 1
    fi
    if [[ "$SERVICE_HOST" != "$HOST_IPV6" ]]; then
        echo "SERVICE_HOST and HOST_IPV6 are set with different value. Do not set SERVICE_HOST explicitly to let Devstack deploy serviecs on iIPv6."
        exit 1
    fi
    local local_service_host=$(echo $SERVICE_HOST | tr -d [])
    is_service_host_ipv6=$(python -c 'import oslo_utils.netutils as nutils; print nutils.is_valid_ipv6("'$local_service_host'")')
    if [[ "$is_service_host_ipv6" != "True" ]]; then
        echo $SERVICE_HOST "SERVICE_HOST is not ipv6 which means devstack cannot deploy services on IPv6 address."
        exit 1
    fi
}

function sanity_check_system_ipv6_enabled {
    system_ipv6_enabled=$(python -c 'import oslo_utils.netutils as nutils; print nutils.is_ipv6_enabled()')
    if [[ $system_ipv6_enabled != "True" ]]; then
        echo "IPv6 is disabled in system"
        exit 1
    fi
}

function verify_service_listen_address_is_ipv6 {
    endpoints=$(openstack endpoint list -f value -c URL)
    local all_ipv6=True
    for endpoint in ${endpoints}; do
        local endpoint_address=$(echo "$endpoint" | awk -F/ '{print $3}' | awk -F] '{print $1}')
        endpoint_address=$(echo $endpoint_address | tr -d [])
        local is_endpoint_ipv6=$(python -c 'import oslo_utils.netutils as nutils; print nutils.is_valid_ipv6("'$endpoint_address'")')
        if [[ "$is_endpoint_ipv6" != "True" ]]; then
            all_ipv6=False
            echo $endpoint ": This is not ipv6 endpoint which means corresponding service is not listening on IPv6 address."
            continue
        fi
    done
    if [[ "$all_ipv6" == "False"  ]]; then
        exit 1
    fi
}

#First thing to verify if system has IPv6 enabled or not
sanity_check_system_ipv6_enabled
#Verify whether devstack is configured properly with IPv6 setting
verify_devstack_ipv6_setting
#Get all registrfed endpoints by devstack in keystone and verify that each endpoints address is IPv6.
verify_service_listen_address_is_ipv6

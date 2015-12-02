#!/bin/bash

# **move_ip.sh**

# ``move_ip.sh`` moves the IP address and the route from the public interface over to the OVS bridge if
#  the l3 agent was enabled.  This logic is done during stack.sh, but if then system is rebooted,
#  connectivity to the IP address is lost.

# Keep track of the current devstack directory.
TOP_DIR=$(cd $(dirname "$0")/.. && pwd)

# Load local configuration
source $TOP_DIR/openrc

# Source neutron library
source $TOP_DIR/lib/neutron-legacy

if is_service_enabled q-l3; then
    _move_neutron_addresses_route "$PUBLIC_INTERFACE" "$OVS_PHYSICAL_BRIDGE" False "inet"
    if [[ $(ip -f inet6 a s dev "$PUBLIC_INTERFACE" | grep -c 'global') != 0 ]]; then
        _move_neutron_addresses_route "$PUBLIC_INTERFACE" "$OVS_PHYSICAL_BRIDGE" False "inet6"
    fi
fi

# midonet.sh - Midonet virtual infrastructure

if is_service_enabled midonet; then

    if [[ "$1" == "source" ]]; then

        # Disable the q-agt and q-l3 services
        disable_service q-agt
        disable_service q-l3

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then

        # To allow connectivity from the host to the 'external' devstack host network
        # we are going to create the following topology and route the packages properly.
        #
        # 'MidoNet Provider Router' should already have been created by previous scripts.
        #
        #
        #                           
        #          +------------------+---------------+
        #          |                                  |
        #          |     fakeuplink linux bridge      |
        #          |                                  |
        #          +------------------+---------------+        'REAL' WORLD
        #                             | veth0 (172.19.0.1/30)
        #                             |
        #                             |
        #                             |
        # +----------------------------------------------------+
        #                             |
        #                             |
        #                             |
        #               172.19.0.2/30 | veth1
        #          +------------------+----------------+        'VIRTUAL' WORLD
        #          |                                   |
        #          |      MidoNet Provider Router      |
        #          |                                   |
        #          +------------------+----------------+
        #                             |  $FLOATING_RANGE (172.24.4.0/24 by default)
        #                             |
        #             +---------------+----------------+
        #             ^         ^            ^         ^
        #             |         |            |         |
        #           (TR)       (TR)        (TR)      (TR)
        #
        # (TR) stands for Tenant routers
        # All the N-S traffic that comes from overlay virtual network gets forwarded to the
        # underlay fakeuplink linux bridge and vice versa. It is called fakeuplink because 
        # it simulates a comunication between two 'edge' internet routers.

        # Create the veth interfaces
        sudo ip link add type veth
        sudo ip link set dev veth0 up
        sudo ip link set dev veth1 up

        # create the linux bridge, give to it an IP address and attach the veth0 interface
        sudo brctl addbr uplinkbridge
        sudo brctl addif uplinkbridge veth0
        sudo ip addr add 172.19.0.1/30 dev uplinkbridge
        sudo ip link set dev uplinkbridge up

        # allow ip forwarding
        sudo sysctl -w net.ipv4.ip_forward=1

        # route packets from physical underlay network to the bridge if the destination
        # belongs to the floating range
        sudo ip route add $FLOATING_RANGE via 172.19.0.2

        # Here we initialize the MidoNet virtual infrastructure
        PROVIDER_ROUTER_NAME='MidoNet Provider Router'
        PROVIDER_ROUTER_ID=$(midonet-cli -e router list | \
            grep "$PROVIDER_ROUTER_NAME" | \
            awk '{ print $2 }')
        die_if_not_set $LINENO PROVIDER_ROUTER_ID "FAILED to find a provider router"
        echo "Found MidoNet Provider Router with ID ${PROVIDER_ROUTER_ID}"

        # Add a port in the MidoNet Provider Router that will be part of a /30 network
        PROVIDER_PORT_ID=$(midonet-cli -e router $PROVIDER_ROUTER_ID add \
            port address 172.19.0.2 net 172.19.0.0/30)
        die_if_not_set $LINENO PROVIDER_PORT_ID "FAILED to create port on provider router"

        # Create a route to push all the packets from this end of the /30 network to the other end
        ROUTE=$(midonet-cli -e router $PROVIDER_ROUTER_ID add route \
            src 0.0.0.0/0 dst 0.0.0.0/0 type normal port router $PROVIDER_ROUTER_ID \
            port $PROVIDER_PORT_ID gw 172.19.0.1)
        die_if_not_set $LINENO ROUTE "FAILED to create route on provider router"

        # All hosts must belong to a tunnel zone. Create the tunnel zone
        TUNNEL_ZONE_ID=$(midonet-cli -e create tunnel-zone name default_tz type gre)
        die_if_not_set $LINENO TUNNEL_ZONE_ID "FAILED to create tunnel zone"

        # Get the host id of the devstack machine
        HOST_ID=$(midonet-cli -e host list | awk '{ print $2 }')
        die_if_not_set $LINENO HOST_ID "FAILED to obtain host id"

        # add our host as a member to the tunnel zone
        MEMBER=$(midonet-cli -e tunnel-zone $TUNNEL_ZONE_ID add member \
            host $HOST_ID address 172.19.0.2)
        die_if_not_set $LINENO MEMBER "FAILED to create tunnel zone member"
        echo "Added member ${MEMBER} to the tunnel zone"

        # Bind the virtual port to the veth interface
        BINDING=$(midonet-cli -e host $HOST_ID add binding \
            port router $PROVIDER_ROUTER_ID port $PROVIDER_PORT_ID interface veth1)
        die_if_not_set $LINENO BINDING "FAILED to create host binding"

    elif [[ "$1" == "unstack" ]]; then
        # Remove the router
        sudo ip link set dev uplinkbridge down
        sudo brctl delbr uplinkbridge
        sudo ip link set veth0 down
        sudo ip link set veth1 down
        sudo ip link del veth0
        sudo ip link del veth1
    fi
fi

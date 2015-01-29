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
        # The called script prepares this setup
        $MIDONET_DIR/tools/devmido/create_fake_uplink.sh

    elif [[ "$1" == "unstack" ]]; then
        # Remove the previous setup
        $MIDONET_DIR/tools/devmido/delete_fake_uplink.sh
    fi
fi

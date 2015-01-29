# midonet.sh - Midonet virtual infrastructure

if is_service_enabled midonet; then

    if [[ "$1" == "source" ]]; then

        # Disable the q-agt and q-l3 services
        disable_service q-agt
        disable_service q-l3

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then

        # To allow connectivity from the OpenStack VMs to the pyhisical
        # devstack host network we are going to create a fake uplink to bind
        # virtual and physical devices.  Details of this script can be seen
        # in:
        #   $MIDONET_DIR/tools/devmido/README.md
        source $MIDONET_DIR/tools/devmido/midostack.sh create_fake_uplink

    elif [[ "$1" == "unstack" ]]; then
        # Remove the previous setup
        source $MIDONET_DIR/tools/devmido/midostack.sh delete_fake_uplink
    fi
fi

# opendaylight.sh - DevStack extras script

if is_service_enabled opendaylight-compute; then
    if [[ "$1" == "source" ]]; then
        # no-op
        :
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        # no-op
        :
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        # OpenDaylight configuration comes after all services are up
        :
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing OpenDaylight"
        ODL_LOCAL_IP=${ODL_LOCAL_IP:-$HOST_IP}
        ODL_MGR_PORT=${ODL_MGR_PORT:-6640}
        read ovstbl <<< $(sudo ovs-vsctl get Open_vSwitch . _uuid)
        sudo ovs-vsctl set-manager tcp:$ODL_MGR_IP:$ODL_MGR_PORT
        sudo ovs-vsctl set Open_vSwitch $ovstbl other_config={"local_ip"="$ODL_LOCAL_IP"}
    elif [[ "$1" == "stack" && "$2" == "post-extra" ]]; then
        # no-op
        :
    fi

    if [[ "$1" == "unstack" ]]; then
        sudo ovs-vsctl del-manager
        BRIDGES=$(sudo ovs-vsctl list-br)
        for bridge in $BRIDGES ; do
            sudo ovs-vsctl del-controller $bridge
        done
    fi

    if [[ "$1" == "clean" ]]; then
        # no-op
        :
    fi
fi

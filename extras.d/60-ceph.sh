# ceph.sh - Devstack extras script to install Ceph and radosgw

if is_service_enabled ceph radosgw; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/storages/ceph
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Ceph"
        install_storage_ceph
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring Ceph"
        configure_storage_ceph
        echo_summary "Initializing Ceph"
        init_storage_ceph
        echo_summary "Starting Ceph"
        start_storage_ceph
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_storage_ceph
        cleanup_storage_ceph
    fi

    if [[ "$1" == "clean" ]]; then
        cleanup_storage_ceph
    fi
fi

if is_service_enabled radosgw ; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/storages/ceph_radosgw
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Ceph RadosGateway"
        install_ceph_radosgw
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring Ceph RadosGateway"
        configure_ceph_radosgw
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing and Starting Ceph RadosGateway"
        start_ceph_radosgw
    fi

    if [[ "$1" == "unstack" ]]; then
        cleanup_ceph_radosgw
    fi
fi

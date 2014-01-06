# ceph.sh - Devstack extras script to install Ceph

if is_service_enabled ceph; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/storages/ceph
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Ceph"
        install_storage_ceph
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring Ceph"
        configure_storage_ceph

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing Ceph"
        init_storage_ceph
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

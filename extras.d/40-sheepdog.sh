# sheepdog.sh - Devstack extras script to enable sheepdog storage backend

if is_service_enabled sheepdog; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/sheepdog
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Sheepdog"
        install_sheepdog
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        # NOTE (scott-devoid): we do everything here because we need to have
        # sheepdog started before other openstack components, e.g. glance in
        # order to upload images to the sheepdog cluster.
        echo_summary "Configuring Sheepdog cluster"
        configure_sheepdog
        echo_summary "Starting Sheepdog cluster"
        start_sheepdog
    fi
    if [[ "$1" == "unstack" ]]; then
        echo_summary "Stopping Sheepdog cluster"
        stop_sheepdog
    fi
    if [[ "$1" == "clean" ]]; then
        echo_summary "Clearing Sheepdog cluster of data"
        cleanup_sheepdog
    fi
fi

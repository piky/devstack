# sheepdog.sh - DevStack extras script to install Sheepdog

if is_service_enabled sheepdog; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/sheepdog
    elif [[ "$1" == "stack" && "$2" == "pre-install" ]]; then
        echo_summary "Installing Sheepdog"
        check_os_support_sheepdog
        install_sheepdog
        echo_summary "Configuring Sheepdog"
        configure_sheepdog
        # NOTE (leseb): Do everything here because we need to have Sheepdog started before the main
        # OpenStack components. Sheepdog OSD must start here otherwise we can't upload any images.
        echo_summary "Initializing Sheepdog"
        init_sheepdog
        start_sheepdog
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        if is_service_enabled cinder; then
            echo_summary "Configuring Cinder for Sheepdog"
            configure_sheepdog_cinder
        fi
    fi

    if [[ "$1" == "unstack" ]]; then
        cleanup_sheepdog
        stop_sheepdog
    fi

    if [[ "$1" == "clean" ]]; then
        cleanup_sheepdog
    fi
fi

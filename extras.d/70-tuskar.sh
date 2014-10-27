# tuskar.sh - Devstack extras script to install Tuskar

if is_service_enabled tuskar; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/tuskar
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Tuskar"
        install_tuskarclient
        install_tuskar
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring Tuskar"
        configure_tuskar
        configure_tuskarclient

        if is_service_enabled key; then
            create_tuskar_accounts
        fi

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing Tuskar"
        init_tuskar
        start_tuskar
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_tuskar
    fi
fi

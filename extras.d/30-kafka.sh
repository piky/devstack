# kafka.sh - DevStack extras script to install Kafka

if is_service_enabled kafka; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/kafka

    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        # Perform installation of service source
        echo_summary "Installing kafka"
        install_kafka

        echo_summary "Initializing kafka"
        init_kafka

    elif [[ "$1" == "unstack" ]]; then
        # Shut down kafka services
        echo_summary "Shut down kafka service"
        stop_kafka

    elif [[ "$1" == "clean" ]]; then
        # Remove state and transient data
        # Remember clean.sh first calls unstack.sh
        echo_summary "Clean up kafka service"
        cleanup_kafka
    fi
fi

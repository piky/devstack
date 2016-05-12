# tempest.sh - DevStack extras script

if is_service_enabled tempest; then
    if [[ "$1" == "source" ]]; then
        echo_summary "Initial tempest source"
        source $TOP_DIR/lib/tempest
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Tempest"
        install_tempest
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing Tempest"
        configure_tempest
    fi
fi

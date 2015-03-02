# memtracker -- very frequent system snapshots

if is_service_enabled memtracker; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/memtracker
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        # no-op
        :
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        # no-op
        :
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        start_memtracker
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_memtracker
    fi

    if [[ "$1" == "clean" ]]; then
        # no-op
        :
    fi
fi

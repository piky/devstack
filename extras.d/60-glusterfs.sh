# glusterfs.sh - DevStack extras script to install GlusterFS

if is_service_enabled glusterfs; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/glusterfs
    elif [[ "$1" == "stack" && "$2" == "pre-install" ]]; then
        echo_summary "Installing GlusterFS"
        install_glusterfs
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        if is_service_enabled cinder; then
            echo_summary "Configuring Cinder for GlusterFS"
            configure_glusterfs_cinder
        fi
    fi

    if [[ "$1" == "unstack" ]]; then
        cleanup_glusterfs
        stop_glusterfs
    fi

    if [[ "$1" == "clean" ]]; then
        cleanup_glusterfs
    fi
fi

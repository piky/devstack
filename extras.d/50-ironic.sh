# ironic.sh - Devstack extras script to install ironic

if is_service_enabled ir-api ir-cond; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/ironic
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Ironic"
        install_ironic
        install_ironicclient
        cleanup_ironic
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring Ironic"
        configure_ironic

        if is_service_enabled key; then
            create_ironic_accounts
        fi

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        # Initialize ironic
        init_ironic

        # Start the ironic API and ironic taskmgr components
        echo_summary "Starting Ironic"
        start_ironic

        if is_service_enabled g-api g-reg ir-api ir-cond n-api n-cond n-cpu q-svc q-dhcp q-agt key; then
            if [[ "$IRONIC_BAREMETAL_BASIC_OPS" = "True" ]]; then
                TOKEN=$(keystone token-get | grep ' id ' | get_field 2)
                die_if_not_set $LINENO TOKEN "Keystone fail to get token"

                echo_summary "Creating and uploading baremetal images for ironic"

                # build and upload separate deploy kernel & ramdisk
                upload_baremetal_deploy $TOKEN

                # upload images, separating out the kernel & ramdisk for PXE boot
                for image_url in ${IMAGE_URLS//,/ }; do
                    upload_baremetal_image $image_url $TOKEN
                done

                create_brigde_and_vms
                enroll_vms
            fi
        fi
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_ironic
        rm -f $IRONIC_VM_MACS_CSV_FILE 
        sudo pkill tftpd
    fi

    if [[ "$1" == "clean" ]]; then
        cleanup_ironic
    fi
fi

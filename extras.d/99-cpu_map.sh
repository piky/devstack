# cpu_map.sh - Extras script to install custom cpu_map
if is_service_enabled n-cpu; then
    if [[ "$1" == "stack" && "$2" == "install" && "$VIRT_DRIVER" == "libvirt" ]]; then
        echo_summary "Updating CPU Map"
        local core2duo=0
        local model=0
        while read line ; do
            echo $line
            if [[ "$line" =~ "<model name='core2duo'>" ]] && [[ "$core2duo" -eq 0 ]] ; then
                core2duo=1
            elif [[ "$line" =~ "</model>" ]] && [[ "$core2duo" -eq 1 ]] && [[ "$model" -eq 0 ]] ; then
                model=1
            fi
            if [[ "$core2duo" -eq 1 ]] && [[ "$model" -eq 1 ]] ; then
                echo "<model name='gate64'>"
                echo "<model name='core2duo'/>"
                echo "<feature policy='disable' name='monitor'/>"
                echo "<feature policy='disable' name='pse36'/>"
                echo "</model>"
                core2duo="done"
                model="done"
            fi
        done < /usr/share/libvirt/cpu_map.xml > tmp_cpu_map.xml
        sudo cp tmp_cpu_map.xml /usr/share/libvirt/cpu_map.xml
        # Do a stop then start as a restart does not appear to be sufficient.
        stop_service libvirt-bin
        start_service libvirt-bin
    fi
fi

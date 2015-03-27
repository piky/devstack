# cpu_map.sh - Extras script to install custom cpu_map
if is_service_enabled n-cpu; then
    if [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Updating CPU Map"
        local pentiumpro=0
        local model=0
        while read line ; do
            echo $line
            if [[ "$line" =~ "<model name='pentiumpro'>" ]] && [[ "$pentiumpro" -eq 0 ]] ; then
                pentiumpro=1
            elif [[ "$line" =~ "</model>" ]] && [[ "$pentiumpro" -eq 1 ]] && [[ "$model" -eq 0 ]] ; then
                model=1
            fi
            if [[ "$pentiumpro" -eq 1 ]] && [[ "$model" -eq 1 ]] ; then
                echo "<model name='gate64'>"
                echo "<model name='pentiumpro'/>"
                echo "<feature name='lm'/>"
                echo "</model>"
                pentiumpro="done"
                model="done"
            fi
        done < /usr/share/libvirt/cpu_map.xml > tmp_cpu_map.xml
        sudo cp tmp_cpu_map.xml /usr/share/libvirt/cpu_map.xml
        # Do a stop then start as a restart does not appear to be sufficient.
        stop_service libvirt-bin
        start_service libvirt-bin
    fi
fi

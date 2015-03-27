# cpu_map.sh - Extras script to install custom cpu_map
if is_service_enabled n-cpu; then
    if [[ "$1" == "install" ]]; then
        local x86=0
        local models=0
        while read line ; do
            echo $line
            if [[ "$line" =~ "<arch name='x86'>" ]] && [[ "$x86" -eq 0 ]] ; then
                x86=1
            elif [[ "$line" =~ "</model>" ]] && [[ "$model" -eq 0 ]] ; then
                models=1
            fi
            if [[ "$x86" -eq 1 ]] && [[ "$models" -eq 1 ]] ; then
                echo "<model name='gate64'>"
                echo "<model name='pentiumpro'/>"
                echo "<feature name='lm'/>"
                echo "</model>"
                x86="done"
                models="done"
            fi
        done < /usr/share/libvirt/cpu_map.xml > tmp_cpu_map.xml
        sudo cp tmp_cpu_map.xml /usr/share/libvirt/cpu_map.xml
        sudo restart libvirt-bin
    fi
fi

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
                # Create cpu model that is core2duo less
                # monitor and pse36 features.
                echo "<model name='gate64'>"
                echo "<vendor name='Intel'/>"
                echo "<feature name='fpu'/>"
                echo "<feature name='de'/>"
                echo "<feature name='pse'/>"
                echo "<feature name='tsc'/>"
                echo "<feature name='msr'/>"
                echo "<feature name='pae'/>"
                echo "<feature name='mce'/>"
                echo "<feature name='cx8'/>"
                echo "<feature name='apic'/>"
                echo "<feature name='sep'/>"
                echo "<feature name='pge'/>"
                echo "<feature name='cmov'/>"
                echo "<feature name='pat'/>"
                echo "<feature name='mmx'/>"
                echo "<feature name='fxsr'/>"
                echo "<feature name='sse'/>"
                echo "<feature name='sse2'/>"
                echo "<feature name='vme'/>"
                echo "<feature name='mtrr'/>"
                echo "<feature name='mca'/>"
                echo "<feature name='clflush'/>"
                echo "<feature name='pni'/>"
                echo "<feature name='nx'/>"
                echo "<feature name='ssse3'/>"
                echo "<feature name='syscall'/>"
                echo "<feature name='lm'/>"
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

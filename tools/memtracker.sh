#!/bin/bash

# track memory usage, processes and wait-channels very frequently for
# diagnosing long-running or out-of-memory jobs

while [ 1 ]; do

    echo "---"

    # timestamp that helps correlate with openstack logs

    date -u +"%Y-%m-%dT%H:%M:%SZ"

    cat /proc/meminfo

    # pid , %memory , cputime, thread-count, wait-channel, command, args
    ps -eo pid:10,pmem:6,cputime:10,nlwp:8,wchan:25,comm:25,args:100

    echo "==="

    sleep ${MEMTRACKER_SLEEP:-2}

done

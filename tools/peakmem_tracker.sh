#!/usr/bin/env bash

set -o errexit

# time to sleep between checks
SLEEP_TIME=10

# MemAvailable is the best estimation and has built-in heuristics
# around reclaimable memory.  However, it is not available until 3.14
# kernel (i.e. Ubuntu LTS Trusty misses it).  In that case, we fall
# back to free+buffers+cache as the available memory.
USE_MEM_AVAILBLE=0
if grep -q '^MemAvailable:' /proc/meminfo; then
    USE_MEM_AVAILABLE=1
fi

function get_mem_available {
    if [[ $USE_MEM_AVAILABLE -eq 1 ]]; then
        awk '/^MemAvailable:/ {print $2}' /proc/meminfo
    else
        awk '/^MemFree:/ {free=$2}
            /^Buffers:/ {buffers=$2}
            /^Cached:/  {cached=$2}
            END { print free+buffers+cached }' /proc/meminfo
    fi
}

# whenever we see less memory available than last time, dump the
# snapshot of current usage; i.e. checking the latest entry in the
# file will give the peak-memory usage
function tracker {
    local low_point=$(get_mem_available)
    while [ 1 ]; do

        local mem_available=$(get_mem_available)

        if [[ $mem_available -lt $low_point ]]; then
            low_point=$mem_available
            echo "[[["
            date
            echo "---"
            cat /proc/meminfo
            echo "---"
            # would hierarchial view be more useful (-H)?  output is
            # not sorted by usage then, however.
            ps --sort=-pmem -eo pid:10,pmem:6,rss:15,ppid:10,cputime:10,nlwp:8,wchan:25,args:100
            echo "]]]"
        fi

        sleep $SLEEP_TIME
    done
}

function usage {
    echo "Usage: $0 [-x] [-s N]" 1>&2
    exit 1
}

while getopts ":s:x" opt; do
    case $opt in
        s)
            SLEEP_TIME=$OPTARG
            ;;
        x)
            set -o xtrace
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

tracker

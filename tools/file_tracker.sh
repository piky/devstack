#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

set -o errexit

# time to sleep between checks
SLEEP_TIME=20

function tracker {
    echo "Number of open files | Number of open files not in use | Maximum number of files allowed to be opened"
    while true; do
        cat /proc/sys/fs/file-nr
        pid_high_fd=$(sudo bash -c 'for pid in /proc/[0-9]*; do p=$(basename $pid); printf "%4d FDs for PID %6d\\n" $(ls $pid/fd 2>/dev/null | wc -l) $p; done |sort -nr|head -1|rev|cut -d" " -f 1|rev')
        echo PID: $pid_high_fd
        if [[ ${pid_high_fd} != "" ]]; then
            fd_cmd="ls -l /proc/${pid_high_fd}/fd"
            fd_count=$(sudo $fd_cmd |wc -l)
            echo FD Count: $fd_count
            if ((${fd_count} > 700)); then
                echo "================================"
                echo "Open file number is over 700, file list below:"
                sudo ${fd_cmd}
                echo "================================"
            fi
            sleep $SLEEP_TIME
        fi
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

tracker

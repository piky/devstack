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

PYTHON=${PYTHON:-python3}

# time to sleep between checks
SLEEP_TIME=20

function tracker {
    while [ 1 ]; do
        cat /proc/sys/fs/file-nr | awk '{split($0, a, " "); print "Number of open files: " a[1]; print "Number of open files not in use: " a[2]; print "Maximum number of files allowed to be opened: " a[3]}'
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

tracker

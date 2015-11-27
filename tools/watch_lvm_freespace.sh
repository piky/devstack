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

set -euo pipefail

# time to sleep between checks
SLEEP_TIME=2

function get_vg_free_space {
    local vg_name=$1
    local line

    line=$(sudo vgs --noheading --nosuffix --units g --separator '|' $vg_name)
    vg_free_space_float=$(echo $line | cut -f 7 -d '|')
    echo ${vg_free_space_float%.*}
}


function tracker {
    local low_point
    low_point=$(get_vg_free_space $VG_NAME)
    while [ 1 ]; do

        local vg_free_space
        vg_free_space=$(get_vg_free_space $VG_NAME)

        if [[ $vg_free_space -lt $low_point ]]; then
            low_point=$vg_free_space
            echo "---"
            echo "LVM free disk space low_point: $vg_free_space"
            echo "---"
            sudo vgs $VG_NAME
            echo "---"
        fi

        sleep $SLEEP_TIME
    done
}

function usage {
    echo "Usage: $0 [-x] [-s N] vg_name" 1>&2
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

if [ $# -ne 1 ] || [ -z "$1" ]; then
    usage
    exit 1
fi

VG_NAME=$1

while ! sudo vgs $VG_NAME &>/dev/null; do
  echo "$(date '+%F-%H%M%S') Volume group '$VG_NAME' not found. Sleeping."
  sleep $SLEEP_TIME
done

tracker

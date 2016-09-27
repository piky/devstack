#!/bin/bash

# Keep track of the DevStack directory
TOP_DIR=$(cd $(dirname "$0")/.. && pwd)

function usage {
    cat << EOF
Show pre-caching image urls

Usages:
    $0
    $0 --list
    $0 [<driver1> <driver2> ...]
    $0 [--exclude] [<driver1> <driver2> ...]

Options:
    -l, --list           List available drivers set in stackrc
    <drivers>            Show image urls of specified drivers
    --exclude <drivers>  Show image urls excluding specified drivers
    -h, --help           A brief usage guide

EOF
}

# The following "source" implicitly calls get_default_host_ip() in
# stackrc and will die if the selected default IP happens to lie
# in the default ranges for FIXED_RANGE or FLOATING_RANGE. Since we
# do not really need HOST_IP to be properly set in the remainder of
# this script, just set it to some dummy value and make stackrc happy.
HOST_IP=SKIP
source $TOP_DIR/functions

OPTS=$(getopt -o hl --long help,list,exclude: -- "$@")
if [[ "$?" -ne 0 ]]; then
    exit 1
fi

eval set -- "$OPTS"
DRIVERS="$(source $TOP_DIR/stackrc && echo $DEVSTACK_SUPPORTED_VIRT_DRIVERS)"
EXCLUSION=""
while true; do
    case "$1" in
        -l | --list ) echo "$DRIVERS" | tr ' ' '\n' | sort | uniq ; exit 0 ;;
        --exclude ) shift ; EXCLUSION="$@"; break ;;
        -h | --help ) usage ; exit 0 ;;
        * ) DRIVERS=${@:-"$DRIVERS"} ; break ;;
    esac
done

# Extra variables to trigger getting additional images.
export ENABLED_SERVICES="h-api,tr-api"
HEAT_FETCHED_TEST_IMAGE="Fedora-i386-20-20131211.1-sda"
PRECACHE_IMAGES=True

# Loop over all the virt drivers and collect all the possible images
ALL_IMAGES=""
for driver in $DRIVERS; do
    VIRT_DRIVER=$driver
    if [[ " $EXCLUSION " == *" $VIRT_DRIVER "* ]]; then
        continue
    fi
    URLS=$(source $TOP_DIR/stackrc && echo $IMAGE_URLS)
    if [[ ! -z "$ALL_IMAGES" ]]; then
        ALL_IMAGES+=,
    fi
    ALL_IMAGES+=$URLS
done

# Make a nice list
echo $ALL_IMAGES | tr ',' '\n' | sort | uniq

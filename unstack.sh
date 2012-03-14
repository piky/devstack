#!/usr/bin/env bash
#
# Stops that which is started by ``stack.sh`` (mostly)
# mysql and rabbit are left running as OpenStack code refreshes
# do not require them to be restarted.
#
# Stop all processes by setting UNSTACK_ALL or specifying ``--all``
# on the command line

# Keep track of the current devstack directory.
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions

# Load local configuration
source $TOP_DIR/stackrc

if [[ "$1" == "--all" ]]; then
    UNSTACK_ALL=${UNSTACK_ALL:-1}
fi

# Get the bulk of OpenStack services in one shot
killall screen

# Swift runs daemons
if is_service_enabled swift; then
    swift-init all stop
fi

# Apache has the WSGI processes
if is_service_enabled horizon; then
    sudo service apache2 stop
fi

# Get the iSCSI volumes
if is_service_enabled n-vol; then
    TARGETS=$(sudo tgtadm --op show --mode target)
    if [[ -n "$TARGETS" ]]; then
        # FIXME(dtroyer): this could very well require more here to
        #                 clean up left-over volumes
        echo "iSCSI target cleanup needed:"
        echo "$TARGETS"
    fi
    sudo stop tgt
fi

if [[ -n "$UNSTACK_ALL" ]]; then
    # Stop MySQL server
    if is_service_enabled mysql; then
        sudo service mysql stop
    fi
fi

#!/usr/bin/env bash

# **discover_hosts.sh**

# This is just a very simple script to run the
# "nova-manage cell_v2 discover_hosts" command
# which is needed to discover compute nodes and
# register them with a parent cell in Nova.
# This assumes that /etc/nova/nova.conf exists
# and has the following entries filled in:
#
# [api_database]
# connection = This is the URL to the nova_api database
#
# In other words this should be run on the primary
# (API) node in a multi-node setup.

# Try to locate nova-manage in it's venv
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"

if [[ -r $DIR/.stackenv ]]; then
    source $DIR/.stackenv
    PATH=$PATH:$NOVA_BIN_DIR
fi

if [[ -x $(which nova-manage) ]]; then
    nova-manage cell_v2 discover_hosts --verbose
fi

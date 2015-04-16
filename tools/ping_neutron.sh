#!/bin/bash
#
# Copyright 2015 Hewlett-Packard Development Company, L.P.
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

# Ping a neutron guest using a network namespace probe

set -o errexit
set -o pipefail

TOP_DIR=$(cd $(dirname "$0")/.. && pwd)

# This *must* be run as the admin tenant
source $TOP_DIR/openrc admin admin

function usage {
    cat - <<EOF
ping_neutron.sh <net_name> [ping args]

This provides a wrapper to ping neutron guests that are on isolated
tenant networks that the caller can't normally reach. It does so by
creating a network namespace probe.

It takes arguments like ping, except the first arg must be the network
name.

Note: in environments with duplicate network names, the results are
non deterministic.

This should *really* be in the neutron cli.

EOF
    exit 1
}

NET_NAME=$1

if [[ -z "$NET_NAME" ]]; then
    echo "Error: net_name is required"
    usage
fi

REMANING_ARGS="${@:2}"

# BUG: with duplicate network names, this fails pretty hard.
NET_ID=$(neutron net-list $NET_NAME | grep "$NET_NAME" | awk '{print $2}')
PROBE_ID=$(neutron-debug probe-list -c id -c network_id | grep "$NET_ID" | awk '{print $2}' | head -n 1)
ROOT_WRAP=$(get_rootwrap_location neutron)
# BUG? it seems *really* weird that we need to ask for a project
# specific rootwrap command, and then also give it a project specific
# config file. Like weird to the point of crazy pants. Also, rootwrap
# command had no arg handling or help, because why would you want
# that.
ROOT_WRAP+=" $NEUTRON_CONF_DIR/rootwrap.conf"

# This runs a command inside the specific netns
NET_NS_CMD="ip netns exec qprobe-$PROBE_ID"

PING_CMD="$ROOT_WRAP $NET_NS_CMD ping $REMAING_ARGS"
echo "Running $PING_CMD"
$PING_CMD

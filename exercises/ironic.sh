#!/usr/bin/env bash

## Copyright (c) 2012 Hewlett-Packard Development Company, L.P.
## All Rights Reserved.
##
##    Licensed under the Apache License, Version 2.0 (the "License"); you may
##    not use this file except in compliance with the License. You may obtain
##    a copy of the License at
##
##         http://www.apache.org/licenses/LICENSE-2.0
##
##    Unless required by applicable law or agreed to in writing, software
##    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
##    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
##    License for the specific language governing permissions and limitations
##    under the License.

# **ironic.sh**

# Basic exercise of Ironic.  It does the following:
#
# * Creates a new chassis
# * Creates a new node, using the fake driver
# * Creates a new port on that node
# * Powers on the node
# * Powers off the node
# * Adds and removes extra metadata to each resource
# * Deletes each resource

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# Settings
# ========
FAKE_MAC_ADDR=${FAKE_MAC_ADDR:-"aa:bb:cc:dd:ee:ff"}

# Keep track of the current directory
EXERCISE_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $EXERCISE_DIR/..; pwd)

# Import common functions
source $TOP_DIR/functions

# Import configuration.
source $TOP_DIR/openrc admin admin

# Import exercise configuration
source $TOP_DIR/exerciserc

is_service_enabled ir-api ir-cond || exit 55

function validate_power_state {
  local _state=$(ironic node-show $1 | grep " power_state " | get_field 2)
  # It should have no power state currently
  if [ "$_state" != "$2" ] ; then
    die $LINENO "power state of node expected to be $2, got $_state"
  fi
}

function validate_extra {
  local _extra=$(ironic $1-show $2 | grep " extra " | get_field 2)
  if [ "$_extra" != "$3" ] ; then
    die $LINENO "failed to validate $1 extra data. expected $3, got $_extra"
  fi
}

# Chassis
CHASSIS_ID=$(ironic chassis-create | grep uuid | get_field 2)
ironic chassis-show $CHASSIS_ID

# Node
NODE_ID=$(ironic node-create -d fake \
          -i ipmi_address=$FAKE_IPMI_ADDRESS \
          -i ipmi_username=$FAKE_IPMI_USERNAME \
          -i ipmi_password=$FAKE_IPMI_PASSWORD | grep " uuid " | get_field 2)
ironic node-show $NODE_ID

# Node validation
# NOTE: rescue interface is currently not supported.
for INTERFACE in console deploy power; do
  INT_STATE=$(ironic node-validate $NODE_ID | grep " $INTERFACE " | get_field 2)
  if [ "$INT_STATE" != "True" ] ; then
    die $LINENO "failed to validate node interface $INTERFACE.  expected True, got $INT_STATE"
  fi
done

# Port creation
PORT_ID=$(ironic port-create -n $NODE_ID -a $FAKE_MAC_ADDR | grep " uuid " | get_field 2)
PORT_NODE_ID=$(ironic port-show $PORT_ID | grep " node_uuid " | get_field 2)
[ "$PORT_NODE_ID" == "$NODE_ID" ] || die $LINENO "created port not assigned to expected node"

# Power cycle
DEPLOY_STATE=$(ironic node-validate $NODE_ID | grep " deploy " | get_field 2)
if [ "$DEPLOY_STATE" != "True" ] ; then
    die $LINENO "deploy state for node is not True!"
fi

# power cycle
validate_power_state $NODE_ID "None"

ironic node-set-power-state $NODE_ID on
sleep 1
validate_power_state $NODE_ID "power on"

ironic node-set-power-state $NODE_ID off
sleep 1
validate_power_state $NODE_ID "power off"

function validate_extra {
  local _extra=$(ironic $1-show $2 | grep " extra " | get_field 2)
  if [ "$_extra" != "$3" ] ; then
    die $LINENO "failed to validate $1 extra data. expected $3, got $_extra"
  fi
}

# Update/remove extra metadata
EXPECTED_JSON="{u'foo': u'bar'}"

ironic chassis-update $CHASSIS_ID add "extra/foo=bar"
validate_extra "chassis" "$CHASSIS_ID" "$EXPECTED_JSON"
ironic chassis-update $CHASSIS_ID remove extra
validate_extra "chassis" "$CHASSIS_ID" "{}"

ironic node-update $NODE_ID add "extra/foo=bar"
validate_extra "node" "$NODE_ID" "$EXPECTED_JSON"
ironic node-update $NODE_ID remove extra
validate_extra "node" "$NODE_ID" "{}"

ironic port-update $PORT_ID add "extra/foo=bar"
validate_extra "port" "$PORT_ID" "$EXPECTED_JSON"
ironic port-update $PORT_ID remove extra
validate_extra "port" "$PORT_ID" "{}"


# Cleanup
ironic node-delete $NODE_ID
ironic port-delete $PORT_ID
ironic chassis-delete $CHASSIS_ID

# Verify delete
ironic node-show $NODE_ID && die $LINENO "deleted node still present"
ironic port-show $NODE_ID && die $LINENO "deleted port still present"
ironic chassis-show $CHASSIS_ID && die $LINENO "deleted chassis still present"

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"

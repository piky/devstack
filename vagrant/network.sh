#!/bin/bash
#
# Copyright (c) 2015 Intel Corp.
# Copyright (c) 2015 OpenStack Foundation
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#
# Authors:
#   Ruijing Guo <ruijing.guo@intel.com>
#

Host_ip=`ifconfig eth1 | grep "inet addr" | cut -f2 -d:| cut -d' ' -f1`

function setup_bridge {
    ip=`ifconfig eth1 | grep "inet addr" | cut -f2 -d:| cut -d' ' -f1 | sed -e 's/192.168.10/192.168.20/'`
    ifconfig eth2 promisc
    ip addr flush dev eth2
    ovs-vsctl add-br br-ex
    ovs-vsctl add-port br-ex eth2
    ifconfig br-ex $ip netmask 255.255.255.0
}

function clean_stack {
    cd /opt/stack/devstack && sudo -E -H -u stack ./unstack.sh
}

function run_stack {
    sudo -E -H -u stack cp /vagrant/localrc  /opt/stack/devstack/localrc
    sudo -E -H -u stack cat << EOF >> /opt/stack/devstack/localrc

HOST_IP=$Host_ip
ENABLED_SERVICES=q-meta,q-agt,q-l3,q-dhcp
Q_DVR_MODE=dvr_snat

EOF

    cd /opt/stack/devstack && sudo -E -H -u stack ./stack.sh
}

clean_stack
setup_bridge
run_stack

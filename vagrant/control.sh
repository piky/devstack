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

function run_stack {
    cd /opt/stack/devstack && sudo -E -H -u stack ./unstack.sh
    sudo -E -H -u stack cat << EOF >> /opt/stack/devstack/localrc

HOST_IP=$Host_ip

ENABLED_SERVICES=qpid,mysql,horizon,key
ENABLED_SERVICES+=,g-api,g-reg,n-api,n-crt,n-obj,n-cond,n-sch,q-svc,c-api,c-vol,c-sch
APACHE_ENABLED_SERVICES+=keystone
CINDER_ENABLED_BACKENDS=nfs
CINDER_NFS_SERVERPATH=192.168.10.9:/nfs

EOF

    cd /opt/stack/devstack && sudo -E -H -u stack ./stack.sh
}

run_stack

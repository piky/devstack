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

yum -y install nfs-utils rpcbind
chkconfig nfs on
chkconfig rpcbind on
chkconfig nfslock on
#echo "/nfs *(rw,sync,no_root_squash,no_subtree_check)" | sudo tee  /etc/exports
echo "/nfs 192.168.0.0/255.255.0.0(rw,sync,no_root_squash)" > /etc/exports
mkdir -p /nfs
chmod 777 /nfs
service rpcbind restart
service nfs restart
service nfslock restart
exportfs

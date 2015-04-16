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

function create_account {
    groupadd stack
    useradd -g stack -s /bin/bash -d /opt/stack -m stack
    echo -e "123456\n123456" | sudo passwd  stack
    echo "stack ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers 
}

function setup_gitreview {
    #ssh-keygen and copy public/private key devstack/vagrant/.gitssh directory
    #put public key in  https://review.openstack.org/#/settings/ssh-keys
    sudo -E -H -u stack mkdir /opt/stack/.ssh
    cp /vagrant/.gitssh/* /opt/stack/.ssh; chown -R stack /opt/stack/.ssh
    sudo -E -H -u stack git config --global user.name "Ruijing Guo"
    sudo -E -H -u stack git config --global user.email ruijing.guo@intel.com
    sudo -E -H -u stack git config --global gitreview.username ruijing
    sudo -E -H -u stack git config --global core.editor vi
}

function checkout_devstack {
    sudo -E -H -u stack git clone https://git.openstack.org/openstack-dev/devstack /opt/stack/devstack
}

apt-get update
apt-get install -y git git-review
setup_gitreview

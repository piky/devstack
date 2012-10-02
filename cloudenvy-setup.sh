#!/bin/bash

# Skip ssh new host check.
cat<<EOF | sudo tee ~/.ssh/config
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  User ubuntu
EOF

sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get install -y git python-netaddr

git clone https://github.com/openstack-dev/devstack.git
cd devstack

cat<<LOCALRC | tee localrc
FIXED_RANGE=192.168.20.0/24
MYSQL_PASSWORD=mysqlsekret
RABBIT_PASSWORD=rabbitsekret
SERVICE_TOKEN=servicesekret
SERVICE_PASSWORD=topsekret
ADMIN_PASSWORD=admin
LOCALRC

./stack.sh

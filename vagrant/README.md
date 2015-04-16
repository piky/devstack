Deploy multi-node openstack using Vagrant/Virutalbox and Devstack.

*  eth0: only for login
*  eth1: 192.168.10.0/24 (netmask 255.255.255.0)
*  eth2: 192.168.20.0/24 (netmask 255.255.255.0)

The IP address reservation is

* 0.0.0.1   : Host OS
* 0.0.0.9   : NFS Server
* 0.0.0.10  : OS Controller
* 0.0.0.11  : OS Networking
* 0.0.0.12  : OS Compute
* 0.0.0.13  : OS Compute

* 192.168.10.* : management network, IP for tenant tunnel network(VXLAN/GRE)
* 192.168.20.* : external network

How to run in ubuntu:

1. install vagrant

sudo rpm -ivh https://dl.bintray.com/mitchellh/vagrant/vagrant_1.6.5_x86_64.rpm

Note: vagrant >= 1.6.3 supports VAGRANT API 2.0

2. install virtualbox

sudo apt-get install virtualbox virtualbox-guest-additions

3. import vagrant box 

vagrant box add ubuntu14.04 https://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box
vagrant box add centos65 https://github.com/2creatives/vagrant-centos/releases/download/v6.5.3/centos65-x86_64-20140116.box

4. create cluster

vagrant up

5. login 

a. http://192.168.10.10
b. vagrant ssh controller/network/nfs/compute1/compute2 

6. destroy cluster

vagrant destroy -f

Installing OpenStack LBaaS Version 2 on Kilo using Devstack
============================================================

The Kilo release of OpenStack will support Version 2 of the neutron load balancer. Until now, using OpenStack `LBaaS V2 <http://docs.openstack.org/api/openstack-network/2.0/content/lbaas_ext.html>`_ has required a good understanding of neutron and LBaaS architecture and several manual steps.


Phase 1: Create DevStack + 2 novas
-----------------------------------

First, set up an Ubuntu 14.04 LTS vm with at least 8 GB RAM and 16 GB disk space, make sure it is updated. Install git and any other developer tools you find useful.

  ::

    sudo apt-get update
    sudo apt-get -y upgrade
    sudo apt-get -y dist-upgrade
    sudo apt-get -y install git

Install devstack

  ::

    git clone https://git.openstack.org/openstack-dev/devstack
    cd devstack


Edit your `localrc` to look like

  ::

    # Load the external LBaaS plugin.  When the patches merge, this will
    # simply point to the main neutron-lbaas repo
    enable_plugin neutron-lbaas https://review.openstack.org/openstack/neutron-lbaas refs/changes/40/155540/11

    #Q_PLUGIN=ml2
    #Q_ML2_TENANT_NETWORK_TYPE=vxlan
    #Q_DVR_MODE=dvr_snat
    # ===== BEGIN localrc =====
    # Begin Al's notes
    #
    # Depending on network firewalls and proxy settings, you may not be
    # able to use the git protocol, in which case, override GIT_BASE to
    # use http/https. In the HP public cloud you will not need to do
    # this, but you may need to do so in environments requiring http
    # proxy.
    # GIT_BASE=http://git.openstack.org
    # End Al's notes
    # Originally from http://www.sebastien-han.fr/blog/2013/08/08/devstack-in-1-minute/
    # Misc
    DATABASE_PASSWORD=password
    ADMIN_PASSWORD=password
    SERVICE_PASSWORD=password
    SERVICE_TOKEN=password
    RABBIT_PASSWORD=password
    # Enable Logging
    LOGFILE=/opt/stack/logs/stack.sh.log
    VERBOSE=True
    LOG_COLOR=True
    SCREEN_LOGDIR=/opt/stack/logs
    # Pre-requisite
    ENABLED_SERVICES=rabbit,mysql,key
    # Horizon (always use the trunk)
    ENABLED_SERVICES+=,horizon
    HORIZON_REPO=https://github.com/openstack/horizon
    HORIZON_BRANCH=master
    # Nova
    ENABLED_SERVICES+=,n-api,n-crt,n-obj,n-cpu,n-cond,n-sch
    IMAGE_URLS+=",https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img"
    # Glance
    ENABLED_SERVICES+=,g-api,g-reg
    # Neutron
    ENABLED_SERVICES+=,q-svc,q-agt,q-dhcp,q-l3,q-meta
    # Enable LBaaS V2
    ENABLED_SERVICES+=,q-lbaasv2
    # Cinder
    ENABLED_SERVICES+=,cinder,c-api,c-vol,c-sch
    # Tempest
    ENABLED_SERVICES+=,tempest
    # ===== END localrc =====

Run stack.sh and do some sanity checks

  ::

    ./stack.sh
    . ./openrc

    neutron net-list  # should show public and private networks

Create two nova instances that we can use as test http servers:

  ::

    #create nova instances on private network
    nova boot --image $(nova image-list | awk '/ cirros-0.3.0-x86_64-disk / {print $2}') --flavor 1 --nic net-id=$(neutron net-list | awk '/ private / {print $2}') node1
    nova boot --image $(nova image-list | awk '/ cirros-0.3.0-x86_64-disk / {print $2}') --flavor 1 --nic net-id=$(neutron net-list | awk '/ private / {print $2}') node2
    neutron nova-list # should show the nova instances just created

    #add secgroup rule to allow ssh etc..
    neutron security-group-rule-create default --protocol icmp
    neutron security-group-rule-create default --protocol tcp --port-range-min 22 --port-range-max 22
    neutron security-group-rule-create default --protocol tcp --port-range-min 80 --port-range-max 80

Set up a simple web server on each of these instances. ssh into each instance (username 'cirros', password 'cubswin:)') and run

 ::

    MYIP=$(ifconfig eth0|grep 'inet addr'|awk -F: '{print $2}'| awk '{print $1}')
    while true; do echo -e "HTTP/1.0 200 OK\r\n\r\nWelcome to $MYIP" | sudo nc -l -p 80 ; done

Phase 2: Create your load balancers
------------------------------------

 ::

    neutron lbaas-loadbalancer-create --name lb1 private-subnet
    neutron lbaas-listener-create --loadbalancer lb1 --protocol HTTP --protocol-port 80 --name listener1
    neutron lbaas-pool-create --lb-algorithm ROUND_ROBIN --listener listener1 --protocol HTTP pool1
    neutron lbaas-member-create  --subnet private-subnet --address 10.0.0.2 --protocol-port 80 pool1


..
  Note to patch submitters: this file is covered by a periodic proposal
  job.  You should edit the files data/devstack-plugins-registry.footer
  data/devstack-plugins-registry.header instead of this one.

==========================
 DevStack Plugin Registry
==========================

Since we've created the external plugin mechanism, it's gotten used by
a lot of projects. The following is a list of plugins that currently
exist. Any project that wishes to list their plugin here is welcomed
to.

Detected Plugins
================

The following are plugins that a script has found in the openstack/
namespace, which includes but is not limited to official OpenStack
projects.
====================================== ===
Plugin Name                            URL
====================================== ===
                                       `git://git.openstack.org/openstack/aodh <https://git.openstack.org/cgit/openstack/aodh>`__
                                       `git://git.openstack.org/openstack/app-catalog-ui <https://git.openstack.org/cgit/openstack/app-catalog-ui>`__
                                       `git://git.openstack.org/openstack/astara <https://git.openstack.org/cgit/openstack/astara>`__
                                       `git://git.openstack.org/openstack/barbican <https://git.openstack.org/cgit/openstack/barbican>`__
                                       `git://git.openstack.org/openstack/blazar <https://git.openstack.org/cgit/openstack/blazar>`__
                                       `git://git.openstack.org/openstack/broadview-collector <https://git.openstack.org/cgit/openstack/broadview-collector>`__
                                       `git://git.openstack.org/openstack/ceilometer <https://git.openstack.org/cgit/openstack/ceilometer>`__
                                       `git://git.openstack.org/openstack/ceilometer-powervm <https://git.openstack.org/cgit/openstack/ceilometer-powervm>`__
                                       `git://git.openstack.org/openstack/cerberus <https://git.openstack.org/cgit/openstack/cerberus>`__
                                       `git://git.openstack.org/openstack/cloudkitty <https://git.openstack.org/cgit/openstack/cloudkitty>`__
                                       `git://git.openstack.org/openstack/collectd-ceilometer-plugin <https://git.openstack.org/cgit/openstack/collectd-ceilometer-plugin>`__
                                       `git://git.openstack.org/openstack/congress <https://git.openstack.org/cgit/openstack/congress>`__
                                       `git://git.openstack.org/openstack/cue <https://git.openstack.org/cgit/openstack/cue>`__
                                       `git://git.openstack.org/openstack/designate <https://git.openstack.org/cgit/openstack/designate>`__
                                       `git://git.openstack.org/openstack/devstack-plugin-additional-pkg-repos <https://git.openstack.org/cgit/openstack/devstack-plugin-additional-pkg-repos>`__
                                       `git://git.openstack.org/openstack/devstack-plugin-amqp1 <https://git.openstack.org/cgit/openstack/devstack-plugin-amqp1>`__
                                       `git://git.openstack.org/openstack/devstack-plugin-bdd <https://git.openstack.org/cgit/openstack/devstack-plugin-bdd>`__
                                       `git://git.openstack.org/openstack/devstack-plugin-ceph <https://git.openstack.org/cgit/openstack/devstack-plugin-ceph>`__
                                       `git://git.openstack.org/openstack/devstack-plugin-glusterfs <https://git.openstack.org/cgit/openstack/devstack-plugin-glusterfs>`__
                                       `git://git.openstack.org/openstack/devstack-plugin-hdfs <https://git.openstack.org/cgit/openstack/devstack-plugin-hdfs>`__
                                       `git://git.openstack.org/openstack/devstack-plugin-nfs <https://git.openstack.org/cgit/openstack/devstack-plugin-nfs>`__
                                       `git://git.openstack.org/openstack/devstack-plugin-pika <https://git.openstack.org/cgit/openstack/devstack-plugin-pika>`__
                                       `git://git.openstack.org/openstack/devstack-plugin-sheepdog <https://git.openstack.org/cgit/openstack/devstack-plugin-sheepdog>`__
                                       `git://git.openstack.org/openstack/devstack-plugin-zmq <https://git.openstack.org/cgit/openstack/devstack-plugin-zmq>`__
                                       `git://git.openstack.org/openstack/dragonflow <https://git.openstack.org/cgit/openstack/dragonflow>`__
                                       `git://git.openstack.org/openstack/drbd-devstack <https://git.openstack.org/cgit/openstack/drbd-devstack>`__
                                       `git://git.openstack.org/openstack/ec2-api <https://git.openstack.org/cgit/openstack/ec2-api>`__
                                       `git://git.openstack.org/openstack/freezer <https://git.openstack.org/cgit/openstack/freezer>`__
                                       `git://git.openstack.org/openstack/freezer-api <https://git.openstack.org/cgit/openstack/freezer-api>`__
                                       `git://git.openstack.org/openstack/freezer-web-ui <https://git.openstack.org/cgit/openstack/freezer-web-ui>`__
                                       `git://git.openstack.org/openstack/gce-api <https://git.openstack.org/cgit/openstack/gce-api>`__
                                       `git://git.openstack.org/openstack/gnocchi <https://git.openstack.org/cgit/openstack/gnocchi>`__
                                       `git://git.openstack.org/openstack/ironic <https://git.openstack.org/cgit/openstack/ironic>`__
                                       `git://git.openstack.org/openstack/ironic-inspector <https://git.openstack.org/cgit/openstack/ironic-inspector>`__
                                       `git://git.openstack.org/openstack/kingbird <https://git.openstack.org/cgit/openstack/kingbird>`__
                                       `git://git.openstack.org/openstack/kuryr <https://git.openstack.org/cgit/openstack/kuryr>`__
                                       `git://git.openstack.org/openstack/magnum <https://git.openstack.org/cgit/openstack/magnum>`__
                                       `git://git.openstack.org/openstack/magnum-ui <https://git.openstack.org/cgit/openstack/magnum-ui>`__
                                       `git://git.openstack.org/openstack/manila <https://git.openstack.org/cgit/openstack/manila>`__
                                       `git://git.openstack.org/openstack/mistral <https://git.openstack.org/cgit/openstack/mistral>`__
                                       `git://git.openstack.org/openstack/monasca-api <https://git.openstack.org/cgit/openstack/monasca-api>`__
                                       `git://git.openstack.org/openstack/murano <https://git.openstack.org/cgit/openstack/murano>`__
                                       `git://git.openstack.org/openstack/networking-6wind <https://git.openstack.org/cgit/openstack/networking-6wind>`__
                                       `git://git.openstack.org/openstack/networking-bagpipe <https://git.openstack.org/cgit/openstack/networking-bagpipe>`__
                                       `git://git.openstack.org/openstack/networking-bgpvpn <https://git.openstack.org/cgit/openstack/networking-bgpvpn>`__
                                       `git://git.openstack.org/openstack/networking-brocade <https://git.openstack.org/cgit/openstack/networking-brocade>`__
                                       `git://git.openstack.org/openstack/networking-calico <https://git.openstack.org/cgit/openstack/networking-calico>`__
                                       `git://git.openstack.org/openstack/networking-cisco <https://git.openstack.org/cgit/openstack/networking-cisco>`__
                                       `git://git.openstack.org/openstack/networking-fortinet <https://git.openstack.org/cgit/openstack/networking-fortinet>`__
                                       `git://git.openstack.org/openstack/networking-generic-switch <https://git.openstack.org/cgit/openstack/networking-generic-switch>`__
                                       `git://git.openstack.org/openstack/networking-infoblox <https://git.openstack.org/cgit/openstack/networking-infoblox>`__
                                       `git://git.openstack.org/openstack/networking-l2gw <https://git.openstack.org/cgit/openstack/networking-l2gw>`__
                                       `git://git.openstack.org/openstack/networking-midonet <https://git.openstack.org/cgit/openstack/networking-midonet>`__
                                       `git://git.openstack.org/openstack/networking-mlnx <https://git.openstack.org/cgit/openstack/networking-mlnx>`__
                                       `git://git.openstack.org/openstack/networking-nec <https://git.openstack.org/cgit/openstack/networking-nec>`__
                                       `git://git.openstack.org/openstack/networking-odl <https://git.openstack.org/cgit/openstack/networking-odl>`__
                                       `git://git.openstack.org/openstack/networking-ofagent <https://git.openstack.org/cgit/openstack/networking-ofagent>`__
                                       `git://git.openstack.org/openstack/networking-ovn <https://git.openstack.org/cgit/openstack/networking-ovn>`__
                                       `git://git.openstack.org/openstack/networking-ovs-dpdk <https://git.openstack.org/cgit/openstack/networking-ovs-dpdk>`__
                                       `git://git.openstack.org/openstack/networking-plumgrid <https://git.openstack.org/cgit/openstack/networking-plumgrid>`__
                                       `git://git.openstack.org/openstack/networking-powervm <https://git.openstack.org/cgit/openstack/networking-powervm>`__
                                       `git://git.openstack.org/openstack/networking-sfc <https://git.openstack.org/cgit/openstack/networking-sfc>`__
                                       `git://git.openstack.org/openstack/networking-vsphere <https://git.openstack.org/cgit/openstack/networking-vsphere>`__
                                       `git://git.openstack.org/openstack/neutron <https://git.openstack.org/cgit/openstack/neutron>`__
                                       `git://git.openstack.org/openstack/neutron-lbaas <https://git.openstack.org/cgit/openstack/neutron-lbaas>`__
                                       `git://git.openstack.org/openstack/neutron-lbaas-dashboard <https://git.openstack.org/cgit/openstack/neutron-lbaas-dashboard>`__
                                       `git://git.openstack.org/openstack/neutron-vpnaas <https://git.openstack.org/cgit/openstack/neutron-vpnaas>`__
                                       `git://git.openstack.org/openstack/nova-docker <https://git.openstack.org/cgit/openstack/nova-docker>`__
                                       `git://git.openstack.org/openstack/nova-powervm <https://git.openstack.org/cgit/openstack/nova-powervm>`__
                                       `git://git.openstack.org/openstack/octavia <https://git.openstack.org/cgit/openstack/octavia>`__
                                       `git://git.openstack.org/openstack/osprofiler <https://git.openstack.org/cgit/openstack/osprofiler>`__
                                       `git://git.openstack.org/openstack/python-freezerclient <https://git.openstack.org/cgit/openstack/python-freezerclient>`__
                                       `git://git.openstack.org/openstack/rally <https://git.openstack.org/cgit/openstack/rally>`__
                                       `git://git.openstack.org/openstack/sahara <https://git.openstack.org/cgit/openstack/sahara>`__
                                       `git://git.openstack.org/openstack/sahara-dashboard <https://git.openstack.org/cgit/openstack/sahara-dashboard>`__
                                       `git://git.openstack.org/openstack/scalpels <https://git.openstack.org/cgit/openstack/scalpels>`__
                                       `git://git.openstack.org/openstack/searchlight <https://git.openstack.org/cgit/openstack/searchlight>`__
                                       `git://git.openstack.org/openstack/searchlight-ui <https://git.openstack.org/cgit/openstack/searchlight-ui>`__
                                       `git://git.openstack.org/openstack/senlin <https://git.openstack.org/cgit/openstack/senlin>`__
                                       `git://git.openstack.org/openstack/smaug <https://git.openstack.org/cgit/openstack/smaug>`__
                                       `git://git.openstack.org/openstack/smaug-dashboard <https://git.openstack.org/cgit/openstack/smaug-dashboard>`__
                                       `git://git.openstack.org/openstack/solum <https://git.openstack.org/cgit/openstack/solum>`__
                                       `git://git.openstack.org/openstack/tacker <https://git.openstack.org/cgit/openstack/tacker>`__
                                       `git://git.openstack.org/openstack/tap-as-a-service <https://git.openstack.org/cgit/openstack/tap-as-a-service>`__
                                       `git://git.openstack.org/openstack/tricircle <https://git.openstack.org/cgit/openstack/tricircle>`__
                                       `git://git.openstack.org/openstack/trove <https://git.openstack.org/cgit/openstack/trove>`__
                                       `git://git.openstack.org/openstack/trove-dashboard <https://git.openstack.org/cgit/openstack/trove-dashboard>`__
                                       `git://git.openstack.org/openstack/vitrage <https://git.openstack.org/cgit/openstack/vitrage>`__
                                       `git://git.openstack.org/openstack/vitrage-dashboard <https://git.openstack.org/cgit/openstack/vitrage-dashboard>`__
                                       `git://git.openstack.org/openstack/vmware-nsx <https://git.openstack.org/cgit/openstack/vmware-nsx>`__
                                       `git://git.openstack.org/openstack/watcher <https://git.openstack.org/cgit/openstack/watcher>`__
                                       `git://git.openstack.org/openstack/watcher-dashboard <https://git.openstack.org/cgit/openstack/watcher-dashboard>`__
                                       `git://git.openstack.org/openstack/zaqar <https://git.openstack.org/cgit/openstack/zaqar>`__
                                       `git://git.openstack.org/openstack/zaqar-ui <https://git.openstack.org/cgit/openstack/zaqar-ui>`__

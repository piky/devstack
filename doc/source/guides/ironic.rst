===================
Ironic and DevStack
===================

This is a rough guide to various configuration parameters for Ironic
running with DevStack.


Ironic provision network
========================

This network is used during instance provisioning. It will be created
on Devstack if the following variables are set. Ironic provision network id
will be added to ``/etc/ironic/ironic.conf`` and ``network_provider`` will
be set to ``neutron_plugin``. There is an example of ``local.conf``:

::


	# Ironic provision network name
	IRONIC_PROVISION_NETWORK_NAME=ironic-provision

	# Provision network provider type. Can be flat of vlan.
	IRONIC_PROVISION_PROVIDER_NETWORK_TYPE=vlan

	# If provider type is vlan. VLAN_ID may be specified. If it is not set,
	# vlan will be allocated dynamically.
	IRONIC_PROVISION_SEGMENTATION_ID=110

	# Allocation network pool for provision network
	IRONIC_PROVISION_ALLOCATION_POOL=start=10.0.5.10,end=10.0.5.100

	# Ironic provision subnet name. If it is not set
	# ${IRONIC_PROVISION_NETWORK_NAME}-subnet will be used
	IRONIC_PROVISION_PROVIDER_SUBNET_NAME=provision-subnet

	# Ironic provision subnet gateway. Gateway ip will be configured on
	# $OVS_PHYSICAL_BRIDGE.$IRONIC_PROVISION_SEGMENTATION_ID vlan subinterface
	# if IRONIC_PROVISION_PROVIDER_NETWORK_TYPE=='vlan'. Otherwise gateway ip
	# will be configured directly on $OVS_PHYSICAL_BRIDGE
	IRONIC_PROVISION_SUBNET_GATEWAY=10.0.5.1

	# Ironic provision subnet prefix
	IRONIC_PROVISION_SUBNET_PREFIX=10.0.5.0/24


Link Local Connection
=====================

This information is used by Neutron in order to bind port on the switch. To
register node in ironic with LLC information use the following ``local.conf``:

::

	IRONIC_LLC_ENABLED=True


Hardware node registration in Ironic
====================================

Ironic nodes can be automatically registered in Ironic during Devstack setup.
By specifying ``IRONIC_HW_NODES_FILE`` variable. It is an INI settings syntax
file. Each section name represents ironic node name, where ironic node options
are appropriate options in the section. There is an example of ``local.conf``

::

	IRONIC_HW_NODES_FILE=/opt/stack/ironic_hw_nodes

and ``/opt/stack/ironic_hw_nodes``:

::

	[node-1]
	ipmi_address=1.2.3.4
	mac_address=aa:bb:cc:dd:ee:ff
	ipmi_username=ipmi_user
	ipmi_password=ipmi_password
	cpus=2
	memory_mb=16000
	local_gb=100
	cpu_arch=x86_64
	# Link Local Connection info
	switch_info=sw-hostname
	port_id=Gig0/3
	switch_id=00:14:f2:8c:93:c1


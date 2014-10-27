Using DevStack with Neutron Networking
======================================

Network Interface Configuration
-------------------------------

To use Neutron, it is suggested that two network interfaces be present
in the host operating system.

The first interface, eth0 is used for the OpenStack management (API,
message bus, etc) as well as for ssh for an administrator to access
the machine.

::

        stack@compute:~$ ifconfig eth0
        eth0      Link encap:Ethernet  HWaddr bc:16:65:20:af:fc
                  inet addr:192.168.1.18

eth1 is manually configured at boot to not have an IP address.
Consult your operating system documentation for the appropriate
technique. For Ubuntu, the contents of `/etc/networking/interfaces`
contains:

::

        auto eth1
        iface eth1 inet manual
                up ifconfig $IFACE 0.0.0.0 up
                down ifconfig $IFACE 0.0.0.0 down

The second physical interface, eth1 is added to a bridge (in this case
named br-ex), which is used to forward network traffic from guest VMs.
Network traffic from eth1 on the compute nodes is then NAT'd by the
controller node that runs Neutron's `neutron-l3-agent` and provides L3
connectivity.

::

        stack@compute:~$ sudo ovs-vsctl add-br br-ex
        stack@compute:~$ sudo ovs-vsctl add-port br-ex eth1
        stack@compute:~$ sudo ovs-vsctl show
        9a25c837-32ab-45f6-b9f2-1dd888abcf0f
            Bridge br-ex
                Port br-ex
                    Interface br-ex
                        type: internal
                Port phy-br-ex
                    Interface phy-br-ex
                        type: patch
                        options: {peer=int-br-ex}
                Port "eth1"
                    Interface "eth1"




Neutron Networking with Open vSwitch
------------------------------------

Configuring Neutron networking in DevStack is very similar to
configuring `nova-network` - many of the same configuration variables
(like `FIXED_RANGE` and `FLOATING_RANGE`) used by `nova-network` are
used by Neutron, which is intentional.

The only difference is the disabling of `nova-network` in your
localrc, and the enabling of the Neutron components.


Configuration
~~~~~~~~~~~~~

::

        FIXED_RANGE=10.0.0.0/24
        FLOATING_RANGE=192.168.27.0/24
        PUBLIC_NETWORK_GATEWAY=192.168.27.2

        disable_service n-net
        enable_service q-svc
        enable_service q-agt
        enable_service q-dhcp
        enable_service quantum
        enable_service q-meta
        enable_service q-l3
        enable_service neutron

        Q_USE_SECGROUP=True
        ENABLE_TENANT_VLANS=True
        TENANT_VLAN_RANGE=1000:1999
        PHYSICAL_NETWORK=default
        OVS_PHYSICAL_BRIDGE=br-ex

In this configuration we are defining FLOATING_RANGE to be a
subnet that exists in the private RFC1918 address space - however in
in a real setup FLOATING_RANGE would be a public IP address range.

Neutron Networking with Open vSwitch and Provider Networks
----------------------------------------------------------

In some instances, it is desirable to use Neutron's provider
networking extension, so that networks that are configured on an
external router can be utilized by Neutron, and instances created via
Nova can attach to the network managed by the external router.

For example, in some lab environments, a hardware router has been
pre-configured by another party, and an OpenStack developer has been
given a VLAN tag and IP address range, so that instances created via
DevStack will use the external router for L3 connectivity, as opposed to the Neutron L3 service.


Service Configuration
~~~~~~~~~~~~~~~~~~~~~

**Control Node**

In this example, the control node will run the majority of the
OpenStack API and management services (Keystone, Glance,
Nova, Neutron, etc..)


**Compute Nodes**

In this example, the nodes that will host guest instances will run
the `neutron-openvswitch-agent` for network connectivity, as well as
the compute service `nova-compute`.

DevStack Configuration
~~~~~~~~~~~~~~~~~~~~~~

The following is a snippet of the DevStack configuration on the
controller node.

::

        PUBLIC_INTERFACE=eth1

        ## Neutron options
        Q_USE_SECGROUP=True
        ENABLE_TENANT_VLANS=True
        TENANT_VLAN_RANGE=3001:4000
        PHYSICAL_NETWORK=default
        OVS_PHYSICAL_BRIDGE=br-ex

        Q_USE_PROVIDER_NETWORKING=True
        Q_L3_ENABLED=False

        # Do not use Nova-Network
        disable_service n-net

        # Neutron
        ENABLED_SERVICES+=,neutron,q-svc,q-dhcp,q-meta,q-agt

        ## Neutron Networking options used to create Neutron Subnets

        FIXED_RANGE="10.1.1.0/24"
        PROVIDER_SUBNET_NAME="provider_net"
        PROVIDER_NETWORK_TYPE="vlan"
        SEGMENTATION_ID=2010

In this configuration we are defining FIXED_RANGE to be a
subnet that exists in the private RFC1918 address space - however in
in a real setup FIXED_RANGE would be a public IP address range, so
that you could access your instances from the public internet.

The following is a snippet of the DevStack configuration on the
compute node.

::

        # Services that a compute node runs
        ENABLED_SERVICES=n-cpu,rabbit,neutron,q-agt

        ## Neutron options
        Q_USE_SECGROUP=True
        ENABLE_TENANT_VLANS=True
        TENANT_VLAN_RANGE=3001:4000
        PHYSICAL_NETWORK=default
        OVS_PHYSICAL_BRIDGE=br-ex
        PUBLIC_INTERFACE=eth1
        Q_USE_PROVIDER_NETWORKING=True
        Q_L3_ENABLED=False

When DevStack is configured to use provider networking (via
`Q_USE_PROVIDER_NETWORKING` is True and `Q_L3_ENABLED` is False) -
DevStack will automatically add the network interface defined in
`PUBLIC_INTERFACE` to the `OVS_PHYSICAL_BRIDGE`

For example, with the above  configuration, a bridge is
created, named `br-ex` which is managed by Open vSwitch, and the
second interface on the compute node, `eth1` is attached to the
bridge, to forward traffic sent by guest vms.

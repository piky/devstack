Using DevStack with Neutron Networking
======================================

Neutron Networking with Open vSwitch
------------------------------------

Service Configuration
~~~~~~~~~~~~~~~~~~~~~

Compute Nodes:

In this example, the nodes that will host guest instances will run
the `neutron-openvswitch-agent` for network connectivity, as well as
the compute service `nova-compute`.

DevStack Configuration
~~~~~~~~~~~~~~~~~~~~~~

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

The purpose of `PHYSICAL_NETWORK` and `OVS_PHYSICAL_BRIDGE` is
discussed in the next section.
        
Physical Interface Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On each compute node, there are two physical interfaces. The first
interface, eth0 is used for the OpenStack management (API, message
bus, etc) as well as for ssh for an administrator to access the
machine.

::

        stack@compute:~$ ifconfig eth0
        eth0      Link encap:Ethernet  HWaddr bc:16:65:20:af:fc
                  inet addr:192.168.1.18

A bridge is created, named `br-ex` which is managed by Open vSwitch,
and the second interface on the compute node, `eth1` is attached to
the bridge, to forward traffic sent by guest vms.

::

        stack@oscomp-cc38-b01:~$ sudo ovs-vsctl show
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

NOTE: eth1 is manually configured at boot to not have an IP address.
Consult your operating system documentation for the apropriate
technique. For Ubuntu, the contents of `/etc/networking/interfaces`
contains:

::

        auto eth1
        iface eth1 inet manual
                up ifconfig $IFACE 0.0.0.0 up
                down ifconfig $IFACE 0.0.0.0 down

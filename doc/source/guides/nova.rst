=================
Nova and devstack
=================

This is a rough guide to various configuration parameters for nova
running with devstack.


nova-serialproxy
================

`nova-serialproxy
<http://docs.openstack.org/developer/nova/man/nova-serialproxy.html>`_
allows remote access to serial consoles.

The service can be enabled by adding ``n-serial`` to
``ENABLED_SERVICES``.  Further options can be enabled via
``local.conf``, e.g.

::

    [[post-config|$NOVA_CONF]]
    [DEFAULT]
    serial_console base_url http://...
    serial_console listen 8081

See the nova documentation for more information

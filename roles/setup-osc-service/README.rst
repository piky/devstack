Start openstack-server and install a client to use it.

In order for this to override the normal openstackclient binary, the path
must be modified before running devstack so /home/stack/bin is first.

**Role Variables**

.. zuul:rolevar:: devstack_openstack_service
   :default: false

   Whether to use the openstackclient service to speed up execution of
   stack.sh. This starts a persistent service on the node that accepts
   commands through a socket and overrides the "openstack" binary to be
   a simple command that communicates with the service to execute client
   commands.

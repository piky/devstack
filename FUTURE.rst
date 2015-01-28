=============
 Quo Vadimus
=============

Where are we going?

This is a document in Devstack to outline where we are headed in the
future. The future might be near or far, but this is where we'd like
to be.

This is intended to help people contribute, because it will be a
little clearer if a contribution takes us closer or further away to
our end game.

==================
 Default Services
==================

Devstack is designed as a development environment first. There are a
lot of ways to compose the OpenStack services, but we do need one
default.

That should be the Compute Kernel (currently Glance + Nova + Cinder +
Neutron + Keystone). It should be the base building block going
forward, and the introduction point of people to OpenStack via
Devstack.

================
 Service Howtos
================

Starting from the base building block all services included in
OpenStack should have an overview page in the Devstack
documentation. That should include the following:

- A helpful high level overview of that service
- What it depends on (both other OpenStack services and other system
  components)
- What new daemons are needed to be started, including where they
  should live

This provides a map for people doing multinode testing to understand
what portions are control plane, which should live on worker nodes.

Service how to pages will start with an ugly "This team has provided
no information about this service" until someone does.

===================
 Included Services
===================

Devstack doesn't need to eat the world. Given the existance of the
external devstack plugin architecture, it's expected that projects not
in the integrated release will be supported via external plugins.

=============================
 Included Backends / Drivers
=============================

TBD

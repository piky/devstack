.. Documentation Architecture for the devstack docs.

   It is really easy for online docs to meander over time as people
   attempt to add the small bit of additional information they think
   people need, into an existing information architecture. In order to
   prevent that we need to be a bit strict as to what's on this front
   page.

   This should *only* be the quick start narrative. Which should end
   with 2 sections: what you can do with devstack once it's set up,
   and how to go beyond this setup. Both should be a set of quick
   links to other documents to let people explore from there.

DevStack
========

.. image:: assets/images/logo-blue.png

DevStack is a series of extensible scripts used to quickly bring up a
complete OpenStack environment.  It is used interactively as a
development environment and as the basis for much of the OpenStack
project's functional testing.

The source is available at
`<https://git.openstack.org/cgit/openstack-dev/devstack>`__.

Quick Start
-----------

#. Select a Linux Distribution

   Only Ubuntu 14.04/16.04 (Trusty/Xenial), Fedora 22 (or Fedora 23)
   and CentOS/RHEL 7 are documented here. OpenStack also runs and is
   packaged on other flavors of Linux such as OpenSUSE and Debian.

#. Install Selected OS

   In order to correctly install all the dependencies, we assume a
   specific minimal version of the supported distributions to make it as
   easy as possible. We recommend using a minimal install of Ubuntu or
   Fedora server in a VM if this is your first time.

#. Download DevStack

   ::

       git clone https://git.openstack.org/openstack-dev/devstack

   The ``devstack`` repo contains a script that installs OpenStack and
   templates for configuration files

#. Configure

   Create a ``local.conf`` file with 4 passwords preset

   ::

          [[local|localrc]]
          ADMIN_PASSWORD=secret
          DATABASE_PASSWORD=$ADMIN_PASSWORD
          RABBIT_PASSWORD=$ADMIN_PASSWORD
          SERVICE_PASSWORD=$ADMIN_PASSWORD

 #. Add Stack User

   Devstack should be run as a non-root user with sudo enabled
   (standard logins to cloud images such as "ubuntu" or "cloud-user"
   are usually fine).

   You can quickly create a separate `stack` user to run DevStack with

   ::

       devstack/tools/create-stack-user.sh; su stack

#. Start the install, this will take a few minutes.

   ::

       cd devstack; ./stack.sh

#. Profit!

   This will produce a single node devstack running ``keystone``,
   ``glance``, ``nova``, ``cinder``, ``neutron``, and
   ``horizon``. Floating IPs will be available, guests have access to
   the external world.

   You can access horizon to experience the web interface to
   OpenStack, and manage vms, networks, volumes, and images from
   there.

   You can ``source openrc`` in your shell, and then use the
   ``openstack`` command line tool to manage your devstack.

   You can ``cd /opt/stack/tempest`` and run tempest tests that have
   been configured to work with your devstack.

#. Going further

   Learn more about our :doc:`configuration system <configuration>` to
   customize devstack for your needs.

   Read :doc:`guides <guides>` for specific setups people have (note:
   guides are point in time contributions, and may not always be kept
   up to date to the latest devstack).

   Enable :doc:`devstack plugins <plugins>` to support additional
   services, features, and configuration not present in base devstack.

   Get :doc:`the big picture <overview>` of what we are trying to do
   with devstack, and help us by :doc:`contributing to the project
   <hacking>`.

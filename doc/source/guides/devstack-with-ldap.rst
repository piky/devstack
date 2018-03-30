============================
Deploying DevStack with LDAP
============================

The OpenStack Identity service has the ability to integrate with LDAP. The goal
of this guide is to walk you through setting up an LDAP-backed OpenStack
development environment.

Introduction
============

Keystone supports integration with different LDAP deployments per domain
configuration. By default, devstack will setup an OpenLDAP server and wire it
up to a specific keystone domain. Users within that domain will be able to
authenticate against keystone, assume role assignments, and interact with other
OpenStack services.

Configuration
=============

To deploy an OpenLDAP server, make sure ``ldap`` is added to the list of
``ENABLED_SERVICES``::

    ENABLED_SERVICES+=,ldap


Devstack will require a password to setup an LDAP administrator. This
administrative user is also the bind user specified in keystone's configuration
files, similar to a ``keystone`` MySQL database user.

Devstack will prompt you for a password when running ``stack.sh`` if
``LDAP_PASSWORD`` is not set::

    LDAP_PASSWORD=ldapbindpassword
    ./stack.sh

At this point, devstack should have everything it needs to deploy OpenLDAP,
bootstrap it with a minimal set of users, and configure it to back to a domain
in keystone.

Management
==========

Once ``stack.sh`` completes, you should have a running keystone deployment with
a basic set of users. It is important to note that not all users will live
within LDAP. Instead, keystone will back different domains to different
identity sources. For example, the ``default`` domain will be backed by MySQL.
This is usually where you'll find your administrative and services users. If
you query keystone for a list of domains, you should see a domain called
``Users``. This domain is setup by devstack and points to OpenLDAP.

Initially, there will only be two users in the LDAP server. The ``Manager``
user is used by keystone to talk to OpenLDAP. The ``demo`` user is a generic
user that you should be able to see if you query keystone for users within the
``Users`` domain. Both of these users were added to LDAP using basic LDAP
utilities installed by devstack (e.g. ``ldap-utils``) and LDIFs. The LDIFs used
to create these users can be found in ``devstack/files/ldap/``.

Listing Users
-------------

To list all users in LDAP directly, you can use ``ldapsearch`` with the LDAP
user bootstrapped by devstack::

    ldapsearch -x -w $LDAP_PASSWORD -D cn=Manager,dc=openstack,dc=org -H \
        ldap://localhost -b dc=openstack,dc=org

As you can see, devstack creates an OpenStack domain called ``openstack.org``
as a container for the ``Manager`` and ``demo`` users.

Creating Users
--------------

Since keystone's LDAP integration is read-only, users must be added directly to
LDAP. Keystone will automatically see the user after they are created and they
will automatically be placed into the ``Users`` domain.

LDIFs can be used to add users via the command line. The following is an
example LDIF that can be used to create a new LDAP user, let's call it
``pquill.ldif.in``::

    dn: cn=pquill,ou=Users,dc=openstack,dc=org
    cn: pquill
    displayName: Peter Quill
    givenName: Peter Quill
    mail: pquill@openstack.org
    objectClass: inetOrgPerson
    objectClass: top
    sn: pquill
    uid: pquill
    userPassword: im-a-better-pilot-than-rocket

Now, we use the ``Manager`` user to create a user for Peter in LDAP::

    ldapadd -x -w ldapbindpassword -D cn=Manager,dc=openstack,dc=org -H \
        ldap://localhost -c -f pquill.ldif.in

We should be able to assign Peter roles on projects. After Peter has some level
of authorization, he should be able to login to Horizon by specifying the
``Users`` domain and using his ``pquill`` username and password.

Deleting Users
--------------

We can use the same basic steps to remove users from LDAP, but instead of using
LDIFs, we can just pass the ``dn`` of the user we want to delete::

    ldapdelete -x -w ldapbindpassword -D cn=Manager,dc=openstack,dc=org -H \
        ldap://localhost cn=pquill,ou=Users,dc=openstack,dc=org

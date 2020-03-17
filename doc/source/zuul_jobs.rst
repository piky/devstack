Zuul CI Jobs
============

The DevStack repository includes a set of Zuul CI jobs which can be used by
any project inside OpenStack but also by third parties that need to integrate
their systems and test them against OpenStack using Zuul.  The following is
an example of a Zuul tenant with all the needed ``required-projects`` which
consumes DevStack.

.. code-block:: yaml

   - tenant:
       name: devstack
       max-nodes-per-job: 10
       report-build-page: true
       source:
         gerrit:
           untrusted-projects:
             - zuul/zuul-jobs
             # Include all the necessary jobs
             - include: [job, nodeset]
               projects:
                 - openstack/devstack
                 - openstack/tempest
             # Include all the required-projects
             - include: []
               projects:
                 - openstack/cinder
                 - openstack/glance
                 - openstack/keystone
                 - openstack/neutron
                 - openstack/nova
                 - openstack/oslo.cache
                 - openstack/oslo.concurrency
                 - openstack/oslo.config
                 - openstack/oslo.context
                 - openstack/oslo.db
                 - openstack/oslo.i18n
                 - openstack/oslo.log
                 - openstack/oslo.messaging
                 - openstack/oslo.middleware
                 - openstack/oslo.policy
                 - openstack/oslo.privsep
                 - openstack/oslo.reports
                 - openstack/oslo.rootwrap
                 - openstack/oslo.serialization
                 - openstack/oslo.service
                 - openstack/oslo.utils
                 - openstack/oslo.versionedobjects
                 - openstack/oslo.vmware
                 - openstack/placement
                 - openstack/requirements
                 - openstack/swift

Jobs
----

.. zuul:autojobs::

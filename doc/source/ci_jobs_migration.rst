====================================================
Migrating Zuul V2 Devstack CI jobs to Zuul V3 native
====================================================

The OpenStack CI system moved from Zuul v2 to Zuul v3, and all CI jobs moved to
the new CI system. All jobs have been migrated automatically to a format
compatible with Zuul v3; the jobs produced in this way however are suboptimal
and do not use the capabilities introduced by Zuul v3, which allow for re-use of
job parts, in the form of Ansible roles, as well as inheritance between jobs.

Devstack hosts a set of roles, plays and jobs that can be used by other
repositories to define their devstack based jobs. To benefit from them, jobs
must be migrated from the legacy v2 ones into v3 native format.

This document provides guidance and examples to make the migration process as
painless and smooth as possible.

Devstack Gate Flags
===================

The old CI system worked using a combination of devstack, Tempest and
devstack-gate to setup a test environment and run tests against it. With Zuul
V3, the logic that used to live in devstack-gate is moved into different repos,
including devstack, tempest and grenade.

Devstack-gate exposes and interface for job definition based on a number of
DEVSTACK_GATE_* environment variables, or flags. This guide shows how to map
DEVSTACK_GATE flags into the new
system.

The repo column indicates in which repository is hosted the code that replaces
the devstack gate flag. The new implementation column explains how to reproduce
the same or a similar behaviour in Zuul v3 jobs. For localrc settings,
devstack-gate defined a default value. In ansible jobs the default is either the
value defined in the parent job, or the default from devstack, if any.

==============================================  ========= ==================
Devstack gate flag                              Repo      New implementation
==============================================  ========= ==================
OVERRIDE_ZUUL_BRANCH                            zuul      override-checkout:
                                                          [branch]
                                                          in the job definition.
DEVSTACK_GATE_NET_OVERLAY                       zuul-jobs A bridge called
                                                          br-infra is setup for
                                                          all jobs that inherit
                                                          from multinode with
                                                          a dedicated `bridge role <https://docs.openstack.org/infra/zuul-jobs/roles.html#role-multi-node-bridge>`_.
DEVSTACK_GATE_FEATURE_MATRIX                    d-g       `test_matrix_features`
                                                          variable of the
                                                          test-matrix role in
                                                          devstack-gate. This
                                                          is a temporary
                                                          solution, feature
                                                          matrix will go away.
                                                          In the future services
                                                          will be defined in
                                                          jobs only.
DEVSTACK_CINDER_VOLUME_CLEAR                    devstack  *CINDER_VOLUME_CLEAR: true/false*
                                                          in devstack_localrc
                                                          in the job vars.
DEVSTACK_GATE_NEUTRON                           devstack  True by default. To
                                                          disable, disable all
                                                          neutron services in
                                                          devstack_services in
                                                          the job definition.
DEVSTACK_GATE_CONFIGDRIVE                       devstack  *FORCE_CONFIG_DRIVE: true/false*
                                                          in devstack_localrc
                                                          in the job vars.
                                                          Default
DEVSTACK_GATE_INSTALL_TESTONLY                  devstack  *INSTALL_TESTONLY_PACKAGES: true/false*
                                                          in devstack_localrc
                                                          in the job vars.
DEVSTACK_GATE_VIRT_DRIVER                       devstack  *VIRT_DRIVER: [virt driver]*
                                                          in devstack_localrc
                                                          in the job vars.
DEVSTACK_GATE_LIBVIRT_TYPE                      devstack  *LIBVIRT_TYPE: [libvirt type]*
                                                          in devstack_localrc
                                                          in the job vars.
DEVSTACK_GATE_TEMPEST                           devstack  Defined by the job
                                                tempest   that is used. The
                                                          `devstack` job only
                                                          runs devstack.
                                                          The `devstack-tempest`
                                                          one triggers a Tempest
                                                          run as well.
DEVSTACK_GATE_TEMPEST_FULL                      tempest   *tox_envlist: full*
                                                          in the job vars.
DEVSTACK_GATE_TEMPEST_ALL                       tempest   *tox_envlist: all*
                                                          in the job vars.
DEVSTACK_GATE_TEMPEST_ALL_PLUGINS               tempest   *tox_envlist: all-plugin*
                                                          in the job vars.
DEVSTACK_GATE_TEMPEST_SCENARIOS                 tempest   *tox_envlist: scenario*
                                                          in the job vars.
TEMPEST_CONCURRENCY                             tempest   *tempest_concurrency: [value]*
                                                          in the job vars. This
                                                          is available only on
                                                          jobs that inherit from
                                                          `devstack-tempest`
                                                          down.
DEVSTACK_GATE_TEMPEST_NOTESTS                   tempest   *tox_envlist: venv-tempest*
                                                          in the job vars. This
                                                          will create Tempest
                                                          virtual environment
                                                          but run no tests.
DEVSTACK_GATE_SMOKE_SERIAL                      tempest   *tox_envlist: smoke-serial*
                                                          in the job vars.
DEVSTACK_GATE_TEMPEST_DISABLE_TENANT_ISOLATION  tempest   *tox_envlist: full-serial*
                                                          in the job vars.
                                                          *TEMPEST_ALLOW_TENANT_ISOLATION: false*
                                                          in devstack_localrc in
                                                          the job vars.
==============================================  ========= ==================

The following flags have not been migrated yet or are legacy and won't be
migrated at all.

=====================================  ======  ==========================
Devstack gate flag                     Status  Details
=====================================  ======  ==========================
DEVSTACK_GATE_TOPOLOGY                 WIP     The topology depends on the base
                                               job that is used and more
                                               specifically on the nodeset
                                               attached to it. The new job
                                               format allows project to define
                                               the variables to be passed to
                                               every node/node-group that exists
                                               in the topology. Named topologies
                                               that include the nodeset and the
                                               matching variables can be defined
                                               in the form of base jobs.
DEVSTACK_GATE_GRENADE                  TBD     Grenade Zuul V3 jobs will be
                                               hosted in the grenade repo.
GRENADE_BASE_BRANCH                    TBD     Grenade Zuul V3 jobs will be
                                               hosted in the grenade repo.
DEVSTACK_GATE_NEUTRON_DVR              TBD     Depends on multinode support.
DEVSTACK_GATE_EXERCISES                TBD     Can be done on request.
DEVSTACK_GATE_IRONIC                   TBD     This will probably be implemented
                                               on ironic side.
DEVSTACK_GATE_IRONIC_DRIVER            TBD     This will probably be implemented
                                               on ironic side.
DEVSTACK_GATE_IRONIC_BUILD_RAMDISK     TBD     This will probably be implemented
                                               on ironic side.
DEVSTACK_GATE_POSTGRES                 Legacy  This flag exists in d-g but the
                                               only thing that it does is
                                               capture postgres logs. This is
                                               already supported by the roles in
                                               post, so the flag is useless in
                                               the new jobs. postgres itself can
                                               be enabled via the
                                               devstack_service job variable.
DEVSTACK_GATE_ZEROMQ                   Legacy  This has no effect in d-g.
DEVSTACK_GATE_MQ_DRIVER                Legacy  This has no effect in d-g.
DEVSTACK_GATE_TEMPEST_STRESS_ARGS      Legacy  Stress is not in Tempest anymore.
DEVSTACK_GATE_TEMPEST_HEAT_SLOW        Legacy  This is not used anywhere.
DEVSTACK_GATE_CELLS                    Legacy  This has no effect in d-g.
DEVSTACK_GATE_NOVA_API_METADATA_SPLIT  Legacy  This has no effect in d-g.
=====================================  ======  ==========================

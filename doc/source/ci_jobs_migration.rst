====================================================
Migrating Zuul V2 Devstack CI jobs to Zuul V3 native
====================================================

The OpenStack CI system moved from Zuul v2 to Zuul v3, and all CI
jobs moved to the new CI system. All jobs have been migrated
automatically to a format compatible with Zuul v3; the jobs
produced in this way however are suboptimal and do not use the
capabilities introduced by Zuul v3, which allow for re-use of
job parts, in the form of Ansible roles, as well as inheritance
between jobs.

Devstack hosts a set of roles, plays and jobs that can be used
by other repositories to define their devstack based jobs.
To benefit from them, jobs must be migrated from the legacy v2
ones into v3 native format.

This document provides guidance and examples to make the
migration process as painless and smooth as possible.

Devstack Gate Flags
===================

The old CI system worked using a combination of devstack,
tempest and devstack-gate to setup a test environment and run
tests against it. With Zuul V3, the logic that used to live
in devstack-gate is moved into different repos, including
devstack, tempest and grenade.

Devstack-gate exposes and interface for job definition based
on a number of DEVSTACK_GATE_* environment variables, or flags.
This guide shows how to map DEVSTACK_GATE flags into the new
system.

============================  ======== ==================
Devstack gate flag            Repo     New implementation
============================  ======== ==================
DEVSTACK_GATE_FEATURE_MATRIX  d-g      `test_matrix_features` variable of the
                                       test-matrix role in devstack-gate. This
                                       is a temporary solution, feature matrix
                                       will go away. In the future services will
                                       be defined in jobs only.
DEVSTACK_GATE_TEMPEST         devstack Defined by the job that is used. The
                              tempest  `devstack` job only runs devstack. The
                                       `devstack-tempest` one triggers a Tempest
                                       run as well.
============================  ==================

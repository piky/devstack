Reads the OS_* variables set by devstack through openrc
for the specified user and project and exports them as
the os_env_vars fact.

**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.

.. zuul:rolevar:: openrc_file
   :default: {{ devstack_base_dir }}/devstack/openrc

   The location of the generated openrc file.

.. zuul:rolevar:: openrc_user
   :default: admin

   The user whose credentials should be retrieved.

.. zuul:rolevar:: openrc_project
   :default: admin

   The project (which openrc_user is part of) whose
   access data should be retrieved.

.. zuul:rolevar:: openrc_export_skip
   :default: false

   Set it to true to not export os_env_vars.

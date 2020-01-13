Extract the OS underscore environment variables

Extracts the OS underscore environment variables and saves them
as a fact.

**Role Variables**

.. zuul:rolevar:: openrc_file
   :default: {{ devstack_base_dir }}/devstack/openrc

   Absolute pathname of the openrc file.

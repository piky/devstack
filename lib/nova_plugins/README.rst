Nova Hypervisor Plugins
=======================

DevStack configures Nova's hypervisor according to the setting of
``VIRT_DRIVER``.  ``stack.sh`` loads the file in this directory
cooresponding to ``hypervisor-$VIRT_DRIVER`` if it exists.  If no
file exists with that name ``stack.sh`` aborts.

The plugin file is expected to:

    * Define the global configuration environment variables that
      may be required in other services, such as ``LIBVIRT_FIREWALL_DRIVER``.
      The file is sourced after all other service lib files but before
      any of the services are configured.
    * Declare a single function ``configure_nova_hypervisor()`` that
      performs the configuration necessary in Nova and other services
      to enable the hypervisor driver.  This function is called after all
      service files have been sourced and services configureg but
      before any service has been started.

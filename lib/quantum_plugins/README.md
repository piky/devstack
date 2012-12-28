Quantum plugin specific files
=============================
Quantum plugins requires plugin specific behavior.
The files under the directory, lib/quantum_plugins/, will be used
when their service are enabled.
Each plugin have lib/quantum_plugins/$Q_PLUGIN and define the following
functions.

functions
---------
lib/quantum calls the following functions when the <third_party> is enabled

filename: <plugin>
   The corresponding file name should be same to plugin name, $Q_PLUGIN.
   third party specific configuration variables should be in this file.

functions to be implemented
lib/quantum calls those entry points

* quantum_plugin_create_nova_conf
  set NOVA_VIF_DRIVER and optially set options in nova_conf
  e.g.
  NOVA_VIF_DRIVER=${NOVA_VIF_DRIVER:-"nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver"}
* quantum_plugin_install_agent_packages
  install packages that is specific to plugin agent
  e.g.
  install_package bridge-utils
* quantum_plugin_configure_common
  set plugin-specific variables, Q_PLUGIN_CONF_PATH, Q_PLUGIN_CONF_FILENAME,
  Q_DB_NAME, Q_PLUGIN_CLASS
* quantum_plugin_configure_debug_command
* quantum_plugin_configure_dhcp_agent
* quantum_plugin_configure_l3_agent
* qauntum_plugin_configure_plugin_agent
* quantum_plugin_configure_service
* quantum_plugin_setup_interface_driver

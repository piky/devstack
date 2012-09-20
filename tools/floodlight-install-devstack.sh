#!/bin/sh
#
# Install essex/stable devstack and openstack with quantum and restproxy
# Note:
#   1. this script uses the same password for all openstack services
#   2. this script uses the restproxy code with tag 'for-exxex/stable'
#      (unset RESTPROXY_GITTAG variable to use restproxy in current dir)
#
# This version has been modified to work with an updated stable/essex devstack
#
# See usage below:
USAGE="$0 <network-controller-for-restproxy> [[port] [<password>]]"

set -e

# set parameters
RESTPROXY_CONTROLLER=$1
RESTPROXY_CONTROLLER_PORT=${2:-'80'}
STACK_PASSWORD=${3:-'nova'}
STACK_TOP='/opt/stack'
RESTPROXY_GITTAG="for-essex/stable"
QAUNTUM_PLUGINDIR="${STACK_TOP}/quantum/quantum/plugins"

#
# Validate env
#
if [ ! -f /etc/lsb-release ] ; then
    echo "ERROR: This script is only supported on ubuntu" 1>&2
    exit 1
fi
eval `cat /etc/lsb-release`
if [ "${DISTRIB_RELEASE}"x != "12.04"x ] ; then
    echo "ERROR: This script is only supported on ubuntu 12.04" 1>&2
    exit 1
fi

RESTPROXY_HOMEDIR=`dirname $0`/..
if [ ! -d "${RESTPROXY_HOMEDIR}" ] ; then
    echo "ERROR: Directory '${RESTPROXY_HOMEDIR}' not found." 1>&2
    exit 1
fi
RESTPROXY_HOMEDIR=`cd ${RESTPROXY_HOMEDIR}; pwd`

# Validate args
if [ "${RESTPROXY_CONTROLLER}"x = ""x ] ; then
    echo "ERROR: RESTPROXY_CONTROLLER not defined." 1>&2
    echo "USAGE: ${USAGE}" 2>&1
    exit 2
fi

# install git
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y install gcc make python-all-dev python-pip git

# get devstack
cd ${HOME}
git clone http://github.com/openstack-dev/devstack.git

cd ${HOME}/devstack
cat >localrc.ovs <<EOF
MYSQL_PASSWORD=${STACK_PASSWORD}
RABBIT_PASSWORD=${STACK_PASSWORD}
SERVICE_TOKEN=${STACK_PASSWORD}
SERVICE_PASSWORD=${STACK_PASSWORD}
ADMIN_PASSWORD=${STACK_PASSWORD}

# enable quantum and ovs-plugin
Q_PLUGIN=openvswitch
ENABLED_SERVICES="g-api,g-reg,key,n-api,n-cpu,n-net,n-sch,n-novnc,n-xvnc,n-cauth,horizon,mysql,rabbit,openstackx,q-svc,q-agt,quantum"
EOF

cat >localrc.restproxy <<EOF
MYSQL_PASSWORD=${STACK_PASSWORD}
RABBIT_PASSWORD=${STACK_PASSWORD}
SERVICE_TOKEN=${STACK_PASSWORD}
SERVICE_PASSWORD=${STACK_PASSWORD}
ADMIN_PASSWORD=${STACK_PASSWORD}

# enable quantum and restproxy
Q_PLUGIN=restproxy
RESTPROXY_CONTROLERS=${RESTPROXY_CONTROLLER}
LIBVIRT_FIREWALL_DRIVER=nova.virt.firewall.NoopFirewallDriver
ENABLED_SERVICES="g-api,g-reg,key,n-api,n-cpu,n-net,n-sch,n-novnc,n-xvnc,n-cauth,horizon,mysql,rabbit,openstackx,q-svc,q-agt,quantum"
EOF

cat >restproxy.ini <<EOF
[restproxy]
#
# Configure restproxy
#
# The following parameters are supported:
#   debug       :   True | False                (Default: False)
#   use_syslog  :   True | False                (Default: False)
#   log_file    :   <name of file>              (Default: None, use stdout)
#   log_dir     :   <dir-name>
#                   The plugin must have write permissions to that file/dir
#   log_format  :   <log format>
#   log_date_format: <log date format>
#   servers     :   <host:port>[,<host:port>]*  (Error if not set)
#   serverauth  :   <username:password>         (default: no auth)
#   serverssl   :   True | False                (default: False)
#   proxydb     :   <db-string> (default: mysql://root@localhost/restproxy)
#   novadb      :   <db-string> (default: mysql://root@localhost/nova)
#
debug=True
use_syslog=False
log_file=restproxy.log
log_dir=/tmp
proxydb=mysql://root:${STACK_PASSWORD}@localhost/restproxy
novadb=mysql://root:${STACK_PASSWORD}@localhost/nova

#
# Network controllers
#
servers=${RESTPROXY_CONTROLLER}:${RESTPROXY_CONTROLLER_PORT}
serverauth=
serverssl=
EOF

cat >patch.nova <<'EOF'
diff --git nova/network/l3.py nova/network/l3.py
index 4603bdf..b29c33a 100644
--- nova/network/l3.py
+++ nova/network/l3.py
@@ -121,6 +121,12 @@ class LinuxNetL3(L3Driver):
         pass


+class LinuxNetNoNatL3(LinuxNetL3):
+    """L3 driver that uses linux_net as the backend without ahy SNAT"""
+    def initialize_network(self, cidr):
+        pass
+
+
 class NullL3(L3Driver):
     """The L3 driver that doesn't do anything.  This class can be used when
        nova-network shuld not manipulate L3 forwarding at all (e.g., in a Flat
diff --git nova/network/quantum/melange_ipam_lib.py nova/network/quantum/melange_ipam_lib.py
index c68d83c..bb1755d 100644
--- nova/network/quantum/melange_ipam_lib.py
+++ nova/network/quantum/melange_ipam_lib.py
@@ -152,7 +152,7 @@ class QuantumMelangeIPAMLib(object):

     def get_tenant_id_by_net_id(self, context, net_id, vif_id, project_id):
         ipam_tenant_id = None
-        tenant_ids = [FLAGS.quantum_default_tenant_id, project_id, None]
+        tenant_ids = [project_id, FLAGS.quantum_default_tenant_id, None]
         # This is confusing, if there are IPs for the given net, vif,
         # tenant trifecta we assume that is the tenant for that network
         for tid in tenant_ids:
EOF

# Checkout essex/stable and start devstack once and kill it
git checkout stable/essex
cp localrc.ovs localrc
./stack.sh || :
SCREENPID=`screen -ls | grep \\.stack | cut -f1 -d.`
[ "${SCREENPID}"x = ""x ] || kill -QUIT ${SCREENPID}

# apply patches
(
    cd ${STACK_TOP}/python-quantumclient;
    git checkout 9b09f53a158a6184a560190b0d26293dcc1a44a6
    cd ${STACK_TOP}/nova
    patch -p0 < ${HOME}/devstack/patch.nova
)

# fix libvirt:
sudo tee /etc/libvirt/qemu.conf <<EOF
cgroup_device_acl = [
   "/dev/null", "/dev/full", "/dev/zero",
   "/dev/random", "/dev/urandom",
   "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
   "/dev/rtc", "/dev/hpet", "/dev/net/tun",
]
EOF
sudo service libvirt-bin stop
sudo service libvirt-bin start

# Install restproxy in quantum tree
(
    cd ${HOME}/devstack
    if [ "${RESTPROXY_GITTAG}"x != ""x ] ; then
        git clone http://github.com/floodlight/quantum-restproxy.git restproxy
        cd restproxy
        git checkout "${RESTPROXY_GITTAG}"
    else
        mkdir restproxy
        cd restproxy
        (cd ${RESTPROXY_HOMEDIR}; tar cf - .) | sudo tar xvf -
    fi

    (cd ${QAUNTUM_PLUGINDIR} ; sudo rm -rf restproxy)
    sudo mv ${HOME}/devstack/restproxy ${QAUNTUM_PLUGINDIR}
)

# set up restproxy config
cd ${HOME}/devstack
cp localrc.restproxy localrc
sudo mkdir -p /etc/quantum/plugins/restproxy
sudo cp restproxy.ini /etc/quantum/plugins/restproxy/restproxy.ini

# Done
echo "$0 Done."
echo "Start devstack as:"
echo "   cd ~/devstack; ./stack.sh"
echo ""

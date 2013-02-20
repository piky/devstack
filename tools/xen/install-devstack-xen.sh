#!/bin/bash
#
# This script installs a DevStack DomU VM on
# the specified XenServer.
set -e

function syntax
{
    echo "Syntax: $0 [-i <private key>] <host> <root password>"
    echo "Note: environment variables \$Server and \$XenServerPassword can be used in place of command line arguments"
    exit 1
}

function execute_remote
{
    ssh $ssh_options "root@$Server" "$@"
}

function create_template
{
cat > $1 <<EOF
#
# Set passwords to avoid prompts
#
MYSQL_PASSWORD=citrix
SERVICE_TOKEN=citrix
ADMIN_PASSWORD=citrix
SERVICE_PASSWORD=citrix
RABBIT_PASSWORD=citrix
# This is the password for your DomU (for both stack and root users)
GUEST_PASSWORD=citrix
# IMPORTANT: The following must be set to your dom0 root password!
XENAPI_PASSWORD=%XenServerPassword%

# TEMPEST SETTINGS
#
# Need to be set, otherwise image resize fails (TODO: bug)
DEFAULT_INSTANCE_TYPE="m1.small"

#
# Compute settings
#
MULTI_HOST=true
# our image doesn't have the agent
EXTRA_OPTS=("xenapi_disable_agent=True")
OSDOMU_MEM_MB=4096
#FIXME - see LP 1102964 XEN_FIREWALL_DRIVER=nova.virt.xenapi.firewall.Dom0IptablesFirewallDriver
# turn off rate limit to help tempest
API_RATE_LIMIT=False
VIRT_DRIVER=xenserver

#
# Volume settings
#
# make tempest pass by having bigger volume file
VOLUME_BACKING_FILE_SIZE=10000M

#
# Networking settings
#

# MGMT network params
MGT_IP="dhcp"
MGT_NETMASK=255.255.255.0
MGT_BR=xenbr0
MGT_VLAN=-1
MGT_DEV=eth0

# Public network
PUB_IP=172.24.4.10
PUB_NETMASK=255.255.255.0
PUB_BR=xenbr1
PUB_VLAN=-1
PUB_DEV=eth1

# VM network params
VM_IP=10.255.255.255
VM_NETMASK=255.255.255.0
VM_BR=""
VM_VLAN=%XenServerVmVlan%
VM_DEV=eth1
FLAT_NETWORK_BRIDGE="vmbr"

# XenAPI is on mangement network
HOST_IP_IFACE=eth2

#
# DevStack XenServer tools settings
#
NETINSTALLIP="dhcp"
NETINSTALL_IFACE=eth2
NAMESERVERS=""
NETMAST=""
GATEWAY=""
UBUNTU_INST_RELEASE=precise

#
# exercise.sh settings
#
# boot from volume doesn't yet work on our setup
SKIP_EXERCISES="boot_from_volume"
ACTIVE_TIMEOUT=500
TERMINATE_TIMEOUT=500

#
# DevStack settings
#
LOGFILE=/tmp/devstack/log/stack.log
SCREEN_LOGDIR=/tmp/devstack/log/
ENABLED_SERVICES+=,tempest,

#
# XenServer settings
#
OSDOMU_VDI_GB=40
EOF
}

# Temporary directory
tmpdir=`mktemp -d`
trap "rm -rf $tmpdir" EXIT

# Set up variables.  Default is to use Citrix's internal private key
priv_id=""
[ -e "../../../infrastructure.hg" ] && priv_id="../../../infrastructure.hg/puppet/modules/jenkins/files/id_rsa"

while getopts ":i:" option; do
    case $option in
	i) pub_id=$OPTARG;;
	\?) echo "Invalid option -$OPTARG"; exit 1;;
    esac
done

Server=${1:-$Server}
XenServerPassword=${2:-$XenServerPassword}
XenServerVmVlan=${XenServerVmVlan:-24}

thisdir=$(dirname $(readlink -f "$0"))
TEMPLATE_LOCALRC="${thisdir}/localrc.template"

[ -z $Server ] && syntax
[ -z $XenServerPassword ] && syntax
[ -z $XenServerVmVlan ]&& syntax

if [ ! -e $priv_id ]; then
    echo "ID file $priv_id does not exist; specify valid private key using -i argument"
    exit 1
fi
ssh-keygen -y -f $priv_id > $tmpdir/key.pub
if [ ! -e $TEMPLATE_LOCALRC ]; then
    echo "Template localrc $TEMPLATE_LOCALRC not found - generating new template"
    create_template $TEMPLATE_LOCALRC
fi

# Now we have our variables set up, ensure we don't mis-type them
set -u

# Tolerate this ssh failing - we might need to copy the key across
set +e
ssh -o LogLevel=quiet -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $priv_id root@$Server /bin/true >/dev/null 2>&1
if [ $? != 0 ] ; then
    set -e
    echo "Please supply password for ssh-copy-id.  This should be the last time the password is needed:"
    ssh-copy-id -i $tmpdir/key.pub root@$Server
fi
set -e

ssh_options="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $priv_id"

GENERATED_LOCALRC=$tmpdir\localrc

# Generate localrc
cat $TEMPLATE_LOCALRC |
sed -e "s,%XenServerVmVlan%,$XenServerVmVlan,g;
        s,%XenServerPassword%,$XenServerPassword,g;
" > $GENERATED_LOCALRC

LocalrcAppend=${LocalrcAppend-"localrc.append"}
[ -e "${LocalrcAppend}" ] && ( cat "$LocalrcAppend" >> $GENERATED_LOCALRC ) || echo "$LocalrcAppend was not found, not appending to localrc"

set -x

# The parmaters expected are:
# $Server - XenServer host for compute DomU
# $XenServerVmVlan - Vlan ID
# $XenServerPassword - Password for your XenServer

# $MirrorHttpHostname (default:archive.ubuntu.com)- Ubuntu mirror to use
# $MirrorHttpDirectory (default: /ubuntu) - directory within the http mirror
# $MirrorHttpProxy (default: <empty>) - http proxy to use
# $DevStackURL (optional) - URL of the devstack zip file
# $CleanTemplates (default:false) - If true, clean the templates

MirrorHttpHostname=${MirrorHttpHostname-"archive.ubuntu.com"}
MirrorHttpDirectory=${MirrorHttpDirectory-"/ubuntu"}
MirrorHttpProxy=${MirrorHttpProxy-""}
#DevStackURL=${DevStackURL-"https://github.com/openstack-dev/devstack/zipball/master"}
DevStackURL=${DevStackURL-"https://github.com/citrix-openstack/devstack/zipball/bobba-dev"}
CleanTemplates="${CleanTemplates-false}"
DhcpTimeout=120

# GUEST_IP is used by run-devstack-xen-mutli
# to trigger a re-write of the localrc file
GuestIP="${GUEST_IP-false}"

#
# Optionally modify localrc
# to create a secondary compute host
#
if [ "$GuestIP" != "false" ]
then
    cat <<EOF >> $GENERATED_LOCALRC
# appended by jenkins
# TODO - g-api only added due to dependency error with glance client
ENABLED_SERVICES=n-cpu,n-net,n-api,g-api
MYSQL_HOST=$GuestIP
RABBIT_HOST=$GuestIP
KEYSTONE_AUTH_HOST=$GuestIP
GLANCE_HOSTPORT=$GuestIP:9292

# TODO - allow these to be configured
PUB_IP=172.24.4.11
VM_IP=10.255.255.254
GUEST_NAME=DevStackComputeSlave
EOF
fi

#
# Add the clean templates setting
# and correct the IP address for dom0
#
XenApiIP=`execute_remote ifconfig xenbr0 | grep "inet addr" | cut -d ":" -f2 | sed "s/ .*//"`
cat <<EOF >> $GENERATED_LOCALRC
CLEAN_TEMPLATES=$CleanTemplates
XENAPI_CONNECTION_URL="http://$XenApiIP"
VNCSERVER_PROXYCLIENT_ADDRESS=$XenApiIP
EOF

#
# Show the content on the localrc file
#

set +x
echo "Content of localrc file:"
cat $GENERATED_LOCALRC
echo "** end of localrc file **"

#
# Run the next steps on the XenServer host
#

#
# Clean directory, create directory and
# copy what we need to the XenServer
#
SCRIPT_TMP_DIR=/tmp/jenkins_test
cat > $tmpdir/install_devstack.sh <<EOF
#!/bin/bash
rm -rf $SCRIPT_TMP_DIR
mkdir -p $SCRIPT_TMP_DIR

wget -nv --no-check-certificate $DevStackURL -O $SCRIPT_TMP_DIR/devstack.zip
# Remove the top-level directory (<user>-<repo>-<commit>) so the output is in a "devstack" directory
unzip -oq $SCRIPT_TMP_DIR/devstack.zip -d $SCRIPT_TMP_DIR/tmpunzip
mv $SCRIPT_TMP_DIR/tmpunzip/* $SCRIPT_TMP_DIR/devstack
rm -rf $SCRIPT_TMP_DIR/tmpunzip

preseedcfg=$SCRIPT_TMP_DIR/devstack/tools/xen/devstackubuntupreseed.cfg
sed -ie "s,\(d-i mirror/http/hostname string\).*,\1 ${MirrorHttpHostname},g" \$preseedcfg
sed -ie "s,\(d-i mirror/http/proxy string\).*,\1 ${MirrorHttpProxy},g" \$preseedcfg
sed -ie "s,\(d-i mirror/http/directory string\).*,\1 ${MirrorHttpDirectory},g" \$preseedcfg
# Additional DHCP timeout
sed -ie "s,#\(d-i netcfg/dhcp_timeout string\).*,\1 ${DhcpTimeout},g" \$preseedcfg

cp /tmp/localrc $SCRIPT_TMP_DIR/devstack/localrc

pushd $SCRIPT_TMP_DIR/devstack/tools/xen/
./install_os_domU.sh
popd
EOF
chmod +x $tmpdir/install_devstack.sh
echo
echo "*** Content of install_devstack.sh ***"
cat $tmpdir/install_devstack.sh
echo "*** End of install_devstack.sh ***"

set -x

scp $ssh_options "$GENERATED_LOCALRC" "root@$Server:/tmp/localrc"
scp $ssh_options "$tmpdir/install_devstack.sh" "root@$Server:/tmp/install_devstack.sh"
execute_remote "chmod +x /tmp/install_devstack.sh && /tmp/install_devstack.sh | tee $SCRIPT_TMP_DIR/install_devstack.log"

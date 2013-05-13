#!/bin/bash

# This script must be run on a XenServer or XCP machine
#
# It creates a DomU VM that runs OpenStack services
#
# For more details see: README.md

set -o errexit
set -o nounset
set -o xtrace

# Abort if localrc is not set
if [ ! -e ../../localrc ]; then
    echo "You must have a localrc with ALL necessary passwords defined before proceeding."
    echo "See the xen README for required passwords."
    exit 1
fi

# This directory
THIS_DIR=$(cd $(dirname "$0") && pwd)

# Source lower level functions
. $THIS_DIR/../../functions

# Include onexit commands
. $THIS_DIR/scripts/on_exit.sh

# xapi functions
. $THIS_DIR/functions

#
# Get Settings
#

# Source params - override xenrc params in your localrc to suit your taste
source $THIS_DIR/xenrc

xe_min()
{
  local cmd="$1"
  shift
  xe "$cmd" --minimal "$@"
}

#
# Prepare Dom0
# including installing XenAPI plugins
#

cd $THIS_DIR

# Install plugins

## Nova plugins
NOVA_ZIPBALL_URL=${NOVA_ZIPBALL_URL:-$(zip_snapshot_location $NOVA_REPO $NOVA_BRANCH)}
install_xapi_plugins_from_zipball $NOVA_ZIPBALL_URL

## Install the netwrap xapi plugin to support agent control of dom0 networking
if [[ "$ENABLED_SERVICES" =~ "q-agt" && "$Q_PLUGIN" = "openvswitch" ]]; then
    QUANTUM_ZIPBALL_URL=${QUANTUM_ZIPBALL_URL:-$(zip_snapshot_location $QUANTUM_REPO $QUANTUM_BRANCH)}
    install_xapi_plugins_from_zipball $QUANTUM_ZIPBALL_URL
fi

create_directory_for_kernels

#
# Configure Networking
#
setup_network "$VM_BRIDGE_OR_NET_NAME"
setup_network "$MGT_BRIDGE_OR_NET_NAME"
setup_network "$PUB_BRIDGE_OR_NET_NAME"

if parameter_is_specified "FLAT_NETWORK_BRIDGE"; then
    cat >&2 << EOF
ERROR: FLAT_NETWORK_BRIDGE is specified in localrc file
This is considered as an error, as its value will be derived from the 
VM_BRIDGE_OR_NET_NAME variable's value.
EOF
    exit 1
fi

if ! xenapi_is_listening_on "$MGT_BRIDGE_OR_NET_NAME"; then
    cat >&2 << EOF
ERROR: XenAPI does not have an assigned IP address on the management network.
please review your XenServer network configuration / localrc file.
EOF
    exit 1
fi

HOST_IP=$(xenapi_ip_on "$MGT_BRIDGE_OR_NET_NAME")

# Set up ip forwarding, but skip on xcp-xapi
if [ -a /etc/sysconfig/network ]; then
    if ! grep -q "FORWARD_IPV4=YES" /etc/sysconfig/network; then
      # FIXME: This doesn't work on reboot!
      echo "FORWARD_IPV4=YES" >> /etc/sysconfig/network
    fi
fi
# Also, enable ip forwarding in rc.local, since the above trick isn't working
if ! grep -q  "echo 1 >/proc/sys/net/ipv4/ip_forward" /etc/rc.local; then
    echo "echo 1 >/proc/sys/net/ipv4/ip_forward" >> /etc/rc.local
fi
# Enable ip forwarding at runtime as well
echo 1 > /proc/sys/net/ipv4/ip_forward


#
# Shutdown previous runs
#

DO_SHUTDOWN=${DO_SHUTDOWN:-1}
CLEAN_TEMPLATES=${CLEAN_TEMPLATES:-false}
if [ "$DO_SHUTDOWN" = "1" ]; then
    # Shutdown all domU's that created previously
    clean_templates_arg=""
    if $CLEAN_TEMPLATES; then
        clean_templates_arg="--remove-templates"
    fi
    ./scripts/uninstall-os-vpx.sh $clean_templates_arg

    # Destroy any instances that were launched
    for uuid in `xe vm-list | grep -1 instance | grep uuid | sed "s/.*\: //g"`; do
        echo "Shutting down nova instance $uuid"
        xe vm-unpause uuid=$uuid || true
        xe vm-shutdown uuid=$uuid || true
        xe vm-destroy uuid=$uuid
    done

    # Destroy orphaned vdis
    for uuid in `xe vdi-list | grep -1 Glance | grep uuid | sed "s/.*\: //g"`; do
        xe vdi-destroy uuid=$uuid
    done
fi


#
# Create Ubuntu VM template
# and/or create VM from template
#

GUEST_NAME=${GUEST_NAME:-"DevStackOSDomU"}
TNAME="devstack_template"
SNAME_PREPARED="template_prepared"
SNAME_FIRST_BOOT="before_first_boot"

function wait_for_VM_to_halt() {
    set +x
    echo "Waiting for the VM to halt.  Progress in-VM can be checked with vncviewer:"
    mgmt_ip=$(echo $XENAPI_CONNECTION_URL | tr -d -c '1234567890.')
    domid=$(xe vm-list name-label="$GUEST_NAME" params=dom-id minimal=true)
    port=$(xenstore-read /local/domain/$domid/console/vnc-port)
    echo "vncviewer -via $mgmt_ip localhost:${port:2}"
    while true
    do
        state=$(xe_min vm-list name-label="$GUEST_NAME" power-state=halted)
        if [ -n "$state" ]
        then
            break
        else
            echo -n "."
            sleep 20
        fi
    done
    set -x
}

templateuuid=$(xe template-list name-label="$TNAME")
if [ -z "$templateuuid" ]; then
    #
    # Install Ubuntu over network
    #

    # always update the preseed file, incase we have a newer one
    PRESEED_URL=${PRESEED_URL:-""}
    if [ -z "$PRESEED_URL" ]; then
        PRESEED_URL="${HOST_IP}/devstackubuntupreseed.cfg"
        HTTP_SERVER_LOCATION="/opt/xensource/www"
        if [ ! -e $HTTP_SERVER_LOCATION ]; then
            HTTP_SERVER_LOCATION="/var/www/html"
            mkdir -p $HTTP_SERVER_LOCATION
        fi
        cp -f $THIS_DIR/devstackubuntupreseed.cfg $HTTP_SERVER_LOCATION
        MIRROR=${MIRROR:-""}
        if [ -n "$MIRROR" ]; then
            sed -e "s,d-i mirror/http/hostname string .*,d-i mirror/http/hostname string $MIRROR," \
                -i "${HTTP_SERVER_LOCATION}/devstackubuntupreseed.cfg"
        fi
    fi

    # Update the template
    $THIS_DIR/scripts/install_ubuntu_template.sh $PRESEED_URL

    # create a new VM with the given template
    # creating the correct VIFs and metadata
    FLAT_NETWORK_BRIDGE=$(bridge_for "$VM_BRIDGE_OR_NET_NAME")
    $THIS_DIR/scripts/install-os-vpx.sh \
        -t "$UBUNTU_INST_TEMPLATE_NAME" \
        -v "$VM_BRIDGE_OR_NET_NAME" \
        -m "$MGT_BRIDGE_OR_NET_NAME" \
        -p "$PUB_BRIDGE_OR_NET_NAME" \
        -l "$GUEST_NAME" \
        -r "$OSDOMU_MEM_MB" \
        -k "flat_network_bridge=${FLAT_NETWORK_BRIDGE}"

    # wait for install to finish
    wait_for_VM_to_halt

    # set VM to restart after a reboot
    vm_uuid=$(xe_min vm-list name-label="$GUEST_NAME")
    xe vm-param-set actions-after-reboot=Restart uuid="$vm_uuid"

    #
    # Prepare VM for DevStack
    #

    # Install XenServer tools, and other such things
    $THIS_DIR/prepare_guest_template.sh "$GUEST_NAME"

    # start the VM to run the prepare steps
    xe vm-start vm="$GUEST_NAME"

    # Wait for prep script to finish and shutdown system
    wait_for_VM_to_halt

    # Make template from VM
    snuuid=$(xe vm-snapshot vm="$GUEST_NAME" new-name-label="$SNAME_PREPARED")
    xe snapshot-clone uuid=$snuuid new-name-label="$TNAME"
else
    #
    # Template already installed, create VM from template
    #
    vm_uuid=$(xe vm-install template="$TNAME" new-name-label="$GUEST_NAME")
fi


#
# Inject DevStack inside VM disk
#
$THIS_DIR/build_xva.sh "$GUEST_NAME"

# create a snapshot before the first boot
# to allow a quick re-run with the same settings
xe vm-snapshot vm="$GUEST_NAME" new-name-label="$SNAME_FIRST_BOOT"


#
# Run DevStack VM
#
xe vm-start vm="$GUEST_NAME"


#
# Find IP and optionally wait for stack.sh to complete
#

function find_ip_by_name() {
  local guest_name="$1"
  local interface="$2"
  local period=10
  max_tries=10
  i=0
  while true
  do
    if [ $i -ge $max_tries ]; then
      echo "Timed out waiting for devstack ip address"
      exit 11
    fi

    devstackip=$(xe vm-list --minimal \
                 name-label=$guest_name \
                 params=networks | sed -ne "s,^.*${interface}/ip: \([0-9.]*\).*\$,\1,p")
    if [ -z "$devstackip" ]
    then
      sleep $period
      ((i++))
    else
      echo $devstackip
      break
    fi
  done
}

function ssh_no_check() {
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$@"
}

# Note the XenServer needs to be on the chosen
# network, so XenServer can access Glance API
if [ $HOST_IP_IFACE == "eth2" ]; then
    DOMU_IP=$MGT_IP
    if [ $MGT_IP == "dhcp" ]; then
        DOMU_IP=$(find_ip_by_name $GUEST_NAME 2)
    fi
else
    DOMU_IP=$PUB_IP
    if [ $PUB_IP == "dhcp" ]; then
        DOMU_IP=$(find_ip_by_name $GUEST_NAME 3)
    fi
fi

# If we have copied our ssh credentials, use ssh to monitor while the installation runs
WAIT_TILL_LAUNCH=${WAIT_TILL_LAUNCH:-1}
COPYENV=${COPYENV:-1}
if [ "$WAIT_TILL_LAUNCH" = "1" ]  && [ -e ~/.ssh/id_rsa.pub  ] && [ "$COPYENV" = "1" ]; then
    set +x

    echo "VM Launched - Waiting for startup script"
    # wait for log to appear
    while ! ssh_no_check -q stack@$DOMU_IP "[ -e run.sh.log ]"; do
        sleep 10
    done
    echo -n "Running"
    while [ `ssh_no_check -q stack@$DOMU_IP pgrep -c run.sh` -ge 1 ]
    do
        sleep 10
        echo -n "."
    done
    echo "done!"
    set -x

    # output the run.sh.log
    ssh_no_check -q stack@$DOMU_IP 'cat run.sh.log'

    # Fail if the expected text is not found
    ssh_no_check -q stack@$DOMU_IP 'cat run.sh.log' | grep -q 'stack.sh completed in'

    set +x
    echo "################################################################################"
    echo ""
    echo "All Finished!"
    echo "You can visit the OpenStack Dashboard"
    echo "at http://$DOMU_IP, and contact other services at the usual ports."
else
    set +x
    echo "################################################################################"
    echo ""
    echo "All Finished!"
    echo "Now, you can monitor the progress of the stack.sh installation by "
    echo "tailing /opt/stack/run.sh.log from within your domU."
    echo ""
    echo "ssh into your domU now: 'ssh stack@$DOMU_IP' using your password"
    echo "and then do: 'tail -f /opt/stack/run.sh.log'"
    echo ""
    echo "When the script completes, you can then visit the OpenStack Dashboard"
    echo "at http://$DOMU_IP, and contact other services at the usual ports."
fi

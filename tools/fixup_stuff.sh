#!/usr/bin/env bash

# **fixup_stuff.sh**

# fixup_stuff.sh
#
# All distro and package specific hacks go in here
#
# - prettytable 0.7.2 permissions are 600 in the package and
#   pip 1.4 doesn't fix it (1.3 did)
#
# - httplib2 0.8 permissions are 600 in the package and
#   pip 1.4 doesn't fix it (1.3 did)
#
# - Fedora:
#   - set selinux not enforcing
#   - uninstall firewalld (f20 only)


# If ``TOP_DIR`` is set we're being sourced rather than running stand-alone
# or in a sub-shell
if [[ -z "$TOP_DIR" ]]; then
    set -o errexit
    set -o xtrace

    # Keep track of the current directory
    TOOLS_DIR=$(cd $(dirname "$0") && pwd)
    TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

    # Change dir to top of DevStack
    cd $TOP_DIR

    # Import common functions
    source $TOP_DIR/functions

    FILES=$TOP_DIR/files
fi

# Keystone Port Reservation
# -------------------------
# Reserve and prevent ``KEYSTONE_AUTH_PORT`` and ``KEYSTONE_AUTH_PORT_INT`` from
# being used as ephemeral ports by the system. The default(s) are 35357 and
# 35358 which are in the Linux defined ephemeral port range (in disagreement
# with the IANA ephemeral port range). This is a workaround for bug #1253482
# where Keystone will try and bind to the port and the port will already be
# in use as an ephemeral port by another process. This places an explicit
# exception into the Kernel for the Keystone AUTH ports.
keystone_ports=${KEYSTONE_AUTH_PORT:-35357},${KEYSTONE_AUTH_PORT_INT:-35358}

# Only do the reserved ports when available, on some system (like containers)
# where it's not exposed we are almost pretty sure these ports would be
# exclusive for our DevStack.
if sysctl net.ipv4.ip_local_reserved_ports >/dev/null 2>&1; then
    # Get any currently reserved ports, strip off leading whitespace
    reserved_ports=$(sysctl net.ipv4.ip_local_reserved_ports | awk -F'=' '{print $2;}' | sed 's/^ //')

    if [[ -z "${reserved_ports}" ]]; then
        # If there are no currently reserved ports, reserve the keystone ports
        sudo sysctl -w net.ipv4.ip_local_reserved_ports=${keystone_ports}
    else
        # If there are currently reserved ports, keep those and also reserve the
        # Keystone specific ports. Duplicate reservations are merged into a single
        # reservation (or range) automatically by the kernel.
        sudo sysctl -w net.ipv4.ip_local_reserved_ports=${keystone_ports},${reserved_ports}
    fi
else
    echo_summary "WARNING: unable to reserve keystone ports"
fi


# Python Packages
# ---------------

# get_package_path python-package    # in import notation
function get_package_path {
    local package=$1
    echo $(python -c "import os; import $package; print(os.path.split(os.path.realpath($package.__file__))[0])")
}


# Pre-install affected packages so we can fix the permissions
# These can go away once we are confident that pip 1.4.1+ is available everywhere

# Fix prettytable 0.7.2 permissions
# Don't specify --upgrade so we use the existing package if present
pip_install 'prettytable>=0.7'
PACKAGE_DIR=$(get_package_path prettytable)
# Only fix version 0.7.2
dir=$(echo $PACKAGE_DIR/prettytable-0.7.2*)
if [[ -d $dir ]]; then
    sudo chmod +r $dir/*
fi

# Fix httplib2 0.8 permissions
# Don't specify --upgrade so we use the existing package if present
pip_install httplib2
PACKAGE_DIR=$(get_package_path httplib2)
# Only fix version 0.8
dir=$(echo $PACKAGE_DIR-0.8*)
if [[ -d $dir ]]; then
    sudo chmod +r $dir/*
fi

if is_fedora; then
    # Disable selinux to avoid configuring to allow Apache access
    # to Horizon files (LP#1175444)
    if selinuxenabled; then
        sudo setenforce 0
    fi

    FORCE_FIREWALLD=$(trueorfalse False FORCE_FIREWALLD)
    if [[ $FORCE_FIREWALLD == "False" ]]; then
        # On Fedora 20 firewalld interacts badly with libvirt and
        # slows things down significantly (this issue was fixed in
        # later fedoras).  There was also an additional issue with
        # firewalld hanging after install of libvirt with polkit [1].
        # firewalld also causes problems with neturon+ipv6 [2]
        #
        # Note we do the same as the RDO packages and stop & disable,
        # rather than remove.  This is because other packages might
        # have the dependency [3][4].
        #
        # [1] https://bugzilla.redhat.com/show_bug.cgi?id=1099031
        # [2] https://bugs.launchpad.net/neutron/+bug/1455303
        # [3] https://github.com/redhat-openstack/openstack-puppet-modules/blob/master/firewall/manifests/linux/redhat.pp
        # [4] http://docs.openstack.org/developer/devstack/guides/neutron.html
        if is_package_installed firewalld; then
            sudo systemctl disable firewalld
            # The iptables service files are no longer included by default,
            # at least on a baremetal Fedora 21 Server install.
            install_package iptables-services
            sudo systemctl enable iptables
            sudo systemctl stop firewalld
            sudo systemctl start iptables
        fi
    fi

    reinstall_pip_requests=false

    if [[ "$os_VENDOR" == "Fedora" ]] && [[ "$os_RELEASE" -ge "21" ]]; then
        reinstall_pip_requests=true
    # NOTE: Bash does not handle floating point comparisons. Use bc instead!
    elif [[ "$os_VENDOR" == "Red Hat" ]] && [[ $(echo "if (${os_RELEASE} >= 7.1) 1 else 0" | bc) -eq 1 ]]; then
        reinstall_pip_requests=true
    fi

    if ${reinstall_pip_requests}; then
        # python-requests rpm ships with a vendored version of the python chardet and urllib3
        # (plus in the future, maybe other) packages in the packages/ subdirectory of the
        # main requests/ directory.
        # On Fedora 21, and for some releases (ex: 2.7.0-7.fc21), these directories are symbolic
        # linked to the main python-chardet and python-urllib3 packages.
        # However, on RHEL 7.1 these directories contain the full set of python files
        # for those packages.  These subpackages are of an unknown release.
        #
        # The rpm package is not removed to preserve the dependent packages like cloud-init.
        #
        # If python-requests has been installed, then the pip installer will
        # think everything is fine, but the python code is different than what
        # pip would have been installed.  This is a bad thing.
        #
        # Related issues:
        #   https://bugs.launchpad.net/glance/+bug/1476770
        #   https://bugzilla.redhat.com/show_bug.cgi?id=1253823
        #   https://stackoverflow.com/a/23142059
        #
        #   +++ openstack project create admin --domain=default --or-show -f value -c id
        #   'Response' object has no attribute 'elapsed'
        #
        # The only sensible thing to do is to nuke it from space.

        # NOTE: You possibly cannot uninstall requests because it has been installed with distutils:
        # sudo pip uninstall requests
        # DEPRECATION: Uninstalling a distutils installed project (requests) has been deprecated and
        # will be removed in a future version. This is due to the fact that uninstalling a distutils
        # project will only partially uninstall the project.

        # NOTE: By removing symbolic linked subdirectories, then this will stop other python packages
        # from being affected by the subpackages. Ex:
        # ./requests/packages/urllib3/packages/six.py (containing a broken version 1.2.0) will change ./six.py

        base_path=$(get_package_path requests)/packages
        if [ -L $base_path/chardet -o -L $base_path/urllib3 ]; then
            sudo rm -f $base_path/{chardet,urllib3}
        fi

        pip_install --upgrade --force-reinstall requests
    fi
fi

# The version of pip(1.5.4) supported by python-virtualenv(1.11.4) has
# connection issues under proxy, hence uninstalling python-virtualenv package
# and installing the latest version using pip.
uninstall_package python-virtualenv
pip_install -U virtualenv

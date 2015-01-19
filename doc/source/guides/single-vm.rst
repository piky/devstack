====================
All-In-One Single VM
====================

Use the cloud to build the cloud! Use your cloud to launch new versions
of OpenStack in about 5 minutes. When you break it, start over! The VMs
launched in the cloud will be slow as they are running in QEMU
(emulation), but their primary use is testing OpenStack development and
operation.

Configure nested KVM to make the cloud VMs run faster
-----------------------------------------------------

When using virtualization technologies like KVM, one can take advantage
of "Nested VMX" (i.e. the ability to run KVM on KVM) so that the VMs in
the cloud (Nova guests) can run relatively faster than with plain QEMU
emulation.

The below outlines how to enable nested KVM on Intel hosts and
expose the host CPU features to a VM that can run DevStack.

Check if the nested KVM Kernel parameter is enabled::

    cat /sys/module/kvm_intel/parameters/nested
    N

Temporarily remove the KVM intel Kernel module, enable nested
virtualization to be persistent across reboots and add the Kernel
module back::

    sudo rmmod kvm-intel
    sudo sh -c "echo 'options kvm-intel nested=y' >> /etc/modprobe.d/dist.conf"
    sudo modprobe kvm-intel

Ensure the Nested KVM Kernel module option is enabled on the host::

    cat /sys/module/kvm_intel/parameters/nested
    Y
    modinfo kvm_intel | grep nested
    parm:           nested:bool

Edit the VM's libvirt XML configuration via `virsh` utility ::

    sudo virsh edit devstack-vm

Add the below snippet to expose the host CPU features to the VM::

    <cpu mode='host-passthrough'>
    </cpu>

Start your VM, now it should have KVM capabilities (you can check by
ensuring `/dev/kvm` character device is present).

Before invoking ``stack.sh`` in the VM, ensure to have the below config
attribute in your ``local.conf`` so that the Nova guests take advantage
of the nested KVM virtualization::

    LIBVIRT_TYPE=kvm

Prerequisites Cloud & Image
===========================

Virtual Machine
---------------

DevStack should run in any virtual machine running a supported Linux
release. It will perform best with 2Gb or more of RAM.

OpenStack Deployment & cloud-init
---------------------------------

If the cloud service has an image with ``cloud-init`` pre-installed, use
it. You can get one from `Ubuntu's Daily
Build <http://uec-images.ubuntu.com>`__ site if necessary. This will
enable you to launch VMs with userdata that installs everything at boot
time. The userdata script below will install and run DevStack with a
minimal configuration. The use of ``cloud-init`` is outside the scope of
this document, refer to the ``cloud-init`` docs for more information.

If you are directly using a hypervisor like Xen, kvm or VirtualBox you
can manually kick off the script below as a non-root user in a
bare-bones server installation.

Installation shake and bake
===========================

Launching With Cloud-Init
-------------------------

This cloud config grabs the latest version of DevStack via git, creates
a minimal ``local.conf`` file and kicks off ``stack.sh``. It should be
passed as the user-data file when booting the VM.

::

    #cloud-config

    users:
      - default
      - name: stack
        lock_passwd: False
        sudo: ["ALL=(ALL) NOPASSWD:ALL\nDefaults:stack !requiretty"]
        shell: /bin/bash

    write_files:
      - content: |
            #!/bin/sh
            DEBIAN_FRONTEND=noninteractive sudo apt-get -qqy update || sudo yum update -qy
            DEBIAN_FRONTEND=noninteractive sudo apt-get install -qqy git || sudo yum install -qy git
            sudo chown stack:stack /home/stack
            cd /home/stack
            git clone https://git.openstack.org/openstack-dev/devstack
            cd devstack
            echo '[[local|localrc]]' > local.conf
            echo ADMIN_PASSWORD=password >> local.conf
            echo MYSQL_PASSWORD=password >> local.conf
            echo RABBIT_PASSWORD=password >> local.conf
            echo SERVICE_PASSWORD=password >> local.conf
            echo SERVICE_TOKEN=tokentoken >> local.conf
            ./stack.sh
        path: /home/stack/start.sh
        permissions: 0755

    runcmd:
      - su -l stack ./start.sh

As DevStack will refuse to run as root, this configures ``cloud-init``
to create a non-root user and run the ``start.sh`` script as that user.

Launching By Hand
-----------------

Using a hypervisor directly, launch the VM and either manually perform
the steps in the embedded shell script above or copy it into the VM.

Using OpenStack
---------------

At this point you should be able to access the dashboard. Launch VMs and
if you give them floating IPs access those VMs from other machines on
your network.

One interesting use case is for developers working on a VM on their
laptop. Once ``stack.sh`` has completed once, all of the pre-requisite
packages are installed in the VM and the source trees checked out.
Setting ``OFFLINE=True`` in ``local.conf`` enables ``stack.sh`` to run
multiple times without an Internet connection. DevStack, making hacking
at the lake possible since 2012!

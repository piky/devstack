=====================
First Time User Guide
=====================

This guide will step you through installing devstack for the first time.
Several decisions are made in this first time guide to provide you with the
most common and simplist path to getting your first OpenStack cloud running
with devstack.  See the various guides for more specific devstack examples.


Prerequisites
=============

You will need a computer running a 64 bit version of Windows, Mac OS X or
Linux.  This computer will require at least 4GB of RAM and at least 4GB of
available hard drive space.

Install Steps
=============

By following these install steps you will have a running OpenStack cloud in
20-30 minutes.

#. Download and Install VirtualBox
#. Download Ubuntu 14.04 (Trusty) server image
#. Create an Ubuntu virtual machine
#. Download and configure devstack
#. Install devstack


Download and Install VirtualBox
-------------------------------

Download `VirtualBox`_ for your operating system. This is an open source
virtualization product that will allow you to create virtual machines on your
computer. While the current version is 5.x, older versions will also work if
you are already using this software.

.. _VirtualBox: https://www.virtualbox.org/wiki/Downloads

.. note:: 

   There are different products that can provide virtualization on your
   computer. As a first time user VirtualBox is used as this is the most 
   common product used by developers.


Install VirtualBox on your system, following the default prompts.

To provide for a better experience for installing and accessing devstack the
following VirtualBox configuration setup is recommended.

* Start VirtualBox
* Open Preferences (e.g. File|Preferences)
* Select Network and then Host-only Networks
* Add Network  (accept all defaults)

This additional step will create a network configuration in VirtualBox that is
called **vboxnet0**. This will define a network in the **192.168.56.X** range,
and will configure a DHCP server that will issues IP addresses starting at
192.168.56.101. This will enable you to easily access your devstack cloud 
from your host computer.


Download Ubuntu Server
----------------------

Download the `Ubuntu Server`_ 14.04 (Trusty) server image 
(e.g. ubuntu-14.04.X-**server-amd64**.iso) to your computer. This will be the
base operating system of your virtual machine that will run devstack.

.. _Ubuntu Server: http://releases.ubuntu.com/14.04/

.. note::

   devstack can be installed on different operating systems. As a first time
   user, Ubuntu 14.04 is used as this is the most common platform.

Create Virtual Machine
----------------------

To create a Virtual Machine in VirtualBox select the New icon. This will
prompt your for some initial configuration. Use these recommendations:

* Name and operating System

  * Name: devstack
  * Type: Linux
  * Version: Ubuntu (64-bit)

* Memory Size

  * If you have 8+GB use 4GB. 
  * If you have only 4GB use 2.5GB.

* Hard Disk

  * Use the default settings including 8.0GB, VDI type, dynamically
    allocated, File location and size.


By default your Virtual Machine is read to install however by making the
following network recommendation it will be easier to access your running
Virtual Machine and devstack from your host computer.

* Click Settings
* Select Network
* Enable Adapter 2 and attach to a Host-only Adapter and select vboxnet0
* Ok


You are now read to install the Operating System on the virtual machine
with the following instructions.

* Click Start
* Open the Ubuntu .iso file you just downloaded.
* You will be prompted for a number of options, select the default provided
  and use the following values when prompted.

  * Install Ubuntu Server
  * English (or your choice)
  * United States  (or your location)
  * No for configure the keyboard
  * English (US) for keyboard (or your preference)
  * English (US) for keyboard layout (or your preference)
  * Select **eth0** as your primary network interface
  * Select default ubuntu for hostname
  * Enter **stack** for full username/username
  * Enter **Openstack** for password (or your own preference)
  * Select No to encrypt home directory
  * Select Yes for time zone selected
  * Select Guided - use entire disk for partition method
  * Select highlighted partition
  * Select Yes to partition disks
  * Select Continue for package manager proxy
  * Select No automatic updates
  * Select **OpenSSH Server** in software to install
  * Select Yes to install GRUB boot loader
  * Select Continue when installation complete
  
To verify that the virtual machine is correctly configured after installation
login with the username and password you entered (e.g. stack and OpenStack).

Run the following commands to complete Ubuntu installation needed to install
devstack.

.. highlight:: bash

::

    $ sudo su -
    # Enter your password
    $ umask 266 & echo "stack ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/stack
    $ apt-get update && apt-get upgrade -y
    $ echo "auto eth1
    iface eth1 inet dhcp" >> /etc/network/interfaces
    $ ifup eth1

The virtual machine will be assigned an IP address of **192.168.56.101** which
you can use to connect from your host computer vi ssh.

To verify the Ubuntu virtual machine is ready to use you can connect
via SSH with.

::

    $ ssh stack@192.168.56.101

.. note::

    If this is your first time using VirtualBox and you selected the
    default options for the Host-only adapter the IP address of your first
    virtual machine will be **192.168.56.101**. If you have previously created
    any virtual machines or changed network defaults the IP address may be
    different.

To verify the IP address of your machine you can run:

::

    $ ifconfig eth1


Download and configure devstack
-------------------------------

After connecting to the virtual machine as the **stack** user, the 
following commands will prepare your devstack installation:

::

   $ sudo apt-get install -y git-core
   # NOTE: You will not be prompted for a password
   #       This is important for the following installation steps
   $ git clone https://git.openstack.org/openstack-dev/devstack
   $ cd devstack
   # Use the sample default configuratio file
   $ cp samples/local.conf .
   $ echo "HOST_IP=192.168.56.101" >> local.conf

.. note::

  If your machine has different IP address you should specify this in
  the last line of these commands.

Install devstack
----------------

::

   $ ./stack.sh 

When completed you will see the following:

::


    This is your host IP address: 192.168.56.101
    This is your host IPv6 address: ::1
    Horizon is now available at http://192.168.56.101/dashboard
    Keystone is serving at http://192.168.56.101:5000/
    The default users are: admin and demo
    The password: nomoresecrete


While the installation of devstack is happening, you should read
:doc:`../configuration` section, and look at the 
**devstack/samples/local.conf** sample configuration file being used.


Using devstack
--------------

You now have a running OpenStack cloud. There are two easy ways to access
the services.

* Use the Horizon dashboard with the URL, user and password provided.
* Use the OpenStack client, for example:

::

   $ source accrc/admin/admin
   $ openstack image list


Troubleshooting
---------------

If you are running devstack from a network that has firewall rules that limit
external access, the retrieval of the OpenStack git repositories may fail
because this by default this uses the git protocol (Port 9418). You can change
the configuration to use a https protocol (Port 443) which is allowed by most
networks by:

:: 

  $ cd devstack
  $ echo "GIT_BASE=https://github.com" >> local.conf
  $ ./stack.sh


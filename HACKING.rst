Contributing to DevStack
========================

General
-------

DevStack is written in shell script, specifically ``bash``, although generally
following POSIX usage is a good thing where possible.  We have chosen to
stay in shell because it best illustrates the configuration steps that this
implementation takes on setting up and interacting with OpenStack components.

The primary script in DevStack is ``stack.sh``, which performs the bulk of the
work for DevStack's use cases.  A number of additional scripts can be found
in the tools directory that may be useful in setting up special-case use
of DevStack.


Scripts
-------

DevStack scripts should generally begin by calling ``env(1)`` in the shebang line::

    #!/usr/bin/env bash

Many scripts will utilize shared functions from the functions file.  There are
also rc files (``stackrc`` and ``openrc``) that are often included to set the primary
configuration of the user environment::

    # Use openrc + stackrc + localrc for settings
    pushd $(cd $(dirname "$0")/.. && pwd) >/dev/null

    # Import common functions
    source ./functions

    # Import configuration
    source ./openrc
    popd >/dev/null

``stack.sh`` is a rather large monolithic script that basically flows through from
beginning to end.  There is talk of segmenting it to put the OpenStack projects
into their own sub-scripts to better document the projects as a unit rather than
have it scattered throughout stack.sh.  Someday.


Documentation
-------------

The original DevStack repo (https://github.com/cloudbuilders/devstack) contains
the gh-pages branch that supports the http://devstack.org site.  Other than the DevStack
scripts themselves, this is the primary documentation.

All of the scripts
are processed with shocco to render them with the comments as text describing
the script below.  For this reason we tend to be a little verbose in the
comments _ABOVE_ the code they pertain to.

Scripts like stack.sh also have RST headers embedded in the comments to break
them into logical sections.


Exercises
---------

The scripts in the exercises directory are meant to 1) perform basic operational
checks on certain aspects of OpenStack; and b) document the use of the
OpenStack command-line clients.

When writing an exercise please follow the structure of the existing exercise
scripts; in addition to the conventions mentioned above:

* Begin and end with a banner that stands out in a sea of script logs to aid
  in debugging failures, particularly in automated testing situations.  If the
  end banner is not displayed, the script ended prematurely and can be assumed
  to have failed.

  ::

    echo "**************************************************"
    echo "Begin DevStack Exercise: $0"
    echo "**************************************************"
    ...
    set +o xtrace
    echo "**************************************************"
    echo "End DevStack Exercise: $0"
    echo "**************************************************"

* The scripts will generally have the shell ``xtrace`` attribute set to display
  the actual commands being executed, and the errexit attribute set to exit
  the script on non-zero exit codes::

    # This script exits on an error so that errors don't compound and you see
    # only the first error that occured.
    set -o errexit

    # Print the commands being run so that we can see the command that triggers
    # an error.  It is also useful for following allowing as the install occurs.
    set -o xtrace

* Helper functions are in ``functions`` that will check for non-zero exit codes and
  unset environment variables and print a message and exit the script.  These 
  should be called after most client commands that are not otherwise checked to
  short-circuit long timeouts (instance boot failure, for example)::

    swift post $CONTAINER
    die_if_error "Failure creating container $CONTAINER"

* The exercise scripts should only use the client binaries to interact with OpenStack.

* If certain configuration needs to be present for the test to operate, it should be
  staged in ``stack.sh``, or called from ``stack.sh`` (see ``keystone_data.sh`` for
  an example of this).

* The ``OS_*`` environment variables should be the only ones used for all authentication
  to OpenStack clients.

* The script should clean up after itself if successful.  If it is not successful,
  it is assumed that state will be left behind; for developers this allows a chance
  to look around and attempt to debug the problem.  Ideally, the exercise scripts
  will clean up possible artifacts left over from previous runs during the next
  execution.  Of then though, a reboot of the virtual machine will be the cleanest
  option.


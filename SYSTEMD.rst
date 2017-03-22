===========================
 Using Systemd in DevStack
===========================

.. note::

   This is an in progress document as we work out the way forward here
   with DevStack and systemd.

DevStack can be run with all the services as systemd unit
files. Systemd is now the default init system for nearly every Llinux
distro, and systemd encodes and solves many of the problems related to
poorly running processes.

Why this instead of screen?
===========================

The screen model for DevStack was invented when the number of services
that a devstack user was going to run was typically < 10. This made
screen hot keys to jump around very easy. However, the landscape has
changed (not all services are stoppable in screen as some are under
apache, there are typically at least 20 items)

There is also a common developer workflow of changing code in more
than one service, and needing to restart a bunch of services for that
to take effect.

To enable this add the following to your local.conf::

  USE_SYSTEMD=True



Unit Structure
==============

.. note::

   Originally we actually wanted to do this as user units, however
   there are issues with running this under non interactive
   shells. For now, we'll be running as system units. Some user unit
   code is left in place in case we can switch back later.

All devstack user units are created as a part of the devstack slice
given the name ``devstack@$servicename.service``. This lets us do
certain operations at the slice level.

Manipulating Units
==================

Assuming the unit ``n-cpu`` to make the examples more clear.

Enable a unit (allows it to be started)::

  sudo systemctl enable devstack@n-cpu.service

Disable a unit::

  sudo systemctl disable devstack@n-cpu.service

Start a unit::

  sudo systemctl start devstack@n-cpu.service

Stop a unit::

  sudo systemctl stop devstack@n-cpu.service

Restart a unit::

  sudo systemctl restart devstack@n-cpu.service

See status of a unit::

  sudo systemctl status devstack@n-cpu.service


Querying Logs
=============

One of the other major things that comes with systemd is journald, a
consolidated way to access logs (including querying through structured
metadata). This is accessed by the user via ``journalctl`` command.


Logs can be accessed through ``journalctl``. journalctl has powerful
query facilities. We'll start with some common options.

Follow logs for a specific service::

  journalctl -f --unit devstack@n-cpu.service

Following logs for multiple services simultaneously::

  journalctl -f --unit devstack@n-cpu.service --user-unit
  devstack@n-cond.service

Use higher precision timestamps::

  journalctl -f -o short-precise --unit devstack@n-cpu.service


Known Issues
============

The ``[Service]`` - ``Group=`` parameter doesn't seem to work with user
units, even though the documentation says that it should. This means
that we will need to do an explicit ``/usr/bin/sg``. This has the
downside of making the SYSLOG_IDENTIFIER be ``sg``. We can explicitly
set that with ``SyslogIdentifier=``, but it's really unfortunate that
we're going to need this work around.

Future Work
===========

oslo.log journald
-----------------

Journald has an extremely rich mechanism for direct logging including
structured metadata. We should enhance oslo.log to take advantage of
that. It would let us do things like::

  journalctl REQUEST_ID=......

  journalctl INSTANCE_ID=......

And get all lines related to the request id or instance id.

.. note::

   The ``systemd`` python package appears to only be python3 in recent
   releases, so there is going to need to be some conditional nature
   of using this.

sub targets/slices
------------------

We might want to create per project slices so that it's easy to
follow, restart all services of a single project (like swift) without
impacting other services.

log colorizing
--------------

We lose log colorization through this process. We might want to build
a custom colorizer that we could run journalctl output through
optionally for people.

user units
----------

It would be great if we could do services as user units, so that there
is a clear separation of code being run as not root, to ensure running
as root never accidentally gets baked in as an assumption to
services. However, user units interact poorly with devstack-gate and
the way that commands are run as users with ansible and su.

Maybe someday we can figure that out.

References
==========

- Arch Linux Wiki - https://wiki.archlinux.org/index.php/Systemd/User
- Python interface to journald -
  https://www.freedesktop.org/software/systemd/python-systemd/journal.html
- Systemd documentation on service files -
  https://www.freedesktop.org/software/systemd/man/systemd.service.html
- Systemd documentation on exec (can be used to impact service runs) -
  https://www.freedesktop.org/software/systemd/man/systemd.exec.html

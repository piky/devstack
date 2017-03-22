===========================
 Using Systemd in DevStack
===========================

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

User Units
==========

Systemd supports the concept of user units, so that any user on the
system can create unit files for services just like at the root
level. The Arch Linux Wiki provides a good overview of what can be
done with them - https://wiki.archlinux.org/index.php/Systemd/User

Unit Structure
==============

All devstack user units are created as a part of the devstack slice
given the name ``devstack@$servicename.service``. This lets us do
certain operations at the slice level.

Manipulating Units
==================

Assuming the unit ``n-cpu`` to make the examples more clear.

Enable a unit (allows it to be started)::

  systemctl --user enable devstack@n-cpu.service

Disable a unit::

  systemctl --user disable devstack@n-cpu.service

Start a unit::

  systemctl --user start devstack@n-cpu.service

Stop a unit::

  systemctl --user stop devstack@n-cpu.service

Restart a unit::

  systemctl --user restart devstack@n-cpu.service

See status of a unit::

  systemctl --user status devstack@n-cpu.service


Querying Logs
=============

One of the other major things that comes with systemd is journald, a
consolidated way to access logs (including querying through structured
metadata). This is accessed by the user via ``journalctl`` command.


Logs can be accessed through ``journalctl``. journalctl has powerful
query facilities. We'll start with some common options.

Follow logs for a specific service::

  journalctl -f --user-unit devstack@n-cpu.service

Following logs for multiple services simultaneously::

  journalctl -f --user-unit devstack@n-cpu.service --user-unit
  devstack@n-cond.service

Use higher precision timestamps::

  journalctl -f -o short-precise --user-unit devstack@n-cpu.service


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

Journald has an extremely rich mechanism for direct logging including
structured metadata. We should enhance oslo.log to take advantage of
that. It would let us do things like::

  journalctl REQUEST_ID=......

  journalctl INSTANCE_ID=......

And get all lines related to the request id or instance id.


We might want to create per project slices so that it's easy to
follow, restart all services of a single project (like swift) without
impacting other services.


We lose log colorization through this process. We might want to build
a custom colorizer that we could run journalctl output through
optionally for people.


References
==========

- Arch Linux Wiki - https://wiki.archlinux.org/index.php/Systemd/User
- Python interface to journald -
  https://www.freedesktop.org/software/systemd/python-systemd/journal.html
- Systemd documentation on service files -
  https://www.freedesktop.org/software/systemd/man/systemd.service.html
- Systemd documentation on exec (can be used to impact service runs) -
  https://www.freedesktop.org/software/systemd/man/systemd.exec.html

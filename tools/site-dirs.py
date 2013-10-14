#!/usr/bin/python

import site
import os

# Try to figure out the site-packages directory using the Python 2.7+
# getsitepackages() method. If that fails, fall back to the distutils
# method that is also expected to work on RHEL 6.x (Python 2.6).
try:
    print os.linesep.join(site.getsitepackages())
except AttributeError:
    from distutils.sysconfig import get_python_lib
    print get_python_lib()

#!/usr/bin/env python

import os
import sys

import requests

PROJECTS = ['horizon',
            'keystone',
            'glance',
            'nova',
            'cinder',
            'swift',
            'heat',
            'neutron',
            'requirements',
        ]


def check_project(project, release):
    r = requests.get('http://github.com/openstack/%s/tree/stable/%s' % (
        project, release))
    if r.status_code == 404:
        return False
    elif r.status_code == 200:
        return True
    else:
        print('Got unexpected result %i, so I dunno about %s %s' % (
            resp.status_code, project, release))
        return None


def check_projects(release):
    results = {project: check_project(project, release)
               for project in PROJECTS}
    if not all(results.values()):
        print('Unable to branch yet. Some projects do not have '
              'stable branches for %s:' % release)
        print(','.join(project for project, status in results.items()
                       if not status))
        return False
    else:
        print('All projects have stable/%s branches. Good to go.' % release)
        return True


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Run me with a release name, like mitaka')
        sys.exit(1)
    sys.exit(0 if check_projects(sys.argv[1]) else 1)

#!/usr/bin/env python

import os
import sys

import requests


def find_projects():
    mydir = os.path.dirname(os.path.realpath(__file__))
    projects = os.path.join(mydir, '..', 'projects')
    if os.path.exists(projects):
        return projects
    projects = os.path.join(os.path.realpath(os.curdir()), 'projects')
    if os.path.exists(projects):
        return projects
    return None


def get_projects():
    projects_file = find_projects()
    if not projects_file:
        return None
    lines = open(projects_file).readlines()
    return [x.strip() for x in lines]


def check_project(project, release):
    if project.endswith('-legacy'):
        # Neutron is currently called neutron-legacy in the tree
        project = project.split('-')[0]

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
    projects = get_projects()
    if not projects:
        print('Unable to get list of projects')
        return False
    results = {project: check_project(project, release)
               for project in projects}
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

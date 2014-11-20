#!/usr/bin/env python

import re
import yaml


def find_libs():
    libs = []
    with open("stackrc") as f:
        for line in f:
            m = re.search('GITREPO\[\"([^\]]+)\"\]', line)
            if m:
                libs.append(m.group(1))
    return libs


def find_templates():
    config = yaml.load(open("../project-config/zuul/layout.yaml"))
    project_templates = {}

    for project in config['projects']:
        try:
            templates = [x['name'] for x in project['template']]
            #print project['name']
            #print templates
            project_templates[project['name'].split('/')[-1]] = templates
        except KeyError:
            pass
    return project_templates


libs = find_libs()
templates = find_templates()

for lib in libs:
    if 'lib-forward-testing' in templates[lib]:
        print "%s properly tested" % lib
    else:
        print "%s missing test job lib-forward-testing" % lib

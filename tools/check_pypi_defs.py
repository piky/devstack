#!/usr/bin/env python
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import argparse
import re
import sys
import yaml


def get_options():
    parser = argparse.ArgumentParser(
        description='Sanity check stackrc vs. zuul layout.yaml')
    parser.add_argument('-s', '--stackrc',
                        help='Location of stackrc file',
                        required=True,
                        default=None)
    parser.add_argument('-z', '--zuullayout',
                        help='Location of zuul layout file',
                        required=True,
                        default=None)
    parser.add_argument('-v', '--verbose', action='store_true',
                        default=False)
    return parser.parse_args()


def find_libs(stackrc):
    libs = []
    with open(stackrc) as f:
        for line in f:
            m = re.search('GITREPO\[\"([^\]]+)\"\]', line)
            if m:
                libs.append(m.group(1))
    return libs


def find_templates(layout):
    with open(layout) as f:
        config = yaml.load(f)
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


def main():
    opts = get_options()
    libs = find_libs(opts.stackrc)
    templates = find_templates(opts.zuullayout)

    for lib in libs:
        if 'lib-forward-testing' in templates[lib]:
            print "%s properly tested" % lib
        else:
            print "%s missing test job lib-forward-testing" % lib
            sys.exit(1)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(1)

#!/usr/bin/env python
#
# Copyright 2014 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# This is an output filter to filter and timestamp the logs from grenade and
# devstack. Largely our awk filters got beyond the complexity level which were
# sustainable, so this provides us much more control in a single place.
#
# The overhead of running python should be less than execing `date` a million
# times during a run.

import argparse
import datetime
import re
import sys


def get_options():
    parser = argparse.ArgumentParser(
        description='Filter output by devstack and friends')
    parser.add_argument('-o', '--outfile',
                        help='Output file for content',
                        default=None)
    parser.add_argument('-v', '--verbose', action='store_true',
                        default=False)
    return parser.parse_args()


def skip_line(line):
    """Should we skip this line."""
    return re.search('(set \+o|xtrace)', line)


def main():
    opts = get_options()
    outfile = None
    if opts.outfile:
        outfile = open(opts.outfile, 'a', 0)

    # otherwise fileinput reprocess args as files
    sys.argv = []
    while True:
        line = sys.stdin.readline()
        # put skip lines here
        if skip_line(line):
            continue

        now = datetime.datetime.utcnow()

        newline = ("%s.%s | %s" % (
            now.strftime("%Y-%m-%d %H:%M:%S"),
            now.strftime("%f")[:3],
            line))
        if opts.verbose:
            sys.stdout.write(newline)
            sys.stdout.flush()
        if outfile:
            outfile.write(newline)
            outfile.flush()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(1)

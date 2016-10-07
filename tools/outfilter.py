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

# This is an output filter to filter and timestamp the logs from Grenade and
# DevStack. Largely our awk filters got beyond the complexity level which were
# sustainable, so this provides us much more control in a single place.
#
# The overhead of running python should be less than execing `date` a million
# times during a run.

import argparse
import datetime
import re
import sys

IGNORE_LINES = re.compile('(set \+o|xtrace)')
HAS_DATE = re.compile('^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d{3} \|')


def get_options():
    parser = argparse.ArgumentParser(
        description='Filter output by DevStack and friends')
    parser.add_argument('-o', '--outfile',
                        help='Output file for content',
                        default=None)
    parser.add_argument('-v', '--verbose', action='store_true',
                        default=False)
    return parser.parse_args()


def skip_line(line):
    """Should we skip this line."""
    return IGNORE_LINES.search(line) is not None


def main():
    opts = get_options()
    outfile = None
    if opts.outfile:
        outfile = open(opts.outfile, 'a', 0)

    def output_line(outline):
        # This prevents us from nesting date lines, because
        # we'd like to pull this in directly in Grenade and not double
        # up on DevStack lines
        if HAS_DATE.search(outline) is None:
            now = datetime.datetime.utcnow()
            outline = ("%s | %s" % (
                now.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3],
                outline))

        if opts.verbose:
            sys.stdout.write(outline)
            sys.stdout.flush()
        if outfile:
            outfile.write(outline)
            outfile.flush()


    # provide warning to users that not all content is in the logfile
    output_line("This logfile skips printing all lines matching the regular "
                "expression: '{}'\n".format(IGNORE_LINES.pattern))
    # Otherwise fileinput reprocess args as files
    sys.argv = []
    skipped_lines = 0
    total_lines = 0
    while True:
        line = sys.stdin.readline()
        if not line:
            output_line(
                "{} out of {} lines ({:.2%}) matched the regular expression "
                "'{}' and were not printed\n".format(
                    skipped_lines, total_lines,
                    skipped_lines * 1.0 / total_lines, IGNORE_LINES.pattern))
            return 0

        total_lines += 1
        # put skip lines here
        if skip_line(line):
            skipped_lines += 1
            continue

        output_line(line)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(1)

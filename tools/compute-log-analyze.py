#!/usr/bin/python

import argparse
import re
import sys

from dateutil.parser import parse

RE_DATE = '\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\.\d\d\d'
RE_INSTANCE = (r'(?P<date>%s) INFO nova.compute.manager .*? '
               'Took \d+\.\d+ seconds to build instance' % RE_DATE)


def get_args():
    parser = argparse.ArgumentParser(
        description='Count number of servers built')
    parser.add_argument('files', metavar='file', nargs='+',
                        help='process this file')
    return parser.parse_args()


def count_instance_builds(files):
    build_times = {}

    for fname in files:
        with open(fname) as f:
            build_times[fname] = []
            for line in f:
                m = re.search(RE_INSTANCE, line)

                if not m:
                    continue

                built_at = parse(m.group('date'))
                build_times[fname].append(built_at)

    return build_times


def report_build_times(build_times):
    errors = 0

    for fname, build_times in build_times.items():
        if not len(build_times) > 1:
            print("ERROR: no instance builds found in log %s" % fname)
            errors += 1
        print "%s - %s instance builds" % (fname, len(build_times))

    return errors


def main():
    args = get_args()
    times = count_instance_builds(args.files)
    sys.exit(report_build_times(times))


if __name__ == "__main__":
    main()

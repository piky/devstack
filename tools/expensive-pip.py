#!/usr/bin/env python

import argparse
import re

from dateutil.parser import parse

RE_DATE = '\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\.\d\d\d'

RE_START = r'(?P<date>%s)\s+\|\s+Running setup.py ' \
           'bdist_wheel for (?P<pkg>\S+)' % RE_DATE
RE_END = r'(?P<date>%s)\s+\|\s+Stored in directory:' % RE_DATE


parser = argparse.ArgumentParser(description='Count up time to build pips')
parser.add_argument('files', metavar='file', nargs='+',
                   help='process this file')
args = parser.parse_args()

for fname in args.files:
    with open(fname) as f:
        for line in f:
            m = re.search(RE_START, line)

            if not m:
                continue

            start = parse(m.group('date'))
            name = m.group('pkg')
            # look to see if the next line is a thing, if so
            # compute how long this took.
            endline = next(f)
            m2 = re.search(RE_END, endline)

            if not m2:
                continue

            end = parse(m2.group('date'))
            total = end - start
            print "%s %s" % (total, name)

#!/usr/bin/env python

import fileinput
import re
import sys

ERRORS = 0


def print_error(error, line):
    global ERRORS
    ERRORS = ERRORS + 1
    print "%s: %s" % (fileinput.filename(), fileinput.filelineno())
    print "%s: '%s'" % (error, line.rstrip('\n'))


def check_no_trailing_whitespace(line):
    if re.search('[ \t]+$', line):
        print_error('E001: Trailing Whitespace', line)


def check_indents(line):
    m = re.search('^(?P<indent>[ \t]+)', line)
    if m:
        if re.search('\t', m.group('indent')):
            print_error('E002: Tab indents', line)
        if (len(m.group('indent')) % 4) != 0:
            print_error('E003: Indent not multiple of 4', line)


for line in fileinput.input():
    check_no_trailing_whitespace(line)
    check_indents(line)


if ERRORS > 0:
    print "%d bash8 error(s) found" % ERRORS
    sys.exit(1)

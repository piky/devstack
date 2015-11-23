#!/usr/bin/env python

__author__ = 'wznoinsk'

import argparse
from operator import itemgetter
import datetime
import os
import re
import sys
import time

working_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
run_modes = ["line"]


def parse_options():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dir', help="Location of devstack's log file(s)",
                        required=True, dest="indir")
    return parser.parse_args()


def open_infile(indir="."):
    infile = "%s/xstack.sh.log" % indir
    return open(infile, 'r')


def prepopulate_list(s):
    l = []
    for i in range(0, s):
        l.append(0)

    return l


def calc_delta(line_prev, line):
    fields = line_prev.split("|")
    dt = datetime.datetime.strptime(fields[0].strip(), "%Y-%m-%d %H:%M:%S.%f")
    msecs_prev = float(time.mktime(dt.timetuple())) + (float(dt.microsecond)
                                                       / 1000000)

    fields = line.split("|")
    dt = datetime.datetime.strptime(fields[0].strip(), "%Y-%m-%d %H:%M:%S.%f")
    msecs = float(time.mktime(dt.timetuple())) + (float(dt.microsecond)
                                                  / 1000000)
    if msecs_prev > 0:
        delta = msecs - msecs_prev
    else:
        delta = 0

    return delta


def merge_deltas(deltas):
    deltas_out = {}
    for key in deltas.keys():
        for key2, value2 in deltas[key].items():
            deltas_out[key2] = [value2]

    return deltas_out


def process_lines(lines):
    line_deltas_sorted = {}

    for mode in run_modes:
        deltas = {}
        line_no = 0

        for line in lines:
            if line_no > 0:
                if mode == 'line':
                    deltas[line_no - 1] = calc_delta(lines[line_no - 1], line)

            line_no += 1

        if mode == 'line':
            line_deltas_sorted = sorted(deltas.items(),
                                        key=itemgetter(1), reverse=True)

    return line_deltas_sorted


def display_top(deltas_sorted, lines):
    c = -1
    for d in deltas_sorted:
        c += 1
        if c < 10:
            try:
                line_no = d[0]
                print "%s sec | %s" % (
                    deltas_sorted[c][1], lines[line_no].strip())
            except:
                pass


def main():
    cmdline_args = parse_options()
    infile_fh = open_infile(cmdline_args.indir)
    lines = infile_fh.readlines()
    line_deltas = process_lines(lines)

    print "top 10 longest running commands"
    display_top(line_deltas, lines)

    infile_fh.close()


if __name__ == '__main__':
    sys.exit(main())

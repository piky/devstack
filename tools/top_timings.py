#!/usr/bin/env python
#
# Copyright 2015 Intel Corporation
#
# All Rights Reserved.
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

import argparse
from operator import itemgetter
import datetime
import sys
import time


def parse_options():
    parser = argparse.ArgumentParser()
    parser.add_argument('-f', '--file', help="Filepath to devstack's log file"
                        " (default: ./xstack.sh.log)", required=False,
                        dest="infile", default="./xstack.sh.log")
    parser.add_argument('-l', '--limit', help="Number of top entries displayed"
                        " (default: 10)", required=False, dest="toplimit",
                        default=10)
    parser.add_argument('-m', '--modes', help="Modes to run calculation "
                        "(default: line) ", choices=["line"], required=False,
                        dest="runmodes", default="line")
    return parser.parse_args()


def open_infile(infile="./xstack.sh.log"):
    return open(infile, 'r')


def prepopulate_list(s):
    return [0] * s


def extract_msecs(line):
    try:
        field, _ = line.split("|", 1)
        dt = datetime.datetime.strptime(field.strip(), "%Y-%m-%d %H:%M:%S.%f")
        return float(time.mktime(dt.timetuple())) + \
            (float(dt.microsecond) / 1000000)
    except:
        return False


def calc_delta(line_prev, line):
    msecs_prev = extract_msecs(line_prev)
    msecs = extract_msecs(line)
    delta = 0

    if msecs:
        if msecs_prev > 0:
            delta = msecs - msecs_prev
        else:
            delta = 0

    return delta


def process_lines(lines, runmodes):
    line_deltas_sorted = {}

    for mode in runmodes:
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


def display_top(line_deltas, lines, toplimit):
    print "top %s longest running commands" % toplimit

    c = -1
    fmt2 = 6
    fmt1 = str(int(line_deltas[0][1])).__len__() + 4 + 6 + fmt2

    while c < toplimit - 1:
        c += 1
        d = line_deltas[c]
        try:
            line_no = d[0]
            print '{num:{fmt1}.{fmt2}f} sec | ' \
                  '{line}'.format(fmt1=fmt1, fmt2=fmt2, num=line_deltas[c][1],
                                  line=lines[line_no].strip())
        except:
            pass


def main():
    cmdline_args = parse_options()
    # TODO(wznoinsk): add support for input from stdin
    lines = open_infile(cmdline_args.infile).readlines()
    line_deltas = process_lines(lines, [cmdline_args.runmodes])

    display_top(line_deltas, lines, int(cmdline_args.toplimit))


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python
#
#

import datetime
import re
import sys

min_delta = datetime.timedelta(0, 0, 0, 20)
print min_delta


def to_datetime(day, time):
    time, msec = time.split('.')
    dt = datetime.datetime.strptime(day + " " + time, "%Y-%m-%d %H:%M:%S")
    dt = dt.replace(microsecond=(int(msec) * 1000))
    return dt


with open(sys.argv[1]) as f:
    start = None
    lastdepth = None
    lastcmd = ""
    lastdt = ""
    times = []
    for line in f.readlines():
        try:
            day, time, pipe, depth, cmd = line.split(None, 4)
            dt = to_datetime(day, time)
            if start and (lastdepth == '+' or depth != lastdepth):
                delta = dt - start
                if delta > min_delta:
                    print line
                    print delta
                    times.append((delta, lastcmd))
                    start = None
            if re.search("^openstack ", cmd):
                print line
                lastdepth = depth
                start = dt
                lastdt = "%s %s" % (day, time)
                lastcmd = cmd
        except:
            pass

    print "Total time in OSC execution: %s" % \
        reduce(lambda q, p: p + q, [x[0] for x in times])

    max_cmd = None
    max_time = datetime.timedelta()
    for x in times:
        time = x[0]
        cmd = x[1]
        if max(max_time, time) == time:
            max_time = time
            max_cmd = cmd

    min_cmd = None
    min_time = datetime.timedelta(1000)
    for x in times:
        time = x[0]
        cmd = x[1]
        if min(min_time, time) == time:
            min_time = time
            min_cmd = cmd

    print "Max time %s for cmd: %s" % (max_time, max_cmd)
    print "Min time %s for cmd: %s" % (min_time, min_cmd)

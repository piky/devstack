#!/usr/bin/env python

# This tool lists processes that lock memory pages from swapping to disk.

import datetime
import re
import subprocess
import time

import psutil


SUMMARY_REGEX = re.compile(r".*\s+(?P<locked>[\d]+)\s+KB")


def main():
    while True:
        start = datetime.datetime.utcnow()
        try:
            msg = _get_report()
        except Exception as e:
            msg = "Exception occurred: %s" % str(e)

        # append timestamp
        print "%(time)s %(data)s" % {
            'time': start.strftime("%Y-%m-%d-%H:%M:%S"),
            'data': msg,
        }

        # report generation is not particularly light, so wait before next
        # iteration, but keep timing between iterations independent of sysload
        iter_time = (datetime.datetime.utcnow() - start).total_seconds()
        time_to_sleep = 30 - iter_time
        # guard against long reporting time, and give at least 10 secs between reports
        time.sleep(max(time_to_sleep, 10))


def _get_report():
    mlock_users = []
    for proc in psutil.process_iter():
        pid = proc.pid
        # sadly psutil does not expose locked pages info, that's why we
        # call to pmap and parse the output here
        out = subprocess.check_output(['pmap', '-XX', str(pid)])
        last_line = out.splitlines()[-1]

        # some processes don't provide a memory map, for example those
        # running as kernel services, so we need to skip those that don't
        # match
        result = SUMMARY_REGEX.match(last_line)
        if result:
            locked = int(result.group('locked'))
            if locked:
                mlock_users.append({'name': proc.name(),
                                    'pid': pid,
                                    'locked': locked})

    # produce a single line log message with per process mlock stats
    if mlock_users:
        return "; ".join(
            "[%(name)s (pid:%(pid)s)]=%(locked)dKB" % args
            # log heavy users first
            for args in sorted(mlock_users, key=lambda d: d['locked'])
        )
    else:
        return "no locked memory"


if __name__ == "__main__":
    main()

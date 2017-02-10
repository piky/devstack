#!/usr/bin/env python

# This tool lists processes that lock memory pages from swapping to disk.

import datetime
import re
import subprocess
import time

import psutil


SUMMARY_REGEX = re.compile(".*\s+(?P<locked>[^\s]+)\s+KB")


def main():
    while True:
        start = datetime.datetime.utcnow()
        mlock_users = []
        for proc in psutil.process_iter():
            pid = proc.pid
            # sadly psutil does not expose locked pages info, that's why we
            # call to pmap and parse the output here
            out = subprocess.check_output(['pmap', '-XX', str(pid)])
            last_line = out.split('\n')[-2]

            # some processes don't provide a memory map, for example those
            # running as kernel services, so we need to skip those that don't
            # match
            result = re.match(SUMMARY_REGEX, last_line)
            if result:
                locked = int(result.group('locked'))
                if locked:
                    mlock_users.append({'name': proc.name(),
                                        'pid': pid,
                                        'locked': locked})

        # produce a single line log message with per process mlock stats
        if mlock_users:
            data = "; ".join(
                "[%(name)s (pid:%(pid)s)]=%(locked)dKB" % args
                # log heavy users first
                for args in sorted(mlock_users, key=lambda d: d['locked'])
            )
        else:
            data = "no locked memory"

        # append timestamp
        print "%(time)s %(data)s" % {
            'time': start.strftime("%Y-%m-%d-%H:%M:%S"),
            'data': data
        }

        # the script is not particularly light, so wait before next iteration,
        # but keep timing between iterations independent of system load
        iter_time = (datetime.datetime.utcnow() - start).total_seconds()
        time_to_sleep = 30 - iter_time
        time.sleep(time_to_sleep)


if __name__ == "__main__":
    main()

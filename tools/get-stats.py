#!/usr/bin/python3

import glob
import json
import os
import psutil
import re
import subprocess
import sys
import MySQLdb

# https://www.elastic.co/blog/found-crash-elasticsearch#mapping-explosion


def tryint(value):
    try:
        return int(value)
    except ValueError:
        return value


def get_service_stats(service):
    stats = {'MemoryCurrent': 0}
    output = subprocess.check_output(['/usr/bin/systemctl', 'show', service] +
                                     ['-p%s' % stat for stat in stats])
    for line in output.decode().split('\n'):
        if not line:
            continue
        stat, val = line.split('=')
        stats[stat] = int(val)

    return stats


def get_services_stats():
    services = [os.path.basename(s) for s in
                glob.glob('/etc/systemd/system/devstack@*.service')]
    return [dict(service=service, **get_service_stats(service))
            for service in services]


def get_process_stats(proc):
    cmdline = proc.cmdline()
    if 'python' in cmdline[0]:
        cmdline = cmdline[1:]
    return {'cmd': cmdline[0],
            'args': ' '.join(cmdline[1:]),
            'rss': proc.memory_info().rss}


def get_processes_stats(*matches):
    procs = psutil.process_iter()
    return [
        get_process_stats(proc)
        for proc in procs
        for match in matches
        if re.search(match, ' '.join(proc.cmdline()))]


def get_db_stats(user, passwd):
    db = MySQLdb.connect('localhost', user, passwd,
                         'performance_schema')
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute('SELECT COUNT(*) AS queries,current_schema AS db FROM '
                'events_statements_history_long GROUP BY current_schema')
    dbs = []
    for row in cur:
        dbs.append({k: tryint(v) for k, v in row.items()})
    return dbs


def get_http_stats(logfile):
    stats = {}
    for line in open(logfile).readlines():
        m = re.search('"([A-Z]+) ([^" ]+)( HTTP/1.1)?" ([0-9]{3}) ([0-9]+)',
                      line)
        if m:
            method = m.group(1)
            path = m.group(2)
            status = m.group(4)
            size = m.group(5)

            try:
                _, service, rest = path.split('/', 2)
            except ValueError:
                # Root calls like "GET /identity"
                _, service = path.split('/', 1)
                rest = ''
            stats.setdefault(service, {})
            stats[service].setdefault(method, 0)
            stats[service][method] += 1

    # Flatten this for ES
    return [{'service': service, **vals}
            for service, vals in stats.items()]


if __name__ == '__main__':
    db_pass = sys.argv[1]
    apache_log = sys.argv[2]
    print(json.dumps({
        'services': get_services_stats(),
        'db': get_db_stats('root', db_pass),
        'api': get_http_stats(apache_log),
        'processes': get_processes_stats('privsep'),
    }, indent=2))

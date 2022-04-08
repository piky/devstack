#!/usr/bin/python3

import glob
import json
import os
import subprocess
import MySQLdb


# [mysqld]
# performance-schema-consumer-events-statements-history-long=TRUE

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
    return {service: get_service_stats(service)
            for service in services}


def get_db_stats():
    db = MySQLdb.connect('localhost', 'root', 'password',
                         'performance_schema')
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute('SELECT COUNT(*) AS queries,current_schema AS db FROM '
                'events_statements_history_long GROUP BY current_schema')
    stats = {}
    for row in cur:
        stats[row['db']] = {k: int(v) for k, v in row.items()
                            if k != 'db'}
    return stats


if __name__ == '__main__':
    print(json.dumps({
        'services': get_services_stats(),
        'db': get_db_stats(),
    }, indent=2))

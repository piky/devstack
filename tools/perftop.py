#!/usr/bin/python3

# This takes a performance.json (or URL to one) and prints some
# information about it.

import argparse
import json
import requests
import sys

import prettytable


def do_mem(data, top):
    pt = prettytable.PrettyTable(['mem mb', 'service'])
    services = [(e['MemoryCurrent'], e['service']) for e in data['services']
                if isinstance(e['MemoryCurrent'], int)]
    procs = [(e['rss'], e['cmd']) for e in data['processes']]
    count = 0
    total = 0
    for mem, thing in reversed(sorted(services + procs)):
        total += int(mem)
        count += 1
        if count >= top:
            continue
        pt.add_row([mem >> 20, thing])
    pt.add_row([total >> 20, 'Total'])
    print(pt)


def do_db(data, top):
    pt = prettytable.PrettyTable(['db', 'op', 'count'])
    count = 0
    for db in reversed(sorted(data['db'], key=lambda d: d['count'])):
        pt.add_row([db['db'], db['op'], db['count']])
        count += 1
        if count >= top:
            break
    print(pt)


def do_api(data, top):
    pt = prettytable.PrettyTable(['service', 'op', 'count'])
    count = 0
    counts = []

    # Flatten this out to one entry per service,op
    for api in data['api']:
        for k, v in api.items():
            if '-' in k:
                counts.append([api['service'], k, v])

    for apicount in reversed(sorted(counts, key=lambda c: c[-1])):
        pt.add_row(apicount)
        count += 1
        if count >= top:
            break
    print(pt)


def do_api_client(data, top):
    pt = prettytable.PrettyTable(['service', 'op', 'count'])
    max_ps = {}

    for api in data['api']:
        max_count = 0
        max_consumer = ''
        for consumer in [k for k in api.keys() if '-' in k]:
            if max_count < api[consumer]:
                max_count = api[consumer]
                max_consumer = consumer
        max_ps[api['service'], max_consumer] = max_count

    count = 0
    for (service, consumer) in reversed(sorted(max_ps,
                                               key=lambda x: max_ps[x])):
        service_count = max_ps[(service, consumer)]
        pt.add_row([service, consumer, service_count])
        count += 1
        if count >= top:
            break
    print(pt)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--mem', action='store_true')
    p.add_argument('--db', action='store_true')
    p.add_argument('--api', action='store_true')
    p.add_argument('--api-client', action='store_true')
    p.add_argument('--top', type=int, default=10)
    p.add_argument('datafile')
    args = p.parse_args()

    if args.datafile.startswith('http'):
        d = requests.get(args.datafile).json()
    else:
        d = json.loads(open(args.datafile).read())
    if args.mem:
        do_mem(d, args.top)
    elif args.db:
        do_db(d, args.top)
    elif args.api:
        do_api(d, args.top)
    elif args.api_client:
        do_api_client(d, args.top)
    else:
        print('Run with some operation!')
        p.print_help()


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/python3

import argparse
import json
import logging
import sys

import requests

LOG = logging.getLogger('grok')


def humanize(key, value):
    """Format a value for humans, based on key name."""

    if key in ['MemoryCurrent', 'rss']:
        return '%iMiB' % (value // (1024 * 1024))
    else:
        return value


def load_file(filename):
    """Load performance data from a file, stdin, or a URL."""

    if filename == '-':
        data = json.loads(sys.stdin.read())
    elif filename.startswith('http'):
        data = requests.get(filename).json()
    else:
        data = json.loads(open(filename).read())

    return data


def list_to_dict(item_list, *keys):
    """Convert the logstash-friendly array-of-dicts to an actual dict.

    Something like this:

    [{'service': 'foo', 'memory': 123, 'pid': 1},
     {'service': 'bar', 'memory': 456, 'pid': 2}]

    becomes this (with key=service):

    {'foo': {'memory': 123, 'pid': 1},
     'bar': {'memory': 456, 'pid': 2}}

    """
    return {'-'.join(d.pop(key_name) for key_name in keys): d
            for d in item_list}


def percent_change(value1, value2):
    try:
        return int(((value2 - value1) / abs(value1)) * 100)
    except TypeError:
        print('Unable to compare %r and %r' % (value1, value2))
        return 0


def compare_and_warn_value(thingtype, name, key, reference, subject,
                           warn_thresh):
    if isinstance(reference, str) or isinstance(subject, str):
        return
    chg = percent_change(reference, subject)
    if chg > warn_thresh:
        LOG.warning('%s %s value %s grew by %i%% from %s to %s' % (
            thingtype.title(), name, key, chg,
            humanize(key, reference), humanize(key, subject)))
    else:
        LOG.info('%s %s value %s good at %i%% from %s to %s' % (
            thingtype.title(), name, key, chg,
            humanize(key, reference), humanize(key, subject)))
    return chg


def compare_and_warn(reference, subject, warn_thresh):
    things = {
        'services': ('service',),
        'processes': ('cmd',),
        'api': ('service', 'log'),
        'db': ('db',),
    }
    ignores = ['pid']

    for element, keys in things.items():
        reference_things = list_to_dict(reference[element], *keys)
        subject_things = list_to_dict(subject[element], *keys)
        for name in reference_things.keys() & subject_things.keys():
            keys = reference_things[name].keys() & subject_things[name].keys()
            for key in keys:
                if key in ignores:
                    continue
                compare_and_warn_value(element, name, key,
                                       reference_things[name][key],
                                       subject_things[name][key],
                                       warn_thresh)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('reference',
                   help='Reference performance.json')
    p.add_argument('subject',
                   help='A performance.json to judge against reference')
    p.add_argument('--verbose', '-v', action='store_true',
                   help='Be verbose about all values')
    p.add_argument('--warn', type=int, default=5,
                   help='Percent change to trigger a warning (default=5)')
    args = p.parse_args()

    if args.verbose:
        level = logging.INFO
    else:
        level = logging.WARNING
    logging.basicConfig(level=level)

    reference = load_file(args.reference)
    subject = load_file(args.subject)
    compare_and_warn(reference, subject, args.warn)

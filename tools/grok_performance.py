#!/usr/bin/python3

import argparse
import json
import logging
import sys

import requests

LOG = logging.getLogger('grok')


def humanize(key, value):
    if key in ['MemoryCurrent', 'rss']:
        return '%iMiB' % (value // (1024 * 1024))
    else:
        return value


def load_file(filename):
    if filename == '-':
        data = json.loads(sys.stdin.read())
    elif filename.startswith('http'):
        data = requests.get(filename).json()
    else:
        data = json.loads(open(filename).read())

    return data


def list_to_dict(item_list, *keys):
    return {'-'.join(d.pop(key_name) for key_name in keys): d
            for d in item_list}


def percent_change(value1, value2):
    try:
        return ((value2 - value1) / abs(value1)) * 100.0
    except TypeError:
        print('Unable to compare %r and %r' % (value1, value2))
        return 0


def compare_and_warn_value(thingtype, name, key, reference, subject):
    if isinstance(reference, str) or isinstance(subject, str):
        return
    chg = percent_change(reference, subject)
    if chg > 5:
        LOG.warning('%s %s value %s grew by %i%% from %s to %s' % (
            thingtype.title(), name, key, chg,
            humanize(key, reference), humanize(key, subject)))
    else:
        LOG.info('%s %s value %s good at %i%% from %s to %s' % (
            thingtype.title(), name, key, chg,
            humanize(key, reference), humanize(key, subject)))


def compare_and_warn(reference, subject):
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
                                       subject_things[name][key])


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('reference',
                   help='Reference performance.json')
    p.add_argument('subject',
                   help='A performance.json to judge against reference')
    p.add_argument('--verbose', '-v', action='store_true',
                   help='Be verbose about all values')
    args = p.parse_args()

    if args.verbose:
        level = logging.INFO
    else:
        level = logging.WARNING
    logging.basicConfig(level=level)

    reference = load_file(args.reference)
    subject = load_file(args.subject)
    compare_and_warn(reference, subject)
    

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
        LOG.error('Unable to compare %r and %r' % (value1, value2))
        return 0


def compare_and_warn_value(thingtype, name, key, reference, subject,
                           warn_thresh):
    if isinstance(reference, str) or isinstance(subject, str):
        LOG.debug('Not comparing string typed %s.%s.%s' % (
            thingtype, name, key))
        return
    chg = percent_change(reference, subject)
    if abs(chg) > warn_thresh:
        LOG.warning('%s %s value %s changed by %i%% from %s to %s' % (
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
        'db': ('db', 'op'),
    }
    ignores = ['pid']

    for element, keys in things.items():
        reference_things = list_to_dict(reference[element], *keys)
        subject_things = list_to_dict(subject[element], *keys)
        for name in reference_things.keys() & subject_things.keys():
            keys = reference_things[name].keys() & subject_things[name].keys()
            for key in keys:
                if key in ignores:
                    LOG.debug('Ignoring %s.%s.%s' % (element, name, key))
                    continue
                thresh = warn_thresh.get(key, warn_thresh['_default'])
                compare_and_warn_value(element, name, key,
                                       reference_things[name][key],
                                       subject_things[name][key],
                                       thresh)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('reference',
                   help='Reference performance.json')
    p.add_argument('subject',
                   help='A performance.json to judge against reference')
    p.add_argument('--verbose', '-v', action='store_true',
                   help='Be verbose about all values')
    p.add_argument('--debug', action='store_true',
                   help='Enable debugging (implies -v)')
    p.add_argument('--warn', action='append', default=[],
                   help=('Control the percent-change warning threshold '
                         'for a given key. Provide like MemoryCurrent=5. '
                         'defaults to 5 unless otherwise specified'))

    args = p.parse_args()
    if args.debug:
        level = logging.DEBUG
    elif args.verbose:
        level = logging.INFO
    else:
        level = logging.WARNING
    logging.basicConfig(level=level)

    warn_thresh = {
        '_default': 5,

        # The 'largest' size payload returned can vary quite a bit
        # based on things like 'list all resources' which will vary
        # under parallel load.
        'largest': 15,

        # This is so variable that it may not be even useful to try to
        # signal on it.
        'MemoryCurrent': 40,
    }
    for thresh in args.warn:
        try:
            key, value = thresh.split('=', 1)
            warn_thresh[key] = int(value)
        except ValueError:
            LOG.error('Invalid threshold %r; use key=intvalue' % thresh)
            sys.exit(1)

    LOG.debug('Thresholds: %s' % warn_thresh)
    reference = load_file(args.reference)
    subject = load_file(args.subject)
    compare_and_warn(reference, subject, warn_thresh)

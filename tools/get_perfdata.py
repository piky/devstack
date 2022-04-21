#!/usr/bin/python3

import argparse
import datetime
import json
import os
import requests
import sys


def get_latest_job(change, patchset=None):
    """Returns the latest job for this change,patch (or latest."""

    params = {'change': str(change)}
    if patchset:
        params['patchset'] = str(patchset)
    r = requests.get('https://zuul.opendev.org/api/tenant/openstack/builds',
                     params=params)
    r.raise_for_status()
    data = r.json()
    latest = None
    latest_job = None
    for job in data:
        if not job['end_time']:
            continue
        end_time = datetime.datetime.fromisoformat(job['end_time'])
        if not latest or end_time > latest:
            latest = end_time
            latest_job = job

    return latest_job


def get_job_urls(change, patchset):
    """Gets a dict of name:log_url for all finished jobs in change,patch."""

    r = requests.get('https://zuul.opendev.org/api/tenant/openstack/builds',
                     params={'change': str(change),
                             'patchset': str(patchset)})
    r.raise_for_status()

    urls = {}
    for job in r.json():
        # Any retried or incomplete jobs will not have log_url set
        if job['log_url']:
            urls[job['job_name']] = job['log_url']

    return urls


def write_performance_json(latest_job, urls):
    """Fetches and writes the performance.json for each job.

    This stores the performance.json in perfdata/$project/$job.json.
    It also augments the 'report' section with the change,patch that it
    was pulled from for forensics.

    latest_job is just any job from the change to get the project name
    and change,patchset from.
    """

    project = latest_job['project'].split('/', 1)[1].replace('/', '_')
    for job, url in urls.items():
        if not url:
            print('No log url for %s' % job)
            continue
        r = requests.get('%scontroller/logs/performance.json' % url)
        if r.status_code != 200:
            print('No data for %s' % job)
            continue
        fn = os.path.join('perfdata', project, '%s.json' % job)
        try:
            os.makedirs(os.path.dirname(fn))
        except FileExistsError:
            pass

        data = r.json()
        data['report']['generated_change'] = '%s,%s' % (latest_job['change'],
                                                        latest_job['patchset'])
        with open(fn, 'w') as f:
            f.write(json.dumps(data, indent=2))
            print('Wrote %s' % fn)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('change', type=int)
    p.add_argument('--patchset', type=int, default=None,
                   help=('Patchset for which jobs will be taken '
                         '(default=latest)'))

    args = p.parse_args()

    job = get_latest_job(args.change, patchset=args.patchset)
    urls = get_job_urls(args.change, job['patchset'])
    write_performance_json(job, urls)

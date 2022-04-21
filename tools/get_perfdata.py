#!/usr/bin/python3

import argparse
import datetime
import json
import os
import requests
import sys


def get_latest_job(change):
    r = requests.get('https://zuul.opendev.org/api/tenant/openstack/builds',
                     params={'change': str(change)})
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


def get_job_urls(change, event):
    r = requests.get('https://zuul.opendev.org/api/tenant/openstack/builds',
                     params={'change': str(change)})
    data = r.json()

    urls = {}
    for job in data:
        if job['event_id'] == event:
            urls[job['job_name']] = job['log_url']

    return urls


def write_performance_json(latest_job, urls):
    project = latest_job['project'].split('/', 1)[1].replace('/', '_')
    for job, url in urls.items():
        if not url:
            print('No log url for %s' % job)
            continue
        r = requests.get('%s/controller/logs/performance.json' % url)
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
    args = p.parse_args()

    job = get_latest_job(args.change)
    urls = get_job_urls(args.change, job['event_id'])
    write_performance_json(job, urls)

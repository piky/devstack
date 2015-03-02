import argparse
import datetime
import pprint
import sys
from sets import Set

class Record():
    def __init__(self, timestamp, proc, ps):
        self.timestamp = timestamp
        self.proc = proc
        self.ps = ps

    def __repr__(self):
        return "%s" % self.timestamp


def split_logfile(logfile):
    """ split the logfile into individual records"""
    records = []

    in_log = False
    for line in logfile:

        line = line.strip()

        # skip anything outside "---" & "==="
        if not in_log and line != "---":
            continue

        # start of record
        if line == "---":
            record = []
            in_log = True
            continue

        assert(in_log)

        if line == "===":
            records.append(record)
            in_log = False
            record = []
        else:
            record.append(line)
            continue

    return records


def parse(record):
    """parse a incoming record into a Record() object"""
    proc = {}
    ps = {}

    # first line has to be a datestamp
    try:
        timestamp = datetime.datetime.strptime(record[0],
                                               "%Y-%m-%dT%H:%M:%SZ")
    except:
        print "Invalid data"
        sys.exit(1)

    # first get out all the proc data; this is everything up to
    # the ps output which starts with "PID"
    for i in range(1, len(record)):
        if not record[i].startswith("PID"):
            (name, value) = record[i].split(':')
            proc[name] = value
        else:
            # finished with proc values
            break

    # now everything else is the ps output.  Split on whitespace and
    # it all just slots in.  arrange by pid
    for i in range(i+1, len(record)):
        fields = record[i].split()
        pid = fields[0]
        ps[pid] = {}
        ps[pid]['pmem'] = fields[1]
        ps[pid]['time'] = fields[2]
        ps[pid]['threads'] = fields[3]
        ps[pid]['wchan'] = fields[4]
        ps[pid]['command'] = fields[5]
        ps[pid]['args'] = fields[6:]

    return Record(timestamp, proc, ps)


def gnuplot_memory(all_records):

    all_pids_set = Set()
    for record in all_records:
        for pid in record.ps:
            all_pids_set.add(pid)

    all_pids = dict((i, []) for i in all_pids_set)

    for record in all_records:
        all_pids_set_copy = all_pids_set.copy()

        for pid in record.ps:
            all_pids[pid].append(record.ps[pid]['pmem'])
            all_pids_set_copy.remove(pid)

        # fill in zeros
        for pid in all_pids_set_copy:
            all_pids[pid].append(0)

    f = open('memtracker.plot', 'w')
    f.write("unset key\n")
    f.write("set xdata time\n")
    f.write('set timefmt "%Y-%m-%dT%H:%M:%S"\n')
    f.write('plot \\\n')
    i = 0
    plots = []
    for pid in all_pids_set:
        plots.append("'memtracker.data' using 1:%d title '%s' with lines" % (i+2, pid))
        i = i+1

    f.write(",\\\n".join(plots))

    f.close()
    f = open('memtracker.data','w')

    for i in range(0, len(all_records)):
        f.write(str(all_records[i].timestamp.isoformat()) + " ")
        for pid in all_pids_set:
            f.write(str(all_pids[pid][i])+ " ")
        f.write("\n")

    f.close()

    print "run gnuplot memtracker.plot"

def main():
    parser = argparse.ArgumentParser(description='Process memtracker.')
    parser.add_argument('logfile')
    args = parser.parse_args()

    # list of all Records, by date
    all_records = []

    records = split_logfile(open(args.logfile))
    for record in records:
        all_records.append(parse(record))

    # done with raw data, now in all_records
    del(records)

    # we only do one thing right now, which is output gnuplot data for
    # time on the x-asis and all processes and their % memory use on
    # the y-axis.  Yes there are some issues if pids are being
    # recycled, but it's a pretty good view to see if something is
    # going crazy at a first pass.
    gnuplot_memory(all_records)

if __name__ == "__main__":
    main()

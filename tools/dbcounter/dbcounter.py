import json
import logging
import threading
import time
import queue

import sqlalchemy
from sqlalchemy.engine import CreateEnginePlugin
from sqlalchemy import event

LOG = logging.getLogger(__name__)
QUEUE = queue.Queue()
LOCK = threading.Lock()
WRITER_THREAD = None


def do_incr(engine, db, op, count):
    """INSERT or UPDATE (db,op) += count"""
    query = ('INSERT INTO queries (db, op, count) '
             '  VALUES (%s, %s, %s) '
             '  ON DUPLICATE KEY UPDATE count=count+%s')
    try:
        with engine.begin() as conn:
            r = conn.execute(query, (db, op, count, count))
    except Exception as e:
        LOG.error('Failed to account for access to database %r: %s',
                  db, e)


def stat_writer(engine):
    """Consume messages from the queue and write them in batches.

    This writes (db,op)=count stats to the database every ten seconds
    to avoid triggering a write for every SELECT call.
    """
    LOG.debug('Writer thread running')
    while True:
        to_write = {}
        while not QUEUE.empty():
            item = QUEUE.get(block=False)
            to_write.setdefault(item, 0)
            to_write[item] += 1

        for (db, op), count in to_write.items():
            LOG.debug('Writing DB stats %s,%s += %i' % (db, op, count))
            do_incr(engine, db, op, count)

        time.sleep(10)


class LogCursorEventsPlugin(CreateEnginePlugin):
    def __init__(self, url, kwargs):
        self.db_name = url.database
        LOG.info('Registered counter for database %s' % self.db_name)

        # Check for singleton writer thread with a lock, in case we
        # are called from an actually-multithreaded environment
        with LOCK:
            if WRITER_THREAD is None:
                self.ensure_writer_thread(url)

    def ensure_writer_thread(self, url):
        new_url = sqlalchemy.engine.URL.create(url.drivername,
                                               url.username,
                                               url.password,
                                               url.host,
                                               url.port,
                                               'stats')
        engine = sqlalchemy.create_engine(new_url)

        WRITER_THREAD = threading.Thread(target=stat_writer, args=(engine,),
                                         daemon=True)
        WRITER_THREAD.start()
        LOG.debug('Started writer thread')

    def engine_created(self, engine):
        event.listen(engine, "before_cursor_execute", self._log_event)

    def _log_event(self, conn, cursor, statement, parameters, context,
                   executemany):
        try:
            op = statement.strip().split(' ', 1)[0] or 'OTHER'
        except Exception:
            op = 'OTHER'

        QUEUE.put((self.db_name, op))

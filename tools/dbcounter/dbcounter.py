import json
import logging
import os
import threading
import time
import queue

import sqlalchemy
from sqlalchemy.engine import CreateEnginePlugin
from sqlalchemy import event

# https://docs.sqlalchemy.org/en/14/core/connections.html?
# highlight=createengineplugin#sqlalchemy.engine.CreateEnginePlugin

LOG = logging.getLogger(__name__)


class LogCursorEventsPlugin(CreateEnginePlugin):
    def __init__(self, url, kwargs):
        self.db_name = url.database
        LOG.info('Registered counter for database %s' % self.db_name)
        new_url = sqlalchemy.engine.URL.create(url.drivername,
                                               url.username,
                                               url.password,
                                               url.host,
                                               url.port,
                                               'stats')

        self.engine = sqlalchemy.create_engine(new_url)
        self.queue = queue.Queue()
        self.thread = None

    def engine_created(self, engine):
        event.listen(engine, "before_cursor_execute", self._log_event)

    def ensure_writer_thread(self):
        self.thread = threading.Thread(target=self.stat_writer, daemon=True)
        self.thread.start()

    def _log_event(self, conn, cursor, statement, parameters, context,
                   executemany):

        # If we were forked after the engine was created and this
        # plugin was associated, our writer thread is gone, so respawn
        if not self.thread or not self.thread.is_alive():
            self.ensure_writer_thread()

        try:
            op = statement.strip().split(' ', 1)[0] or 'OTHER'
        except Exception:
            op = 'OTHER'

        self.queue.put((self.db_name, op))

    def do_incr(self, db, op, count):
        """INSERT or UPDATE (db,op) += count"""
        query = ('INSERT INTO queries (db, op, count) '
                 '  VALUES (%s, %s, %s) '
                 '  ON DUPLICATE KEY UPDATE count=count+%s')
        try:
            with self.engine.begin() as conn:
                r = conn.execute(query, (db, op, count, count))
        except Exception as e:
            LOG.error('Failed to account for access to database %r: %s',
                      db, e)

    def stat_writer(self):
        """Consume messages from the queue and write them in batches.

        This writes (db,op)=count stats to the database every ten seconds
        to avoid triggering a write for every SELECT call.
        """
        LOG.debug('[%i] Writer thread running' % os.getpid())
        while True:
            to_write = {}
            while not self.queue.empty():
                item = self.queue.get(block=False)
                to_write.setdefault(item, 0)
                to_write[item] += 1
            for (db, op), count in to_write.items():
                LOG.debug('[%i] Writing DB stats %s,%s += %i' % (
                    os.getpid(), db, op, count))
                self.do_incr(db, op, count)

            time.sleep(10)

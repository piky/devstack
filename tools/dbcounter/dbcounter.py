import logging

import sqlalchemy
from sqlalchemy.engine import CreateEnginePlugin
from sqlalchemy import event

LOG = logging.getLogger(__name__)


class LogCursorEventsPlugin(CreateEnginePlugin):
    def __init__(self, url, kwargs):
        new_url = sqlalchemy.engine.URL.create(url.drivername,
                                               url.username,
                                               url.password,
                                               url.host,
                                               url.port,
                                               'stats')
        engine = sqlalchemy.create_engine(new_url)
        self.stats_conn = engine.connect()
        self.db_name = url.database
        LOG.info('Registered counter for database %s' % self.db_name)

    def engine_created(self, engine):
        event.listen(engine, "before_cursor_execute", self._log_event)

    def _log_event(self, conn, cursor, statement, parameters, context,
                   executemany):

        try:
            op = statement.split(' ', 1)[0]
        except Exception:
            op = 'OTHER'

        query = ('INSERT INTO queries (db, op, count) '
                 '  VALUES (%s, %s, %s) '
                 '  ON DUPLICATE KEY UPDATE count=count+1')
        try:
            with self.stats_conn.begin():
                self.stats_conn.execute(query, (self.db_name, op, 1))
        except Exception as e:
            LOG.error('Failed to account for access to database %r',
                      self.db_name)

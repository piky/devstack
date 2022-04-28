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
        self.db_name = url.database
        self.engine = sqlalchemy.create_engine(new_url)
        LOG.info('Registered counter for database %s' % self.db_name)

    def engine_created(self, engine):
        event.listen(engine, "before_cursor_execute", self._log_event)

    def _log_event(self, conn, cursor, statement, parameters, context,
                   executemany):

        try:
            op = statement.strip().split(' ', 1)[0] or 'OTHER'
        except Exception:
            op = 'OTHER'

        query = ('INSERT INTO queries (db, op, count) '
                 '  VALUES (%s, %s, %s) '
                 '  ON DUPLICATE KEY UPDATE count=count+1')
        try:
            with self.engine.begin() as conn:
                r = conn.execute(query, (self.db_name, op, 1))
        except Exception as e:
            LOG.error('Failed to account for access to database %r: %s',
                      self.db_name, e)

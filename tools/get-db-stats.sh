#!/bin/bash

echo 'SELECT COUNT(*) AS queries,current_schema FROM ' \
    'events_statements_history GROUP BY current_schema;' | \
    mysql performance_schema

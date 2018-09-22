#!/usr/bin/env bash
# A script to run unit and integration tests with a clean database instance
# Uses the busted framework: http://olivinelabs.com/busted/
# >>> luarocks install busted
# NOTE: you must have already created a user with login named cloud.
#       See INSTALL.md for information on how to do this
# author: andrew schmitt
# since 7/9/2018

source snapCloud/.env
export PGDATA=$PG_DATA_DIR
# Start postgres if not running.
pg_ctl status 2&> /dev/null
pg_status=$?
if [ "$pg_status" = "1" ]
then
    pg_ctl start &
    echo 'Waiting for pg to start...'
    sleep 5;
fi

# lapis config will pull this in as the db name
export DATABASE_NAME=snapcloud_test
export DATABASE_USERNAME=cloud

# Kill any existing test database and create a new one
dropdb --if-exists ${DATABASE_NAME}
createdb -O ${DATABASE_USERNAME} ${DATABASE_NAME}

# load the schema into the test db
psql -U cloud -d ${DATABASE_NAME} -a -f snapCloud/cloud.sql > /dev/null

# Run the tests in the spec directory with resty nginx libraries
cd snapCloud && resty -I ../spec/ ../resty_busted.lua ../spec
results=$?

# Cleanup postgres.
if [ $pg_status -eq 1 ]
then
    pg_ctl stop &
fi

exit $results;

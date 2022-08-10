#!/usr/bin/env bash
export NETWORK_CODE=${1,,}
# create empty databases
PGSQL_HOST="${NETWORK_CODE}_db"
CORE_DB_INIT="PGPASSWORD=postgres createdb ${NETWORK_CODE}-core -h $PGSQL_HOST -U postgres > /dev/null 2>&1"
HORIZON_DB_INIT="PGPASSWORD=postgres createdb ${NETWORK_CODE}-horizon -h $PGSQL_HOST -U postgres > /dev/null 2>&1"
docker exec -it ${NETWORK_CODE}_core bash -c "$CORE_DB_INIT && $HORIZON_DB_INIT"

# stellar-core database migration
docker exec -it ${NETWORK_CODE}_core bash -c "stellar-core new-db"

# horizon database migration
docker exec -it ${NETWORK_CODE}_horizon bash -c "horizon db init"
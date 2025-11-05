#!/usr/bin/env bash
set -euo pipefail

# Idempotent PostgreSQL migration runner
# Uses env vars with defaults and a migrations tracking table (schema_migrations)
# Env:
#   POSTGRES_HOST (default: localhost)
#   POSTGRES_PORT (default: 5001)
#   POSTGRES_DB   (default: myapp)
#   POSTGRES_USER (default: appuser)
#   POSTGRES_PASSWORD (default: dbuser123)
#   POSTGIS_ENABLE (default: false)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_DIR="${SCRIPT_DIR}/migrations"

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5001}"
POSTGRES_DB="${POSTGRES_DB:-myapp}"
POSTGRES_USER="${POSTGRES_USER:-appuser}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-dbuser123}"
POSTGIS_ENABLE="${POSTGIS_ENABLE:-false}"

export PGPASSWORD="${POSTGRES_PASSWORD}"

PSQL="psql -v ON_ERROR_STOP=1 -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER} -d ${POSTGRES_DB} -X -q"

echo "==> Running migrations on postgresql://${POSTGRES_USER}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"

# Ensure database exists (connect to postgres db to create target db if necessary)
create_db_if_needed() {
  echo "Checking database existence..."
  if ! psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB}'" | grep -q 1; then
    echo "Creating database ${POSTGRES_DB}..."
    psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d postgres -c "CREATE DATABASE ${POSTGRES_DB};"
  fi
}

# Ensure schema_migrations table exists by applying 0001 if needed
apply_init_if_needed() {
  if ! ${PSQL} -tAc "SELECT to_regclass('public.schema_migrations') IS NOT NULL" | grep -q t; then
    echo "Applying initial migration tracker (0001)..."
    ${PSQL} -f "${MIGRATIONS_DIR}/0001_init.sql"
    ${PSQL} -c "INSERT INTO schema_migrations(version, checksum) VALUES ('0001_init.sql', NULL) ON CONFLICT DO NOTHING;"
  fi
}

# Optionally enable postgis
enable_postgis_if_requested() {
  if [[ "${POSTGIS_ENABLE}" == "true" || "${POSTGIS_ENABLE}" == "1" ]]; then
    echo "Ensuring PostGIS extension is enabled..."
    ${PSQL} -c "CREATE EXTENSION IF NOT EXISTS postgis;"
  else
    echo "PostGIS is disabled (set POSTGIS_ENABLE=true to enable)"
  fi
}

apply_migrations() {
  shopt -s nullglob
  local files=("${MIGRATIONS_DIR}"/[0-9][0-9][0-9][0-9]_*.sql)
  for file in "${files[@]}"; do
    local base
    base="$(basename "${file}")"
    # Skip 0001 if it was inserted already
    local applied
    applied="$(${PSQL} -tAc "SELECT 1 FROM schema_migrations WHERE version='${base}'")" || applied=""
    if [[ -n "${applied}" ]]; then
      echo "Skipping already applied migration: ${base}"
      continue
    fi
    echo "Applying migration: ${base}"
    ${PSQL} -f "${file}"
    ${PSQL} -c "INSERT INTO schema_migrations(version, checksum) VALUES ('${base}', NULL) ON CONFLICT DO NOTHING;"
  done
  shopt -u nullglob
}

main() {
  create_db_if_needed
  apply_init_if_needed
  enable_postgis_if_requested
  apply_migrations
  echo "==> Migrations completed"
}

main "$@"

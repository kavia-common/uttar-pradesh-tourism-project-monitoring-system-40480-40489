#!/usr/bin/env bash
set -euo pipefail

# Universal Database Restore Script
# Uses env vars with defaults, restores from backup/ directory

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5001}"
POSTGRES_DB="${POSTGRES_DB:-myapp}"
POSTGRES_USER="${POSTGRES_USER:-appuser}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-dbuser123}"

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backup"

# Discover the most recent backup files
SQL_FILE="$(ls -t ${BACKUP_DIR}/database_backup_*.sql 2>/dev/null | head -1 || true)"
DB_FILE="$(ls -t ${BACKUP_DIR}/database_backup_*.db 2>/dev/null | head -1 || true)"
ARCHIVE_FILE="$(ls -t ${BACKUP_DIR}/database_backup_*.archive 2>/dev/null | head -1 || true)"

# SQLite restore
if [ -n "${DB_FILE}" ] && [ -f "${DB_FILE}" ]; then
  echo "Restoring SQLite database from ${DB_FILE}..."
  cp "${DB_FILE}" "${POSTGRES_DB}"
  echo "✓ Database restored successfully"
  exit 0
fi

# PostgreSQL/MySQL restore from SQL file
if [ -n "${SQL_FILE}" ] && [ -f "${SQL_FILE}" ]; then
  PG_VERSION=$(ls /usr/lib/postgresql/ 2>/dev/null | head -1 || true)
  if [ -n "$PG_VERSION" ]; then
    PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"
    if sudo -u postgres ${PG_BIN}/pg_isready -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} > /dev/null 2>&1; then
      echo "Restoring PostgreSQL database from ${SQL_FILE}..."
      export PGPASSWORD="${POSTGRES_PASSWORD}"
      ${PG_BIN}/psql \
        -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER} -d postgres \
        < "${SQL_FILE}" 2>/dev/null
      echo "✓ Database restored successfully"
      exit 0
    fi
  fi

  # Try MySQL
  if mysqladmin ping -h localhost -P ${POSTGRES_PORT} --silent 2>/dev/null || \
     sudo mysqladmin ping --socket=/var/run/mysqld/mysqld.sock --silent 2>/dev/null; then
    echo "Restoring MySQL database from ${SQL_FILE}..."
    if mysql -h localhost -P ${POSTGRES_PORT} -u ${POSTGRES_USER} -p${POSTGRES_PASSWORD} \
        -e "SELECT 1" >/dev/null 2>&1; then
      mysql -h localhost -P ${POSTGRES_PORT} -u ${POSTGRES_USER} -p${POSTGRES_PASSWORD} < "${SQL_FILE}"
      echo "✓ Database restored successfully (via TCP port ${POSTGRES_PORT})"
      exit 0
    fi
  fi
fi

# MongoDB restore from archive
if [ -n "${ARCHIVE_FILE}" ] && [ -f "${ARCHIVE_FILE}" ]; then
  if mongosh --port ${POSTGRES_PORT} --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo "Restoring MongoDB database from ${ARCHIVE_FILE}..."
    mongosh --port ${POSTGRES_PORT} --eval "use ${POSTGRES_DB}" > /dev/null 2>&1
    mongorestore --port ${POSTGRES_PORT} --archive="${ARCHIVE_FILE}" --drop --quiet
    echo "✓ Database restored successfully"
    exit 0
  fi
fi

echo "ℹ No backup found or database not running"
echo "  Starting with fresh database"
echo ""
echo "Looked for backup files in ${BACKUP_DIR}:"
echo "  - database_backup_*.db (SQLite)"
echo "  - database_backup_*.sql (PostgreSQL/MySQL)"
echo "  - database_backup_*.archive (MongoDB)"
exit 0

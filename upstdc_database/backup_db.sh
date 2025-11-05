#!/usr/bin/env bash
set -euo pipefail

# Universal Database Backup Script (stores backups under backup/)
# Uses env vars with defaults for PostgreSQL target

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5001}"
POSTGRES_DB="${POSTGRES_DB:-myapp}"
POSTGRES_USER="${POSTGRES_USER:-appuser}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-dbuser123}"

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backup"
mkdir -p "${BACKUP_DIR}"

timestamp="$(date +%Y%m%d_%H%M%S)"

# SQLite backup (if project used sqlite file named as db)
if [ -f "${POSTGRES_DB}" ]; then
  echo "Backing up SQLite database file..."
  cp "${POSTGRES_DB}" "${BACKUP_DIR}/database_backup_${timestamp}.db"
  echo "✓ Backup saved to ${BACKUP_DIR}/database_backup_${timestamp}.db"
  exit 0
fi

# PostgreSQL backup
PG_VERSION=$(ls /usr/lib/postgresql/ 2>/dev/null | head -1 || true)
if [ -n "${PG_VERSION}" ]; then
  PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"
  if sudo -u postgres ${PG_BIN}/pg_isready -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} > /dev/null 2>&1; then
    echo "Backing up PostgreSQL database..."
    export PGPASSWORD="${POSTGRES_PASSWORD}"
    ${PG_BIN}/pg_dump \
      -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
      --clean --if-exists --create > "${BACKUP_DIR}/database_backup_${timestamp}.sql"
    echo "✓ Backup saved to ${BACKUP_DIR}/database_backup_${timestamp}.sql"
    exit 0
  fi
fi

# MySQL backup (fallback)
if mysqladmin ping -h localhost -P ${POSTGRES_PORT} --silent 2>/dev/null || \
   sudo mysqladmin ping --socket=/var/run/mysqld/mysqld.sock --silent 2>/dev/null; then
  echo "Backing up MySQL database..."
  if mysql -h localhost -P ${POSTGRES_PORT} -u ${POSTGRES_USER} -p${POSTGRES_PASSWORD} \
      -e "SELECT 1" >/dev/null 2>&1; then
    mysqldump -h localhost -P ${POSTGRES_PORT} \
      -u ${POSTGRES_USER} -p${POSTGRES_PASSWORD} \
      --databases ${POSTGRES_DB} --add-drop-database \
      --routines --triggers --single-transaction > "${BACKUP_DIR}/database_backup_${timestamp}.sql"
    echo "✓ Backup saved to ${BACKUP_DIR}/database_backup_${timestamp}.sql (via TCP port ${POSTGRES_PORT})"
    exit 0
  fi
fi

# MongoDB backup (fallback)
if mongosh --port ${POSTGRES_PORT} --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
  echo "Backing up MongoDB database..."
  mongodump --port ${POSTGRES_PORT} --db ${POSTGRES_DB} \
    --archive="${BACKUP_DIR}/database_backup_${timestamp}.archive" --quiet
  echo "✓ Backup saved to ${BACKUP_DIR}/database_backup_${timestamp}.archive"
  exit 0
fi

echo "⚠ No running database detected"
echo "Make sure your database is running before creating a backup"
exit 1

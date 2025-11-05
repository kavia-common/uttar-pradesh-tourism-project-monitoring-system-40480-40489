#!/usr/bin/env bash
set -euo pipefail

# PostgreSQL startup and bootstrap script
# Uses env vars with defaults and runs migrations idempotently

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5001}"
POSTGRES_DB="${POSTGRES_DB:-myapp}"
POSTGRES_USER="${POSTGRES_USER:-appuser}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-dbuser123}"
POSTGIS_ENABLE="${POSTGIS_ENABLE:-false}"

echo "Starting PostgreSQL setup..."
echo "Host: ${POSTGRES_HOST}  Port: ${POSTGRES_PORT}  DB: ${POSTGRES_DB}  User: ${POSTGRES_USER}"

# Find PostgreSQL version and set paths
PG_VERSION=$(ls /usr/lib/postgresql/ | head -1)
PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"

echo "Found PostgreSQL version: ${PG_VERSION}"

# Check if PostgreSQL is already running on the specified port
if sudo -u postgres ${PG_BIN}/pg_isready -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} > /dev/null 2>&1; then
    echo "PostgreSQL is already running on ${POSTGRES_HOST}:${POSTGRES_PORT}"
else
    # Also check if there's a PostgreSQL process running (in case pg_isready fails)
    if pgrep -f "postgres.*-p ${POSTGRES_PORT}" > /dev/null 2>&1; then
        echo "Found existing PostgreSQL process on port ${POSTGRES_PORT}"
    else
        # Initialize PostgreSQL data directory if it doesn’t exist
        if [ ! -f "/var/lib/postgresql/data/PG_VERSION" ]; then
            echo "Initializing PostgreSQL..."
            sudo -u postgres ${PG_BIN}/initdb -D /var/lib/postgresql/data
        fi

        # Start PostgreSQL server in background
        echo "Starting PostgreSQL server..."
        sudo -u postgres ${PG_BIN}/postgres -D /var/lib/postgresql/data -p ${POSTGRES_PORT} &
        echo "Waiting for PostgreSQL to start..."
        for i in {1..20}; do
            if sudo -u postgres ${PG_BIN}/pg_isready -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} > /dev/null 2>&1; then
                echo "PostgreSQL is ready!"
                break
            fi
            echo "Waiting... ($i/20)"
            sleep 2
        done
    fi
fi

# Ensure user and database exist and grant privileges
echo "Setting up database and user..."
# Create user and database via postgres db
sudo -u postgres ${PG_BIN}/psql -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -d postgres << EOF
-- Create user if doesn't exist
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${POSTGRES_USER}') THEN
        CREATE ROLE ${POSTGRES_USER} WITH LOGIN PASSWORD '${POSTGRES_PASSWORD}';
    ELSE
        ALTER ROLE ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';
    END IF;
END
\$\$;
-- Create database if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB}') THEN
        PERFORM dblink_exec('dbname=postgres', 'CREATE DATABASE ${POSTGRES_DB}');
    END IF;
END
\$\$ LANGUAGE plpgsql;
EOF

# Fallback create database if dblink is unavailable
sudo -u postgres ${PG_BIN}/createdb -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} ${POSTGRES_DB} 2>/dev/null || true

# Schema-level grants
sudo -u postgres ${PG_BIN}/psql -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -d ${POSTGRES_DB} << EOF
GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};
GRANT USAGE, CREATE ON SCHEMA public TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TYPES TO ${POSTGRES_USER};
EOF

# Save connection strings
echo "psql postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}" > "$(dirname "$0")/db_connection.txt"
echo "Connection string saved to db_connection.txt"

# Save environment variables to a file for db_visualizer
cat > "$(dirname "$0")/db_visualizer/postgres.env" << EOF
export POSTGRES_URL="postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
export POSTGRES_USER="${POSTGRES_USER}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
export POSTGRES_DB="${POSTGRES_DB}"
export POSTGRES_PORT="${POSTGRES_PORT}"
export POSTGIS_ENABLE="${POSTGIS_ENABLE}"
EOF

# Run migrations idempotently
echo "Running migrations..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POSTGRES_HOST="${POSTGRES_HOST}" POSTGRES_PORT="${POSTGRES_PORT}" POSTGRES_DB="${POSTGRES_DB}" POSTGRES_USER="${POSTGRES_USER}" POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" POSTGIS_ENABLE="${POSTGIS_ENABLE}" \
bash "${SCRIPT_DIR}/migrate.sh"

echo "PostgreSQL setup complete!"
echo "Database: ${POSTGRES_DB}"
echo "User: ${POSTGRES_USER}"
echo "Host: ${POSTGRES_HOST}"
echo "Port: ${POSTGRES_PORT}"
echo ""
echo "Environment variables saved to upstdc_database/db_visualizer/postgres.env"
echo "To use with Node.js viewer, run: source upstdc_database/db_visualizer/postgres.env"
echo "To connect to the database:"
echo "psql -h ${POSTGRES_HOST} -U ${POSTGRES_USER} -d ${POSTGRES_DB} -p ${POSTGRES_PORT}"
echo "$(cat "$(dirname "$0")/db_connection.txt")"

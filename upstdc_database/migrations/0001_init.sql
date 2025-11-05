-- 0001_init.sql
-- Initial migration: setup schema_migrations, core extensions, and basic helpers
-- Idempotent by design

BEGIN;

-- Migrations tracker table
CREATE TABLE IF NOT EXISTS schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    checksum TEXT
);

-- Core extensions that are generally useful
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Optional: postgis will be created conditionally by startup.sh via POSTGIS_ENABLE

-- Basic helper function to update updated_at columns automatically
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;

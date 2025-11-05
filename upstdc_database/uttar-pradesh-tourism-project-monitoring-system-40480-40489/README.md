# uttar-pradesh-tourism-project-monitoring-system-40480-40489

This repository contains the UPSTDC Project Monitoring System components.

Database setup lives under:
- upstdc_database/ (PostgreSQL schema, migrations, seed data, and scripts)

Quick start for database:
1) Configure environment variables (defaults shown)
   - POSTGRES_HOST=localhost
   - POSTGRES_PORT=5001
   - POSTGRES_DB=myapp
   - POSTGRES_USER=appuser
   - POSTGRES_PASSWORD=dbuser123
   - POSTGIS_ENABLE=false

2) Run startup (idempotent, enables PostGIS if requested, applies migrations)
   POSTGRES_PORT=5001 POSTGIS_ENABLE=true bash upstdc_database/startup.sh

3) Connect using:
   psql postgresql://appuser:dbuser123@localhost:5001/myapp

See upstdc_database/README.md (this folder's README content) for:
- Details of migrations (0001..0005)
- RBAC roles and permissions
- Optional PostGIS support
- Backup/restore scripts and usage

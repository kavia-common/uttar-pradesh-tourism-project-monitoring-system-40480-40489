-- 0004_indexes.sql
-- Indexes and constraints

BEGIN;

-- Common lookup indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_department ON users (department_id);

CREATE INDEX IF NOT EXISTS idx_contractors_name ON contractors (name);

CREATE INDEX IF NOT EXISTS idx_projects_status ON projects (status);
CREATE INDEX IF NOT EXISTS idx_projects_department ON projects (department_id);
CREATE INDEX IF NOT EXISTS idx_projects_location ON projects (location_id);

-- Spatial indexes (only effective if PostGIS extension is enabled)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_locations_geom ON locations USING GIST (geom)';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_projects_geom ON projects USING GIST (geom)';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_updates_geom ON milestone_updates USING GIST (geom)';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_inspections_geom ON inspections USING GIST (geom)';
  END IF;
END$$;

-- FK helper indexes
CREATE INDEX IF NOT EXISTS idx_tenders_project ON tenders (project_id);
CREATE INDEX IF NOT EXISTS idx_contracts_project ON contracts (project_id);
CREATE INDEX IF NOT EXISTS idx_contracts_contractor ON contracts (contractor_id);

CREATE INDEX IF NOT EXISTS idx_milestones_project ON milestones (project_id);
CREATE INDEX IF NOT EXISTS idx_milestones_contract ON milestones (contract_id);
CREATE INDEX IF NOT EXISTS idx_updates_milestone ON milestone_updates (milestone_id);
CREATE INDEX IF NOT EXISTS idx_updates_project ON milestone_updates (project_id);

CREATE INDEX IF NOT EXISTS idx_payments_project ON payments (project_id);
CREATE INDEX IF NOT EXISTS idx_payments_contract ON payments (contract_id);
CREATE INDEX IF NOT EXISTS idx_payments_milestone ON payments (milestone_id);

CREATE INDEX IF NOT EXISTS idx_inspections_project ON inspections (project_id);
CREATE INDEX IF NOT EXISTS idx_inspections_contract ON inspections (contract_id);
CREATE INDEX IF NOT EXISTS idx_inspections_milestone ON inspections (milestone_id);

CREATE INDEX IF NOT EXISTS idx_handover_project ON handovers (project_id);
CREATE INDEX IF NOT EXISTS idx_handover_contract ON handovers (contract_id);

CREATE INDEX IF NOT EXISTS idx_attachments_project ON attachments (project_id);
CREATE INDEX IF NOT EXISTS idx_attachments_contract ON attachments (contract_id);
CREATE INDEX IF NOT EXISTS idx_attachments_milestone ON attachments (milestone_id);
CREATE INDEX IF NOT EXISTS idx_attachments_update ON attachments (update_id);
CREATE INDEX IF NOT EXISTS idx_attachments_inspection ON attachments (inspection_id);
CREATE INDEX IF NOT EXISTS idx_attachments_uploaded_by ON attachments (uploaded_by);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs (entity);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at);

COMMIT;

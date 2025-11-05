-- 0002_rbac.sql
-- Role Based Access Control schema and bootstrap data (without users)

BEGIN;

-- Users table
-- Password hashing left to backend; here we store hashed_password column
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    full_name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    hashed_password TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Roles
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE, -- e.g., ADMIN, PMU, ENGINEER, ACCOUNTANT, CONTRACTOR, VIEWER
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Permissions
CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE, -- e.g., PROJECT_CREATE, PROJECT_VIEW, etc.
    name TEXT NOT NULL,
    description TEXT
);

-- Role-Permission mapping
CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- User-Role mapping
CREATE TABLE IF NOT EXISTS user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- Organization/Department (optional for visibility scoping)
CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT
);

-- User department
ALTER TABLE IF EXISTS users
    ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES departments(id) ON DELETE SET NULL;

-- Bootstrap roles (idempotent)
INSERT INTO roles (code, name, description)
VALUES
    ('ADMIN', 'Administrator', 'Full access to the system'),
    ('PMU', 'PMU', 'Project Management Unit'),
    ('ENGINEER', 'Engineer', 'Project engineers'),
    ('ACCOUNTANT', 'Accountant', 'Finance and payments'),
    ('CONTRACTOR', 'Contractor', 'External contractor users'),
    ('VIEWER', 'Viewer', 'Read-only access')
ON CONFLICT (code) DO NOTHING;

-- Define a reasonable set of permissions
-- Grouped by domain: users, projects, tenders, contracts, milestones, payments, inspections, handovers, attachments, reports, admin
INSERT INTO permissions (code, name, description) VALUES
    ('USER_VIEW', 'View Users', 'Can view users'),
    ('USER_MANAGE', 'Manage Users', 'Can create/update/delete users'),
    ('ROLE_VIEW', 'View Roles', 'Can view roles'),
    ('ROLE_MANAGE', 'Manage Roles', 'Can create/update/delete roles'),
    ('PROJECT_CREATE', 'Create Project', 'Can create projects'),
    ('PROJECT_VIEW', 'View Project', 'Can view projects'),
    ('PROJECT_UPDATE', 'Update Project', 'Can update projects'),
    ('PROJECT_DELETE', 'Delete Project', 'Can delete projects'),
    ('TENDER_MANAGE', 'Manage Tenders', 'Can create/update/delete tenders'),
    ('TENDER_VIEW', 'View Tenders', 'Can view tenders'),
    ('CONTRACT_MANAGE', 'Manage Contracts', 'Can create/update/delete contracts'),
    ('CONTRACT_VIEW', 'View Contracts', 'Can view contracts'),
    ('MILESTONE_MANAGE', 'Manage Milestones', 'Can create/update/delete milestones'),
    ('MILESTONE_VIEW', 'View Milestones', 'Can view milestones'),
    ('PAYMENT_MANAGE', 'Manage Payments', 'Can create/update/delete payments'),
    ('PAYMENT_VIEW', 'View Payments', 'Can view payments'),
    ('INSPECTION_MANAGE', 'Manage Inspections', 'Can create/update/delete inspections'),
    ('INSPECTION_VIEW', 'View Inspections', 'Can view inspections'),
    ('HANDOVER_MANAGE', 'Manage Handovers', 'Can create/update/delete handovers'),
    ('HANDOVER_VIEW', 'View Handovers', 'Can view handovers'),
    ('ATTACHMENT_MANAGE', 'Manage Attachments', 'Can upload/delete attachments'),
    ('ATTACHMENT_VIEW', 'View Attachments', 'Can view attachments'),
    ('REPORT_VIEW', 'View Reports', 'Can view and export reports'),
    ('ADMIN_PANEL', 'Admin Panel', 'Can access admin panel')
ON CONFLICT (code) DO NOTHING;

-- Map role -> permission defaults
-- ADMIN gets all permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON TRUE
WHERE r.code = 'ADMIN'
ON CONFLICT DO NOTHING;

-- PMU: broad management except admin panel and user/role manage
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'PROJECT_CREATE','PROJECT_VIEW','PROJECT_UPDATE','PROJECT_DELETE',
    'TENDER_MANAGE','TENDER_VIEW',
    'CONTRACT_MANAGE','CONTRACT_VIEW',
    'MILESTONE_MANAGE','MILESTONE_VIEW',
    'PAYMENT_MANAGE','PAYMENT_VIEW',
    'INSPECTION_MANAGE','INSPECTION_VIEW',
    'HANDOVER_MANAGE','HANDOVER_VIEW',
    'ATTACHMENT_MANAGE','ATTACHMENT_VIEW',
    'REPORT_VIEW'
)
WHERE r.code = 'PMU'
ON CONFLICT DO NOTHING;

-- ENGINEER: view + manage for inspections, milestones, updates; view projects/contracts/tenders
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'PROJECT_VIEW',
    'TENDER_VIEW',
    'CONTRACT_VIEW',
    'MILESTONE_MANAGE','MILESTONE_VIEW',
    'INSPECTION_MANAGE','INSPECTION_VIEW',
    'ATTACHMENT_MANAGE','ATTACHMENT_VIEW',
    'REPORT_VIEW'
)
WHERE r.code = 'ENGINEER'
ON CONFLICT DO NOTHING;

-- ACCOUNTANT: manage payments and view relevant data
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'PROJECT_VIEW',
    'CONTRACT_VIEW',
    'PAYMENT_MANAGE','PAYMENT_VIEW',
    'REPORT_VIEW',
    'ATTACHMENT_VIEW'
)
WHERE r.code = 'ACCOUNTANT'
ON CONFLICT DO NOTHING;

-- CONTRACTOR: view their projects/contracts/tenders, upload attachments, milestone updates
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'PROJECT_VIEW',
    'TENDER_VIEW',
    'CONTRACT_VIEW',
    'MILESTONE_MANAGE','MILESTONE_VIEW',
    'ATTACHMENT_MANAGE','ATTACHMENT_VIEW',
    'REPORT_VIEW'
)
WHERE r.code = 'CONTRACTOR'
ON CONFLICT DO NOTHING;

-- VIEWER: read-only across domains (no manage)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'USER_VIEW','ROLE_VIEW',
    'PROJECT_VIEW','TENDER_VIEW','CONTRACT_VIEW',
    'MILESTONE_VIEW','PAYMENT_VIEW','INSPECTION_VIEW',
    'HANDOVER_VIEW','ATTACHMENT_VIEW','REPORT_VIEW'
)
WHERE r.code = 'VIEWER'
ON CONFLICT DO NOTHING;

COMMIT;

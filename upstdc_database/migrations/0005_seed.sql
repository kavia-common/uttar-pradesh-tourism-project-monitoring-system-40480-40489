-- 0005_seed.sql
-- Seed initial/reference data and admin user
-- Note: Replace the placeholder hashed password securely in production.

BEGIN;

-- Departments
INSERT INTO departments (name, description) VALUES
    ('Tourism', 'Tourism Department'),
    ('Engineering', 'Engineering Department'),
    ('Finance', 'Finance and Accounts')
ON CONFLICT (name) DO NOTHING;

-- Create an admin user if not exists
-- Placeholder password note: Use backend to set a strong hashed password.
-- For demo: set hashed_password to a recognizable placeholder string.
INSERT INTO users (email, phone, full_name, is_active, hashed_password)
SELECT 'admin@upstdc.in', '0000000000', 'System Administrator', true, 'REPLACE_WITH_SECURE_HASH'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE email = 'admin@upstdc.in');

-- Attach ADMIN role to admin user
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.code = 'ADMIN'
WHERE u.email = 'admin@upstdc.in'
ON CONFLICT DO NOTHING;

-- Add a demo contractor
INSERT INTO contractors (name, contact_person, email, phone)
VALUES ('ABC Constructions Pvt. Ltd.', 'Raj Kumar', 'contact@abcbuild.com', '9999999999')
ON CONFLICT (name) DO NOTHING;

-- Minimal example project
INSERT INTO projects (code, name, description, status, budget_amount)
VALUES ('P-0001', 'Ayodhya Tourism Facilities Upgrade', 'Infrastructure and amenities upgrade', 'PLANNED', 100000000.00)
ON CONFLICT (code) DO NOTHING;

-- Sample tender
INSERT INTO tenders (project_id, tender_no, title, status)
SELECT p.id, 'TND-0001', 'Civil works package', 'OPEN'
FROM projects p WHERE p.code = 'P-0001'
ON CONFLICT DO NOTHING;

COMMIT;

-- Schema-Only Database State
-- Creates all tables and structures with no data

-- Drop all existing tables
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO public;

-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    role VARCHAR(20) DEFAULT 'user',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Projects table
CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    repository_url VARCHAR(255),
    status VARCHAR(20) DEFAULT 'active',
    owner_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Environments table
CREATE TABLE environments (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    type VARCHAR(20) NOT NULL, -- dev, test, staging, prod
    url VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Deployments table
CREATE TABLE deployments (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    environment_id INTEGER REFERENCES environments(id),
    version VARCHAR(50) NOT NULL,
    commit_hash VARCHAR(40),
    deployed_by INTEGER REFERENCES users(id),
    status VARCHAR(20) DEFAULT 'pending',
    deployed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- Test Results table
CREATE TABLE test_results (
    id SERIAL PRIMARY KEY,
    deployment_id INTEGER REFERENCES deployments(id) ON DELETE CASCADE,
    test_type VARCHAR(50) NOT NULL, -- unit, integration, security, performance
    status VARCHAR(20) NOT NULL, -- passed, failed, skipped
    total_tests INTEGER DEFAULT 0,
    passed_tests INTEGER DEFAULT 0,
    failed_tests INTEGER DEFAULT 0,
    skipped_tests INTEGER DEFAULT 0,
    execution_time_ms INTEGER,
    report_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Security Scans table
CREATE TABLE security_scans (
    id SERIAL PRIMARY KEY,
    deployment_id INTEGER REFERENCES deployments(id) ON DELETE CASCADE,
    scan_type VARCHAR(50) NOT NULL, -- SAST, DAST, dependency
    tool VARCHAR(50), -- SonarQube, ZAP, Snyk
    status VARCHAR(20) DEFAULT 'pending',
    critical_findings INTEGER DEFAULT 0,
    high_findings INTEGER DEFAULT 0,
    medium_findings INTEGER DEFAULT 0,
    low_findings INTEGER DEFAULT 0,
    report_url VARCHAR(255),
    scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit Logs table
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id INTEGER,
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Settings table
CREATE TABLE settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT,
    description TEXT,
    updated_by INTEGER REFERENCES users(id),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notifications table
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(200),
    message TEXT,
    is_read BOOLEAN DEFAULT false,
    data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_projects_owner ON projects(owner_id);
CREATE INDEX idx_deployments_project ON deployments(project_id);
CREATE INDEX idx_deployments_environment ON deployments(environment_id);
CREATE INDEX idx_test_results_deployment ON test_results(deployment_id);
CREATE INDEX idx_security_scans_deployment ON security_scans(deployment_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);

-- Create views for reporting
CREATE VIEW deployment_summary AS
SELECT 
    d.id,
    d.version,
    p.name as project_name,
    e.name as environment_name,
    d.status,
    d.deployed_at,
    u.username as deployed_by_user
FROM deployments d
JOIN projects p ON d.project_id = p.id
JOIN environments e ON d.environment_id = e.id
LEFT JOIN users u ON d.deployed_by = u.id;

CREATE VIEW security_overview AS
SELECT 
    p.name as project_name,
    COUNT(DISTINCT s.id) as total_scans,
    SUM(s.critical_findings) as total_critical,
    SUM(s.high_findings) as total_high,
    SUM(s.medium_findings) as total_medium,
    SUM(s.low_findings) as total_low,
    MAX(s.scanned_at) as last_scan
FROM projects p
LEFT JOIN deployments d ON p.id = d.project_id
LEFT JOIN security_scans s ON d.id = s.deployment_id
GROUP BY p.id, p.name;

-- Add update timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO testadmin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO testadmin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO testadmin;
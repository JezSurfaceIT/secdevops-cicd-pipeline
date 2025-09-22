-- Framework Data State
-- Schema + Basic framework data (users, roles, settings)

-- First apply schema-only state
\i /app/sql/states/schema-only.sql

-- Insert framework users
INSERT INTO users (username, email, password_hash, first_name, last_name, role) VALUES
('admin', 'admin@secdevops.com', '$2b$12$LQvRTWLNqwiANmCRb0TTHO.U0CuLbgXLK0HXfxQvKlTPzLyPQPtK.', 'Admin', 'User', 'admin'),
('developer1', 'dev1@secdevops.com', '$2b$12$LQvRTWLNqwiANmCRb0TTHO.U0CuLbgXLK0HXfxQvKlTPzLyPQPtK.', 'John', 'Developer', 'developer'),
('developer2', 'dev2@secdevops.com', '$2b$12$LQvRTWLNqwiANmCRb0TTHO.U0CuLbgXLK0HXfxQvKlTPzLyPQPtK.', 'Jane', 'Developer', 'developer'),
('tester1', 'tester1@secdevops.com', '$2b$12$LQvRTWLNqwiANmCRb0TTHO.U0CuLbgXLK0HXfxQvKlTPzLyPQPtK.', 'Bob', 'Tester', 'tester'),
('security', 'security@secdevops.com', '$2b$12$LQvRTWLNqwiANmCRb0TTHO.U0CuLbgXLK0HXfxQvKlTPzLyPQPtK.', 'Security', 'Officer', 'security'),
('readonly', 'readonly@secdevops.com', '$2b$12$LQvRTWLNqwiANmCRb0TTHO.U0CuLbgXLK0HXfxQvKlTPzLyPQPtK.', 'Read', 'Only', 'viewer');

-- Insert basic projects
INSERT INTO projects (name, description, repository_url, status, owner_id) VALUES
('Oversight Application', 'Main oversight application for compliance monitoring', 'https://github.com/org/oversight-app', 'active', 1),
('Security Tools', 'Security scanning and monitoring tools', 'https://github.com/org/security-tools', 'active', 5),
('Test Automation', 'Automated testing framework', 'https://github.com/org/test-automation', 'active', 4);

-- Insert environments for each project
INSERT INTO environments (project_id, name, type, url, is_active) VALUES
-- Oversight Application environments
(1, 'Development', 'dev', 'http://dev.oversight.internal', true),
(1, 'Testing', 'test', 'http://test.oversight.internal', true),
(1, 'Staging', 'staging', 'http://staging.oversight.internal', true),
(1, 'Production', 'prod', 'https://oversight.company.com', true),
-- Security Tools environments
(2, 'Development', 'dev', 'http://dev.security.internal', true),
(2, 'Production', 'prod', 'https://security.company.com', true),
-- Test Automation environments
(3, 'Development', 'dev', 'http://dev.testing.internal', true),
(3, 'Production', 'prod', 'https://testing.company.com', true);

-- Insert system settings
INSERT INTO settings (key, value, description, updated_by) VALUES
('deployment.auto_rollback', 'true', 'Automatically rollback failed deployments', 1),
('deployment.health_check_timeout', '300', 'Health check timeout in seconds', 1),
('deployment.parallel_deployments', '2', 'Maximum parallel deployments allowed', 1),
('security.scan_on_deploy', 'true', 'Run security scans on every deployment', 5),
('security.block_critical', 'true', 'Block deployment if critical vulnerabilities found', 5),
('security.max_high_findings', '5', 'Maximum allowed high severity findings', 5),
('testing.minimum_coverage', '80', 'Minimum test coverage percentage required', 4),
('testing.run_integration_tests', 'true', 'Run integration tests in pipeline', 4),
('notifications.email_enabled', 'true', 'Enable email notifications', 1),
('notifications.slack_enabled', 'true', 'Enable Slack notifications', 1),
('notifications.slack_webhook', 'https://hooks.slack.com/services/XXXXX', 'Slack webhook URL', 1),
('maintenance.backup_enabled', 'true', 'Enable automatic backups', 1),
('maintenance.backup_retention_days', '30', 'Backup retention period in days', 1),
('monitoring.prometheus_enabled', 'true', 'Enable Prometheus metrics', 1),
('monitoring.grafana_url', 'http://grafana.company.com', 'Grafana dashboard URL', 1);

-- Insert sample notifications for admin user
INSERT INTO notifications (user_id, type, title, message, data) VALUES
(1, 'info', 'System Initialized', 'Test database has been initialized with framework data', '{"source": "db-api"}'),
(1, 'warning', 'Maintenance Window', 'Scheduled maintenance this weekend', '{"start": "2024-01-20T00:00:00Z", "duration": "4h"}');

-- Insert initial audit log entry
INSERT INTO audit_logs (user_id, action, resource_type, resource_id, details) VALUES
(1, 'database.initialized', 'system', 0, '{"state": "framework", "timestamp": "' || CURRENT_TIMESTAMP || '"}');

-- Create materialized view for quick stats
CREATE MATERIALIZED VIEW system_stats AS
SELECT 
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT COUNT(*) FROM projects) as total_projects,
    (SELECT COUNT(*) FROM environments) as total_environments,
    (SELECT COUNT(*) FROM deployments) as total_deployments,
    (SELECT COUNT(*) FROM security_scans) as total_scans,
    CURRENT_TIMESTAMP as last_updated;

-- Refresh the materialized view
REFRESH MATERIALIZED VIEW system_stats;

-- Create function to reset sequences
CREATE OR REPLACE FUNCTION reset_sequences() RETURNS void AS $$
DECLARE
    seq RECORD;
BEGIN
    FOR seq IN 
        SELECT sequence_name 
        FROM information_schema.sequences 
        WHERE sequence_schema = 'public'
    LOOP
        EXECUTE 'ALTER SEQUENCE ' || seq.sequence_name || ' RESTART WITH 100';
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Reset sequences to avoid conflicts
SELECT reset_sequences();

-- Output summary
DO $$
BEGIN
    RAISE NOTICE 'Framework data loaded successfully';
    RAISE NOTICE 'Users created: 6';
    RAISE NOTICE 'Projects created: 3';
    RAISE NOTICE 'Environments created: 8';
    RAISE NOTICE 'Settings configured: 15';
END $$;
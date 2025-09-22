-- Full Test Data State
-- Complete test dataset with realistic data

-- First apply framework state
\i /app/sql/states/framework-data.sql

-- Additional test users
INSERT INTO users (username, email, password_hash, first_name, last_name, role) VALUES
('qa_lead', 'qa_lead@secdevops.com', '$2b$12$LQvRTWLNqwiANmCRb0TTHO.U0CuLbgXLK0HXfxQvKlTPzLyPQPtK.', 'Alice', 'QALead', 'tester'),
('devops1', 'devops1@secdevops.com', '$2b$12$LQvRTWLNqwiANmCRb0TTHO.U0CuLbgXLK0HXfxQvKlTPzLyPQPtK.', 'Charlie', 'DevOps', 'admin'),
('pentester', 'pentester@secdevops.com', '$2b$12$LQvRTWLNqwiANmCRb0TTHO.U0CuLbgXLK0HXfxQvKlTPzLyPQPtK.', 'Eve', 'PenTester', 'security'),
('contractor1', 'contractor1@external.com', '$2b$12$LQvRTWLNqwiANmCRb0TTHO.U0CuLbgXLK0HXfxQvKlTPzLyPQPtK.', 'Frank', 'Contractor', 'developer');

-- Additional projects
INSERT INTO projects (name, description, repository_url, status, owner_id) VALUES
('API Gateway', 'Central API gateway for all services', 'https://github.com/org/api-gateway', 'active', 2),
('Data Analytics', 'Analytics and reporting dashboard', 'https://github.com/org/data-analytics', 'active', 3),
('Mobile App', 'Mobile application for field workers', 'https://github.com/org/mobile-app', 'development', 2),
('Legacy System', 'Legacy system being phased out', 'https://github.com/org/legacy', 'maintenance', 1);

-- Additional environments
INSERT INTO environments (project_id, name, type, url, is_active) VALUES
-- API Gateway environments
(4, 'Development', 'dev', 'http://dev.api.internal', true),
(4, 'Testing', 'test', 'http://test.api.internal', true),
(4, 'Production', 'prod', 'https://api.company.com', true),
-- Data Analytics environments
(5, 'Development', 'dev', 'http://dev.analytics.internal', true),
(5, 'Production', 'prod', 'https://analytics.company.com', true),
-- Mobile App environments
(6, 'Development', 'dev', 'http://dev.mobile.internal', true),
(6, 'Testing', 'test', 'http://test.mobile.internal', true),
-- Legacy System environment
(7, 'Production', 'prod', 'https://legacy.company.com', true);

-- Deployment history
INSERT INTO deployments (project_id, environment_id, version, commit_hash, deployed_by, status, deployed_at, completed_at) VALUES
-- Oversight App deployments
(1, 1, 'v1.0.0', 'abc123def456', 2, 'success', NOW() - INTERVAL '30 days', NOW() - INTERVAL '30 days' + INTERVAL '5 minutes'),
(1, 2, 'v1.0.0', 'abc123def456', 2, 'success', NOW() - INTERVAL '29 days', NOW() - INTERVAL '29 days' + INTERVAL '5 minutes'),
(1, 3, 'v1.0.0', 'abc123def456', 1, 'success', NOW() - INTERVAL '28 days', NOW() - INTERVAL '28 days' + INTERVAL '10 minutes'),
(1, 4, 'v1.0.0', 'abc123def456', 1, 'success', NOW() - INTERVAL '27 days', NOW() - INTERVAL '27 days' + INTERVAL '15 minutes'),
(1, 1, 'v1.1.0', 'def789ghi012', 3, 'success', NOW() - INTERVAL '20 days', NOW() - INTERVAL '20 days' + INTERVAL '5 minutes'),
(1, 2, 'v1.1.0', 'def789ghi012', 3, 'success', NOW() - INTERVAL '19 days', NOW() - INTERVAL '19 days' + INTERVAL '5 minutes'),
(1, 3, 'v1.1.0', 'def789ghi012', 1, 'success', NOW() - INTERVAL '18 days', NOW() - INTERVAL '18 days' + INTERVAL '10 minutes'),
(1, 4, 'v1.1.0', 'def789ghi012', 1, 'success', NOW() - INTERVAL '17 days', NOW() - INTERVAL '17 days' + INTERVAL '15 minutes'),
(1, 1, 'v1.2.0', 'ghi345jkl678', 2, 'failed', NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days' + INTERVAL '3 minutes'),
(1, 1, 'v1.2.1', 'jkl901mno234', 2, 'success', NOW() - INTERVAL '9 days', NOW() - INTERVAL '9 days' + INTERVAL '5 minutes'),
(1, 2, 'v1.2.1', 'jkl901mno234', 2, 'success', NOW() - INTERVAL '8 days', NOW() - INTERVAL '8 days' + INTERVAL '5 minutes'),
(1, 3, 'v1.2.1', 'jkl901mno234', 1, 'success', NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days' + INTERVAL '10 minutes'),
(1, 4, 'v1.2.1', 'jkl901mno234', 1, 'success', NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days' + INTERVAL '15 minutes'),
-- Security Tools deployments
(2, 5, 'v2.0.0', 'sec123abc456', 5, 'success', NOW() - INTERVAL '15 days', NOW() - INTERVAL '15 days' + INTERVAL '7 minutes'),
(2, 6, 'v2.0.0', 'sec123abc456', 5, 'success', NOW() - INTERVAL '14 days', NOW() - INTERVAL '14 days' + INTERVAL '12 minutes'),
(2, 5, 'v2.1.0', 'sec789def012', 5, 'success', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days' + INTERVAL '7 minutes'),
(2, 6, 'v2.1.0', 'sec789def012', 5, 'success', NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days' + INTERVAL '12 minutes'),
-- Test Automation deployments
(3, 7, 'v3.0.0', 'test456ghi789', 4, 'success', NOW() - INTERVAL '12 days', NOW() - INTERVAL '12 days' + INTERVAL '4 minutes'),
(3, 8, 'v3.0.0', 'test456ghi789', 4, 'success', NOW() - INTERVAL '11 days', NOW() - INTERVAL '11 days' + INTERVAL '8 minutes'),
-- API Gateway deployments
(4, 9, 'v0.9.0', 'api111aaa222', 8, 'success', NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days' + INTERVAL '6 minutes'),
(4, 10, 'v0.9.0', 'api111aaa222', 8, 'success', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '6 minutes'),
(4, 11, 'v0.9.0', 'api111aaa222', 1, 'rollback', NOW() - INTERVAL '1 days', NOW() - INTERVAL '1 days' + INTERVAL '2 minutes');

-- Test results for deployments
INSERT INTO test_results (deployment_id, test_type, status, total_tests, passed_tests, failed_tests, skipped_tests, execution_time_ms, report_url) VALUES
-- Tests for deployment 1
(1, 'unit', 'passed', 150, 150, 0, 0, 12000, 'http://jenkins/job/1/testReport'),
(1, 'integration', 'passed', 45, 45, 0, 0, 35000, 'http://jenkins/job/1/integrationReport'),
(1, 'security', 'passed', 20, 20, 0, 0, 180000, 'http://jenkins/job/1/securityReport'),
-- Tests for deployment 2
(2, 'unit', 'passed', 150, 150, 0, 0, 11500, 'http://jenkins/job/2/testReport'),
(2, 'integration', 'passed', 45, 44, 1, 0, 36000, 'http://jenkins/job/2/integrationReport'),
-- Tests for deployment 9 (failed)
(9, 'unit', 'failed', 155, 148, 7, 0, 13000, 'http://jenkins/job/9/testReport'),
(9, 'integration', 'skipped', 0, 0, 0, 45, 0, NULL),
-- Tests for deployment 10
(10, 'unit', 'passed', 155, 155, 0, 0, 12500, 'http://jenkins/job/10/testReport'),
(10, 'integration', 'passed', 45, 45, 0, 0, 34000, 'http://jenkins/job/10/integrationReport'),
(10, 'security', 'passed', 20, 19, 1, 0, 175000, 'http://jenkins/job/10/securityReport'),
(10, 'performance', 'passed', 10, 10, 0, 0, 300000, 'http://jenkins/job/10/performanceReport'),
-- Tests for recent deployments
(13, 'unit', 'passed', 160, 160, 0, 0, 13500, 'http://jenkins/job/13/testReport'),
(13, 'integration', 'passed', 48, 48, 0, 0, 38000, 'http://jenkins/job/13/integrationReport'),
(13, 'security', 'passed', 22, 22, 0, 0, 195000, 'http://jenkins/job/13/securityReport'),
(13, 'performance', 'passed', 12, 11, 1, 0, 320000, 'http://jenkins/job/13/performanceReport');

-- Security scan results
INSERT INTO security_scans (deployment_id, scan_type, tool, status, critical_findings, high_findings, medium_findings, low_findings, report_url, scanned_at) VALUES
-- Scans for deployment 1
(1, 'SAST', 'SonarQube', 'completed', 0, 0, 3, 15, 'http://sonarqube/project/1', NOW() - INTERVAL '30 days'),
(1, 'dependency', 'Snyk', 'completed', 0, 1, 5, 12, 'http://snyk/report/1', NOW() - INTERVAL '30 days'),
-- Scans for deployment 10
(10, 'SAST', 'SonarQube', 'completed', 0, 0, 2, 10, 'http://sonarqube/project/10', NOW() - INTERVAL '9 days'),
(10, 'DAST', 'OWASP ZAP', 'completed', 0, 1, 4, 8, 'http://zap/report/10', NOW() - INTERVAL '9 days'),
(10, 'dependency', 'Snyk', 'completed', 0, 0, 3, 10, 'http://snyk/report/10', NOW() - INTERVAL '9 days'),
-- Scans for deployment 13
(13, 'SAST', 'SonarQube', 'completed', 0, 0, 1, 8, 'http://sonarqube/project/13', NOW() - INTERVAL '6 days'),
(13, 'DAST', 'OWASP ZAP', 'completed', 0, 0, 2, 5, 'http://zap/report/13', NOW() - INTERVAL '6 days'),
(13, 'dependency', 'Snyk', 'completed', 0, 0, 2, 7, 'http://snyk/report/13', NOW() - INTERVAL '6 days'),
(13, 'container', 'Trivy', 'completed', 0, 0, 1, 4, 'http://trivy/report/13', NOW() - INTERVAL '6 days'),
-- Recent scans
(17, 'SAST', 'SonarQube', 'completed', 0, 0, 0, 5, 'http://sonarqube/project/17', NOW() - INTERVAL '4 days'),
(17, 'DAST', 'OWASP ZAP', 'running', 0, 0, 0, 0, NULL, NOW() - INTERVAL '4 days'),
(21, 'SAST', 'SonarQube', 'completed', 0, 2, 5, 12, 'http://sonarqube/project/21', NOW() - INTERVAL '2 days'),
(22, 'dependency', 'Snyk', 'failed', 0, 0, 0, 0, NULL, NOW() - INTERVAL '1 days');

-- Audit logs for various activities
INSERT INTO audit_logs (user_id, action, resource_type, resource_id, details, ip_address, user_agent) VALUES
(1, 'user.login', 'user', 1, '{"method": "password"}', '192.168.1.100', 'Mozilla/5.0'),
(2, 'deployment.initiated', 'deployment', 1, '{"version": "v1.0.0", "environment": "dev"}', '192.168.1.101', 'Jenkins/2.401'),
(2, 'deployment.completed', 'deployment', 1, '{"status": "success", "duration": "5m"}', '192.168.1.101', 'Jenkins/2.401'),
(5, 'scan.initiated', 'security_scan', 1, '{"type": "SAST", "tool": "SonarQube"}', '192.168.1.105', 'SonarQube Scanner'),
(1, 'project.created', 'project', 4, '{"name": "API Gateway"}', '192.168.1.100', 'Mozilla/5.0'),
(3, 'settings.updated', 'settings', 1, '{"key": "deployment.auto_rollback", "old": "false", "new": "true"}', '192.168.1.102', 'Mozilla/5.0'),
(4, 'test.executed', 'test', 1, '{"type": "integration", "total": 45}', '192.168.1.103', 'pytest/7.4.0'),
(8, 'deployment.rollback', 'deployment', 22, '{"reason": "Health check failed"}', '192.168.1.108', 'kubectl/1.28'),
(9, 'security.alert', 'security_scan', 12, '{"finding": "SQL Injection", "severity": "high"}', '192.168.1.109', 'OWASP ZAP/2.14'),
(1, 'user.created', 'user', 10, '{"username": "contractor1"}', '192.168.1.100', 'Mozilla/5.0'),
(6, 'user.logout', 'user', 6, '{"session_duration": "2h15m"}', '192.168.1.106', 'Mozilla/5.0');

-- Additional notifications
INSERT INTO notifications (user_id, type, title, message, is_read, data) VALUES
(1, 'deployment', 'Deployment Successful', 'Version v1.2.1 deployed to production', true, '{"deployment_id": 13}'),
(2, 'test_failure', 'Unit Tests Failed', '7 unit tests failed in v1.2.0', true, '{"deployment_id": 9}'),
(5, 'security', 'High Severity Finding', 'SQL Injection vulnerability detected', false, '{"scan_id": 12}'),
(1, 'system', 'Maintenance Complete', 'Database maintenance completed successfully', true, '{"duration": "45m"}'),
(3, 'deployment', 'Awaiting Approval', 'Deployment to staging requires approval', false, '{"deployment_id": 12}'),
(4, 'test_complete', 'All Tests Passed', 'Integration tests completed successfully', true, '{"deployment_id": 13}'),
(8, 'alert', 'Rollback Triggered', 'Automatic rollback initiated for API Gateway', true, '{"deployment_id": 22}'),
(1, 'quota', 'Resource Limit Warning', '85% of deployment quota used this month', false, '{"used": 85, "limit": 100}');

-- Performance metrics data (sample)
CREATE TABLE IF NOT EXISTS performance_metrics (
    id SERIAL PRIMARY KEY,
    deployment_id INTEGER REFERENCES deployments(id),
    metric_name VARCHAR(100),
    value DECIMAL(10,2),
    unit VARCHAR(20),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO performance_metrics (deployment_id, metric_name, value, unit, timestamp) VALUES
(13, 'response_time_avg', 245.5, 'ms', NOW() - INTERVAL '6 days'),
(13, 'response_time_p95', 780.2, 'ms', NOW() - INTERVAL '6 days'),
(13, 'throughput', 1250.0, 'req/s', NOW() - INTERVAL '6 days'),
(13, 'error_rate', 0.02, 'percent', NOW() - INTERVAL '6 days'),
(13, 'cpu_usage', 45.5, 'percent', NOW() - INTERVAL '6 days'),
(13, 'memory_usage', 68.2, 'percent', NOW() - INTERVAL '6 days');

-- Create sample vulnerability data
CREATE TABLE IF NOT EXISTS vulnerabilities (
    id SERIAL PRIMARY KEY,
    scan_id INTEGER REFERENCES security_scans(id),
    cve_id VARCHAR(50),
    severity VARCHAR(20),
    component VARCHAR(200),
    description TEXT,
    remediation TEXT,
    is_resolved BOOLEAN DEFAULT false
);

INSERT INTO vulnerabilities (scan_id, cve_id, severity, component, description, remediation, is_resolved) VALUES
(2, 'CVE-2023-1234', 'high', 'express@4.17.1', 'Remote code execution vulnerability', 'Update to express@4.18.2 or later', false),
(2, 'CVE-2023-5678', 'medium', 'lodash@4.17.20', 'Prototype pollution', 'Update to lodash@4.17.21', false),
(5, 'CVE-2023-9012', 'medium', 'axios@0.21.1', 'Server-side request forgery', 'Update to axios@0.21.4', true),
(8, 'CVE-2024-0001', 'low', 'moment@2.29.1', 'Regular expression DoS', 'Consider using date-fns instead', false);

-- Refresh materialized view with full data
REFRESH MATERIALIZED VIEW system_stats;

-- Create indexes for performance with full data
CREATE INDEX IF NOT EXISTS idx_deployments_status ON deployments(status);
CREATE INDEX IF NOT EXISTS idx_test_results_status ON test_results(status);
CREATE INDEX IF NOT EXISTS idx_security_scans_status ON security_scans(status);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_deployment ON performance_metrics(deployment_id);
CREATE INDEX IF NOT EXISTS idx_vulnerabilities_severity ON vulnerabilities(severity, is_resolved);

-- Output summary
DO $$
DECLARE
    v_users INTEGER;
    v_projects INTEGER;
    v_deployments INTEGER;
    v_tests INTEGER;
    v_scans INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_users FROM users;
    SELECT COUNT(*) INTO v_projects FROM projects;
    SELECT COUNT(*) INTO v_deployments FROM deployments;
    SELECT COUNT(*) INTO v_tests FROM test_results;
    SELECT COUNT(*) INTO v_scans FROM security_scans;
    
    RAISE NOTICE 'Full test data loaded successfully';
    RAISE NOTICE 'Total users: %', v_users;
    RAISE NOTICE 'Total projects: %', v_projects;
    RAISE NOTICE 'Total deployments: %', v_deployments;
    RAISE NOTICE 'Total test results: %', v_tests;
    RAISE NOTICE 'Total security scans: %', v_scans;
END $$;
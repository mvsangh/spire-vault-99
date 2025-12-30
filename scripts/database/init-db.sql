-- Database Initialization Script for SPIRE-Vault-99
-- Creates tables and seeds demo users (Brooklyn Nine-Nine theme)

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Create index on username and email for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- GitHub integrations table
CREATE TABLE IF NOT EXISTS github_integrations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_configured BOOLEAN DEFAULT FALSE NOT NULL,
    configured_at TIMESTAMP,
    last_accessed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_github_integrations_user_id ON github_integrations(user_id);

-- Audit log table
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(100),
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Create indexes on audit_log for faster queries
CREATE INDEX IF NOT EXISTS idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at);

-- Insert demo users (Brooklyn Nine-Nine theme)
-- Passwords are bcrypt hashed with cost factor 12
-- Password format: <username>99 (e.g., jake99, amy99, etc.)

INSERT INTO users (username, email, password_hash) VALUES
    -- jake / jake99
    ('jake', 'jake@precinct99.nypd', '$2b$12$JBxsZEgat.6wF8SJu6yWJewcSa/6X1rZK/vUxZ9jPtGNnC9dpqirO'),
    -- amy / amy99
    ('amy', 'amy@precinct99.nypd', '$2b$12$bzpBkJzWcl9LaUqTPPs/j.ACuPly9uOSv3hObDyePRSSKYq.PaZwK'),
    -- rosa / rosa99
    ('rosa', 'rosa@precinct99.nypd', '$2b$12$HPF1oodM8XFeJGeu2cgUc.0mG/U92ajcYsxhxtrZJFZOsN3vfHBLm'),
    -- terry / terry99
    ('terry', 'terry@precinct99.nypd', '$2b$12$tgtXWVFKeVDTLqiblt7RO.Trf/ihTDRts1hQJTAjlCE27BrgugK4O'),
    -- charles / charles99
    ('charles', 'charles@precinct99.nypd', '$2b$12$mhwrkOV7bFyBKm7rOGIPnOVZUYRkUNqtcFDLMuQjs.8MTCiTYkBKC'),
    -- gina / gina99
    ('gina', 'gina@precinct99.nypd', '$2b$12$Ww3yDtL0ia7o7nGyvQPNhu.nx.oGmdjrKcpjTMfJ.htHgyR6c/Mx.')
ON CONFLICT (username) DO NOTHING;

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_github_integrations_updated_at ON github_integrations;
CREATE TRIGGER update_github_integrations_updated_at BEFORE UPDATE ON github_integrations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Verify setup
DO $$
DECLARE
    user_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM users;
    RAISE NOTICE '✅ Database initialized successfully!';
    RAISE NOTICE 'Total users: %', user_count;
END $$;

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Function to safely add a column if it doesn't exist
CREATE OR REPLACE FUNCTION add_column_if_not_exists(
    _table text,
    _column text,
    _type text,
    _constraint text DEFAULT ''
) RETURNS void AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = _table
        AND column_name = _column
    ) THEN
        EXECUTE format('ALTER TABLE %I ADD COLUMN %I %s %s', _table, _column, _type, _constraint);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Begin transaction
BEGIN;

-- Create driver_profiles table if it doesn't exist, otherwise modify existing
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'driver_profiles') THEN
        CREATE TABLE driver_profiles (
            id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
            slack_user_id TEXT,
            slack_username TEXT,
            full_name TEXT,
            email TEXT,
            phone TEXT,
            license_number TEXT,
            license_expiry DATE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        
        -- Add unique constraint on slack_user_id
        ALTER TABLE driver_profiles ADD CONSTRAINT driver_profiles_slack_user_id_key UNIQUE (slack_user_id);
    ELSE
        -- Add new columns to existing table
        PERFORM add_column_if_not_exists('driver_profiles', 'slack_user_id', 'TEXT');
        PERFORM add_column_if_not_exists('driver_profiles', 'slack_username', 'TEXT');
        PERFORM add_column_if_not_exists('driver_profiles', 'full_name', 'TEXT');
        PERFORM add_column_if_not_exists('driver_profiles', 'email', 'TEXT');
        PERFORM add_column_if_not_exists('driver_profiles', 'phone', 'TEXT');
        PERFORM add_column_if_not_exists('driver_profiles', 'license_number', 'TEXT');
        PERFORM add_column_if_not_exists('driver_profiles', 'license_expiry', 'DATE');
        PERFORM add_column_if_not_exists('driver_profiles', 'created_at', 'TIMESTAMP WITH TIME ZONE', 'DEFAULT NOW()');
        PERFORM add_column_if_not_exists('driver_profiles', 'updated_at', 'TIMESTAMP WITH TIME ZONE', 'DEFAULT NOW()');
        
        -- Add unique constraint if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 
            FROM pg_constraint 
            WHERE conname = 'driver_profiles_slack_user_id_key'
        ) THEN
            ALTER TABLE driver_profiles ADD CONSTRAINT driver_profiles_slack_user_id_key UNIQUE (slack_user_id);
        END IF;
    END IF;
END $$;

-- Create driver_van_assignments table if it doesn't exist
CREATE TABLE IF NOT EXISTS driver_van_assignments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    driver_id UUID REFERENCES driver_profiles(id),
    van_id UUID REFERENCES vans(id),
    assignment_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(driver_id, assignment_date)
);

-- Create driver_images table if it doesn't exist
CREATE TABLE IF NOT EXISTS driver_images (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    driver_id UUID REFERENCES driver_profiles(id),
    van_image_id UUID REFERENCES van_images(id),
    van_id UUID REFERENCES vans(id),
    image_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_driver_van_assignments_date') THEN
        CREATE INDEX idx_driver_van_assignments_date ON driver_van_assignments(assignment_date);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_driver_images_date') THEN
        CREATE INDEX idx_driver_images_date ON driver_images(image_date);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_slack_user_id') THEN
        CREATE INDEX idx_slack_user_id ON driver_profiles(slack_user_id);
    END IF;
END $$;

-- Create or replace the updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS update_driver_profiles_updated_at ON driver_profiles;
CREATE TRIGGER update_driver_profiles_updated_at
    BEFORE UPDATE ON driver_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Drop and recreate views
DROP VIEW IF EXISTS active_driver_assignments CASCADE;
CREATE VIEW active_driver_assignments AS
SELECT 
    dp.slack_username as driver_name,
    dp.slack_user_id,
    v.van_number,
    dva.assignment_date,
    dva.created_at
FROM driver_van_assignments dva
JOIN driver_profiles dp ON dp.id = dva.driver_id
JOIN vans v ON v.id = dva.van_id
ORDER BY dva.assignment_date DESC;

DROP VIEW IF EXISTS driver_image_summary CASCADE;
CREATE VIEW driver_image_summary AS
SELECT 
    dp.slack_username as driver_name,
    v.van_number,
    COUNT(di.id) as total_images,
    MAX(di.created_at) as last_upload
FROM driver_profiles dp
JOIN driver_images di ON di.driver_id = dp.id
JOIN vans v ON v.id = di.van_id
GROUP BY dp.slack_username, v.van_number
ORDER BY MAX(di.created_at) DESC;

-- Commit transaction
COMMIT; 
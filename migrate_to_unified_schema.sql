-- SAFE MIGRATION: Unify Database Schema
-- This script will work whether you have old 'vans' table or new 'van_profiles' table
-- Run this in Supabase Dashboard -> SQL Editor

-- Step 1: Create new schema tables if they don't exist
CREATE TABLE IF NOT EXISTS driver_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    slack_user_id VARCHAR(50) UNIQUE NOT NULL,
    driver_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS van_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_number INTEGER UNIQUE NOT NULL,
    make VARCHAR(50) DEFAULT 'Unknown',
    model VARCHAR(50) DEFAULT 'Unknown',
    year INTEGER DEFAULT 2020,
    status VARCHAR(20) DEFAULT 'active',
    current_driver_id UUID REFERENCES driver_profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS van_images (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id UUID REFERENCES van_profiles(id),
    van_number INTEGER, -- Made nullable to fix constraint violations
    driver_id UUID REFERENCES driver_profiles(id),
    image_url TEXT,
    image_data TEXT, -- Base64 encoded image data
    image_path VARCHAR(255),
    file_size INTEGER,
    mime_type VARCHAR(50),
    van_damage TEXT DEFAULT 'No damage description',
    van_rating INTEGER CHECK (van_rating >= 1 AND van_rating <= 5),
    source VARCHAR(50) DEFAULT 'slack_bot',
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    image_data_full TEXT -- Full base64 data for backup
);

-- Step 2: Migrate data from old 'vans' table to 'van_profiles' if it exists
DO $$
BEGIN
    -- Check if old 'vans' table exists and has data
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vans' AND table_schema = 'public') THEN
        -- Copy data from vans to van_profiles, avoiding duplicates
        INSERT INTO van_profiles (van_number, make, model, year, status, created_at, updated_at)
        SELECT 
            van_number,
            COALESCE(make, 'Unknown'),
            COALESCE(model, 'Unknown'),
            COALESCE(year, 2020),
            COALESCE(status, 'active'),
            COALESCE(created_at, NOW()),
            COALESCE(updated_at, NOW())
        FROM vans v
        WHERE NOT EXISTS (
            SELECT 1 FROM van_profiles vp WHERE vp.van_number = v.van_number
        );
        
        RAISE NOTICE 'Migrated data from vans table to van_profiles table';
    END IF;
END $$;

-- Step 3: Create sample data if tables are empty
INSERT INTO driver_profiles (slack_user_id, driver_name, email, phone) VALUES
('U08HRF3TM24', 'triable-sass.0u', 'driver@example.com', '+1234567890')
ON CONFLICT (slack_user_id) DO NOTHING;

INSERT INTO van_profiles (van_number, make, model, year, status) VALUES
(78, 'Ford', 'Transit', 2021, 'active'),
(99, 'Mercedes', 'Sprinter', 2022, 'active'),
(556, 'Ford', 'Transit', 2020, 'active'),
(123, 'Mercedes', 'Sprinter', 2021, 'active')
ON CONFLICT (van_number) DO NOTHING;

-- Step 4: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_van_profiles_van_number ON van_profiles(van_number);
CREATE INDEX IF NOT EXISTS idx_van_images_van_id ON van_images(van_id);
CREATE INDEX IF NOT EXISTS idx_van_images_van_number ON van_images(van_number);
CREATE INDEX IF NOT EXISTS idx_driver_profiles_slack_user_id ON driver_profiles(slack_user_id);

-- Step 5: Set up RLS policies safely
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE van_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE van_images ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist, then recreate
DROP POLICY IF EXISTS "Enable all for authenticated users" ON driver_profiles;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON van_profiles;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON van_images;

CREATE POLICY "Enable all for authenticated users" ON driver_profiles FOR ALL USING (true);
CREATE POLICY "Enable all for authenticated users" ON van_profiles FOR ALL USING (true);
CREATE POLICY "Enable all for authenticated users" ON van_images FOR ALL USING (true);

-- Step 6: Show final status
SELECT 
    'MIGRATION COMPLETE' as status,
    (SELECT COUNT(*) FROM driver_profiles) as driver_profiles_count,
    (SELECT COUNT(*) FROM van_profiles) as van_profiles_count,
    (SELECT COUNT(*) FROM van_images) as van_images_count; 
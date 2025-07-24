-- SAFE SCHEMA APPLICATION: Handles existing objects
-- Run this in Supabase Dashboard -> SQL Editor
-- This will create/update tables safely without conflicts

-- 1. Create driver_profiles table
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

-- 2. Create van_profiles table  
CREATE TABLE IF NOT EXISTS van_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_number INTEGER UNIQUE NOT NULL,
    make VARCHAR(50) DEFAULT 'Unknown',
    model VARCHAR(50) DEFAULT 'Unknown',
    year INTEGER,
    status VARCHAR(20) DEFAULT 'active',
    current_driver_id UUID REFERENCES driver_profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create van_images table (with van_number as nullable to fix Slack bot constraint)
CREATE TABLE IF NOT EXISTS van_images (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id UUID REFERENCES van_profiles(id) ON DELETE CASCADE,
    van_number INTEGER, -- Made nullable to fix constraint violation
    driver_profile_id UUID REFERENCES driver_profiles(id),
    driver_id UUID, -- Legacy field, kept for compatibility
    image_url TEXT,
    image_path VARCHAR(255),
    file_size BIGINT,
    content_type VARCHAR(100),
    van_damage TEXT DEFAULT 'No damage description',
    van_rating INTEGER,
    uploaded_by VARCHAR(50) DEFAULT 'slack_bot',
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    image_data TEXT -- Base64 image data for storage bypass
);

-- 4. Create van_assignments table
CREATE TABLE IF NOT EXISTS van_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id UUID REFERENCES van_profiles(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    unassigned_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_van_profiles_van_number ON van_profiles(van_number);
CREATE INDEX IF NOT EXISTS idx_van_images_van_id ON van_images(van_id);
CREATE INDEX IF NOT EXISTS idx_van_images_van_number ON van_images(van_number);
CREATE INDEX IF NOT EXISTS idx_driver_profiles_slack_user_id ON driver_profiles(slack_user_id);
CREATE INDEX IF NOT EXISTS idx_van_assignments_van_id ON van_assignments(van_id);
CREATE INDEX IF NOT EXISTS idx_van_assignments_driver_id ON van_assignments(driver_id);

-- 6. Enable RLS (Row Level Security)
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE van_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE van_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE van_assignments ENABLE ROW LEVEL SECURITY;

-- 7. Drop existing policies if they exist and recreate them
DROP POLICY IF EXISTS "Enable all for authenticated users" ON driver_profiles;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON van_profiles;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON van_images;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON van_assignments;

-- Create policies for authenticated users
CREATE POLICY "Enable all for authenticated users" ON driver_profiles
    FOR ALL USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Enable all for authenticated users" ON van_profiles
    FOR ALL USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Enable all for authenticated users" ON van_images
    FOR ALL USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Enable all for authenticated users" ON van_assignments
    FOR ALL USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

-- 8. Insert sample data (only if not exists)
INSERT INTO driver_profiles (slack_user_id, driver_name, email, phone, status) 
VALUES 
    ('U08HRF3TM24', 'triable-sass.0u', 'driver1@example.com', '+1234567890', 'active'),
    ('SAMPLE_USER_2', 'John Driver', 'john@example.com', '+1987654321', 'active'),
    ('SAMPLE_USER_3', 'Jane Smith', 'jane@example.com', '+1555666777', 'active')
ON CONFLICT (slack_user_id) DO NOTHING;

INSERT INTO van_profiles (van_number, make, model, year, status) 
VALUES 
    (78, 'Ford', 'Transit', 2020, 'active'),
    (99, 'Mercedes', 'Sprinter', 2021, 'active'),
    (556, 'Ford', 'Transit', 2019, 'active'),
    (123, 'Mercedes', 'Sprinter', 2022, 'active')
ON CONFLICT (van_number) DO NOTHING;

-- 9. Success message
SELECT 'SUCCESS: Database schema applied successfully! Flutter app should now work.' as status; 
-- IMMEDIATE FIX: Apply Essential Database Schema
-- Run this in Supabase Dashboard -> SQL Editor
-- This will create the minimum tables needed for the app to work

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

-- 3. Create van_images table
CREATE TABLE IF NOT EXISTS van_images (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id UUID REFERENCES van_profiles(id) ON DELETE CASCADE,
    van_number INTEGER, -- Made nullable to fix Slack bot constraint violation
    driver_id UUID REFERENCES driver_profiles(id),
    image_url TEXT,
    image_data TEXT, -- Base64 encoded image
    file_path VARCHAR(500),
    file_size BIGINT,
    content_type VARCHAR(100),
    van_damage TEXT DEFAULT 'No damage description',
    van_rating INTEGER DEFAULT 0,
    uploaded_by VARCHAR(50) DEFAULT 'slack_bot',
    location VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create van_assignments table
CREATE TABLE IF NOT EXISTS van_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id UUID REFERENCES van_profiles(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by VARCHAR(50) DEFAULT 'system',
    status VARCHAR(20) DEFAULT 'active',
    notes TEXT
);

-- 5. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_van_profiles_van_number ON van_profiles(van_number);
CREATE INDEX IF NOT EXISTS idx_van_images_van_id ON van_images(van_id);
CREATE INDEX IF NOT EXISTS idx_van_images_van_number ON van_images(van_number);
CREATE INDEX IF NOT EXISTS idx_driver_profiles_slack_user_id ON driver_profiles(slack_user_id);

-- 6. Enable Row Level Security
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE van_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE van_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE van_assignments ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS policies (allow all for now)
CREATE POLICY "Enable all for authenticated users" ON driver_profiles FOR ALL USING (true);
CREATE POLICY "Enable all for authenticated users" ON van_profiles FOR ALL USING (true);
CREATE POLICY "Enable all for authenticated users" ON van_images FOR ALL USING (true);
CREATE POLICY "Enable all for authenticated users" ON van_assignments FOR ALL USING (true);

-- 8. Insert sample data
INSERT INTO driver_profiles (slack_user_id, driver_name, email, phone) VALUES
    ('U08HRF3TM24', 'triable-sass.0u', 'driver1@example.com', '555-0001'),
    ('U123456789', 'John Smith', 'john@example.com', '555-0002'),
    ('U987654321', 'Sarah Johnson', 'sarah@example.com', '555-0003')
ON CONFLICT (slack_user_id) DO NOTHING;

INSERT INTO van_profiles (van_number, make, model, year, status) VALUES
    (78, 'Ford', 'Transit', 2022, 'active'),
    (99, 'Mercedes', 'Sprinter', 2023, 'active'),
    (556, 'Chevrolet', 'Express', 2021, 'active'),
    (123, 'Ford', 'Transit Connect', 2023, 'active')
ON CONFLICT (van_number) DO UPDATE SET
    make = EXCLUDED.make,
    model = EXCLUDED.model,
    year = EXCLUDED.year,
    status = EXCLUDED.status;

-- 9. Success message
SELECT 'SUCCESS: Essential database schema applied! Your app should now work.' as status; 
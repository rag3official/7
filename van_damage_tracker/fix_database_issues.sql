-- TARGETED DATABASE FIXES
-- Run this in Supabase SQL Editor to fix the 3 main issues

-- =============================================================================
-- FIX 1: Add missing uploaded_at column to van_images table
-- =============================================================================

-- Check if uploaded_at column exists, if not add it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'uploaded_at'
    ) THEN
        ALTER TABLE van_images ADD COLUMN uploaded_at TIMESTAMPTZ DEFAULT NOW();
        
        -- Copy existing updated_at values to uploaded_at for existing records
        UPDATE van_images SET uploaded_at = updated_at WHERE uploaded_at IS NULL;
        
        RAISE NOTICE 'Added uploaded_at column to van_images table';
    ELSE
        RAISE NOTICE 'uploaded_at column already exists in van_images table';
    END IF;
END $$;

-- =============================================================================
-- FIX 2: Ensure drivers table exists with correct structure
-- =============================================================================

CREATE TABLE IF NOT EXISTS drivers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    employee_id TEXT UNIQUE,
    phone TEXT,
    email TEXT,
    license_number TEXT,
    license_expiry DATE,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add sample drivers if table is empty
INSERT INTO drivers (name, employee_id, phone, email, license_number, license_expiry, status)
SELECT * FROM (VALUES
    ('John Smith', 'EMP001', '+1-555-0101', 'john.smith@company.com', 'DL123456789', '2025-12-31', 'active'),
    ('Sarah Johnson', 'EMP002', '+1-555-0102', 'sarah.johnson@company.com', 'DL987654321', '2025-11-15', 'active'),
    ('Mike Davis', 'EMP003', '+1-555-0103', 'mike.davis@company.com', 'DL456789123', '2025-10-20', 'active'),
    ('Alex Wilson', 'EMP004', '+1-555-0104', 'alex.wilson@company.com', 'DL789123456', '2025-09-30', 'active'),
    ('Emma Brown', 'EMP005', '+1-555-0105', 'emma.brown@company.com', 'DL321654987', '2025-08-25', 'active')
) AS new_drivers(name, employee_id, phone, email, license_number, license_expiry, status)
WHERE NOT EXISTS (SELECT 1 FROM drivers);

-- =============================================================================
-- FIX 3: Add realistic sample images linked to your actual vans
-- =============================================================================

-- First, let's get some real van IDs from your database
-- and add sample images linked to them

-- Clear existing sample van_images if any exist with our test data
DELETE FROM van_images WHERE description LIKE '%Sample damage%';

-- Add sample images using real van IDs from your database
-- This uses the first 6 vans in your database
WITH real_vans AS (
    SELECT id, van_number, ROW_NUMBER() OVER (ORDER BY van_number) as rn
    FROM vans 
    LIMIT 6
),
sample_drivers AS (
    SELECT id, name, ROW_NUMBER() OVER (ORDER BY name) as rn
    FROM drivers
    LIMIT 5
)
INSERT INTO van_images (
    van_id, 
    image_url, 
    uploaded_by, 
    driver_id, 
    uploaded_at,
    description, 
    damage_type, 
    damage_level, 
    location
)
SELECT 
    rv.id,
    'https://example.com/images/van_' || rv.van_number || '_damage_' || (rv.rn % 3 + 1) || '.jpg',
    'system',
    sd.id,
    NOW() - INTERVAL '1 day' * (rv.rn * 2),
    'Sample damage report for van ' || rv.van_number,
    CASE rv.rn % 4 
        WHEN 0 THEN 'scratch'
        WHEN 1 THEN 'dent'
        WHEN 2 THEN 'paint_damage'
        ELSE 'minor_damage'
    END,
    (rv.rn % 5) + 1,
    CASE rv.rn % 5
        WHEN 0 THEN 'front_bumper'
        WHEN 1 THEN 'side_panel'
        WHEN 2 THEN 'rear_door'
        WHEN 3 THEN 'wheel_well'
        ELSE 'roof'
    END
FROM real_vans rv
CROSS JOIN sample_drivers sd
WHERE rv.rn <= 6 AND sd.rn = ((rv.rn % 5) + 1);

-- =============================================================================
-- CREATE/UPDATE the van_images_with_driver view
-- =============================================================================

-- Drop and recreate the view to ensure it works with current structure
DROP VIEW IF EXISTS van_images_with_driver;

CREATE VIEW van_images_with_driver AS
SELECT 
    vi.id,
    vi.van_id,
    vi.image_url,
    vi.uploaded_by,
    vi.uploaded_at,
    vi.description,
    vi.damage_type,
    vi.damage_level,
    vi.location,
    vi.driver_id,
    d.name as driver_name,
    d.employee_id as driver_employee_id,
    d.phone as driver_phone,
    d.email as driver_email,
    v.van_number
FROM van_images vi
LEFT JOIN drivers d ON vi.driver_id = d.id
LEFT JOIN vans v ON vi.van_id = v.id;

-- =============================================================================
-- Add indexes for better performance
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_van_images_van_id ON van_images(van_id);
CREATE INDEX IF NOT EXISTS idx_van_images_driver_id ON van_images(driver_id);
CREATE INDEX IF NOT EXISTS idx_van_images_uploaded_at ON van_images(uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_drivers_employee_id ON drivers(employee_id);

-- =============================================================================
-- Verification queries
-- =============================================================================

SELECT 'FIX VERIFICATION:' as status;

SELECT 'Van Images Table Structure:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'van_images' 
ORDER BY ordinal_position;

SELECT 'Sample Data Count:' as info;
SELECT 
    COUNT(*) as total_images,
    COUNT(DISTINCT van_id) as vans_with_images,
    COUNT(DISTINCT driver_id) as drivers_with_images
FROM van_images;

SELECT 'View Test:' as info;
SELECT COUNT(*) as view_records FROM van_images_with_driver;

SELECT 'Recent Images:' as info;
SELECT 
    v.van_number,
    d.name as driver_name,
    vi.damage_level,
    vi.location,
    vi.uploaded_at::date as upload_date
FROM van_images_with_driver vi
JOIN vans v ON vi.van_id = v.id
LEFT JOIN drivers d ON vi.driver_id = d.id
ORDER BY vi.uploaded_at DESC
LIMIT 5; 
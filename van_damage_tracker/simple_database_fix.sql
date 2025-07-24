-- SIMPLE DATABASE FIX - Works with existing table structures
-- Run this in Supabase SQL Editor

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
-- FIX 2: Ensure drivers table has basic data (work with existing structure)
-- =============================================================================

-- Only insert basic drivers if the table is empty (using only guaranteed columns)
INSERT INTO drivers (name)
SELECT * FROM (VALUES
    ('John Smith'),
    ('Sarah Johnson'),
    ('Mike Davis'),
    ('Alex Wilson'),
    ('Emma Brown')
) AS new_drivers(name)
WHERE NOT EXISTS (SELECT 1 FROM drivers)
ON CONFLICT DO NOTHING;

-- =============================================================================
-- FIX 3: Add sample images linked to your actual vans
-- =============================================================================

-- Clear any existing sample van_images 
DELETE FROM van_images WHERE description LIKE '%Sample damage%';

-- Add sample images using real van IDs from your database
WITH real_vans AS (
    SELECT id, van_number, ROW_NUMBER() OVER (ORDER BY van_number) as rn
    FROM vans 
    LIMIT 6
),
available_drivers AS (
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
    'https://example.com/images/van_' || rv.van_number || '_damage.jpg',
    'system',
    ad.id,
    NOW() - INTERVAL '1 day' * rv.rn,
    'Sample damage report for van ' || rv.van_number,
    CASE rv.rn % 3 
        WHEN 0 THEN 'scratch'
        WHEN 1 THEN 'dent'
        ELSE 'paint_damage'
    END,
    (rv.rn % 5) + 1,
    CASE rv.rn % 4
        WHEN 0 THEN 'front_bumper'
        WHEN 1 THEN 'side_panel'
        WHEN 2 THEN 'rear_door'
        ELSE 'wheel_well'
    END
FROM real_vans rv
CROSS JOIN available_drivers ad
WHERE rv.rn <= 3 AND ad.rn <= 3; -- Limit to avoid too many sample records

-- =============================================================================
-- FIX 4: CREATE/UPDATE the van_images_with_driver view
-- =============================================================================

-- Drop and recreate the view
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
    COALESCE(d.name, 'Unknown') as driver_employee_id,
    COALESCE(d.name, 'N/A') as driver_phone,
    COALESCE(d.name, 'N/A') as driver_email,
    v.van_number
FROM van_images vi
LEFT JOIN drivers d ON vi.driver_id = d.id
LEFT JOIN vans v ON vi.van_id = v.id;

-- =============================================================================
-- Verification
-- =============================================================================

SELECT 'SIMPLE FIX COMPLETE!' as status;

SELECT 'Uploaded_at column check:' as info;
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'van_images' AND column_name = 'uploaded_at'
        ) THEN 'uploaded_at column EXISTS ✓'
        ELSE 'uploaded_at column MISSING ✗'
    END as uploaded_at_status;

SELECT 'Sample data summary:' as info;
SELECT 
    COUNT(*) as total_images,
    COUNT(DISTINCT van_id) as vans_with_images,
    COUNT(DISTINCT driver_id) as unique_drivers
FROM van_images;

SELECT 'View check:' as info;
SELECT COUNT(*) as view_record_count 
FROM van_images_with_driver; 
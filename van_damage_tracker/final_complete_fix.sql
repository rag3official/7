-- FINAL COMPLETE FIX: Add all missing columns to van_images table
-- Run this in Supabase Dashboard -> SQL Editor

-- 1. Add missing columns to van_images table that Flutter expects
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_level INTEGER DEFAULT 0;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_type TEXT;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS driver_name TEXT;

-- 2. Copy data from existing columns to new Flutter-expected columns
UPDATE van_images SET damage_level = van_rating WHERE damage_level IS NULL OR damage_level = 0;
UPDATE van_images SET damage_type = van_damage WHERE damage_type IS NULL;
UPDATE van_images SET uploaded_at = created_at WHERE uploaded_at IS NULL;
UPDATE van_images SET location = 'general' WHERE location IS NULL;

-- 3. Create the vans view that Flutter expects (using only columns that exist in van_profiles)
DROP VIEW IF EXISTS vans;
CREATE VIEW vans AS
SELECT 
    id,
    van_number,
    make,
    model,
    year,
    status,
    current_driver_id,
    created_at,
    updated_at,
    -- Add default values for columns that don't exist in van_profiles but are expected by Flutter
    NULL as color,
    NULL as license_plate,
    NULL as vin,
    NULL as location,
    NULL as mileage,
    NULL as fuel_level,
    NULL as last_maintenance_date,
    NULL as next_maintenance_due,
    NULL as insurance_expiry,
    NULL as registration_expiry,
    NULL as notes
FROM van_profiles;

-- 4. Grant necessary permissions on the view
GRANT SELECT ON vans TO authenticated;
GRANT SELECT ON vans TO anon;

-- 5. Update image_url column to use image_data for base64 images
UPDATE van_images 
SET image_url = CASE 
    WHEN image_data IS NOT NULL AND image_data != '' AND image_url IS NULL THEN 
        CONCAT('data:', content_type, ';base64,', image_data)
    ELSE image_url
END
WHERE image_data IS NOT NULL AND image_data != '';

-- 6. Verify the fix by checking if we have data
SELECT 
    'Van Profiles Count:' as check_type, 
    COUNT(*)::text as count 
FROM van_profiles
UNION ALL
SELECT 
    'Van Images Count:' as check_type, 
    COUNT(*)::text as count 
FROM van_images
UNION ALL
SELECT 
    'Vans View Count:' as check_type, 
    COUNT(*)::text as count 
FROM vans
UNION ALL
SELECT 
    'Van Images with Base64:' as check_type, 
    COUNT(*)::text as count 
FROM van_images 
WHERE image_data IS NOT NULL AND image_data != ''
UNION ALL
SELECT 
    'Van Images with location:' as check_type, 
    COUNT(*)::text as count 
FROM van_images 
WHERE location IS NOT NULL
UNION ALL
SELECT 
    'Van Images with damage_level:' as check_type, 
    COUNT(*)::text as count 
FROM van_images 
WHERE damage_level IS NOT NULL;

-- Success message
SELECT 'SUCCESS: All missing columns added! Flutter app should now display Slack bot uploaded images.' as status; 
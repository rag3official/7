-- COMPLETE DATABASE FIX: Add all missing columns to van_images table
-- This will make the Flutter app work with the Slack bot's stored images
-- Run this in Supabase Dashboard -> SQL Editor

-- 1. Add ALL missing columns that the Flutter app expects
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_level INTEGER DEFAULT 0;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_type TEXT;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS driver_name TEXT;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS uploaded_by TEXT DEFAULT 'slack_bot';

-- 2. Copy data from existing Slack bot columns to Flutter-expected columns
UPDATE van_images SET damage_level = van_rating WHERE damage_level IS NULL OR damage_level = 0;
UPDATE van_images SET damage_type = van_damage WHERE damage_type IS NULL;
UPDATE van_images SET uploaded_at = created_at WHERE uploaded_at IS NULL;
UPDATE van_images SET location = 'general' WHERE location IS NULL;
UPDATE van_images SET description = van_damage WHERE description IS NULL;
UPDATE van_images SET uploaded_by = 'slack_bot' WHERE uploaded_by IS NULL;

-- 3. Create the vans view that Flutter expects (maps van_profiles to vans)
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

-- 5. Ensure image_url is properly set for base64 images
UPDATE van_images 
SET image_url = CASE 
    WHEN image_data IS NOT NULL AND image_data != '' AND (image_url IS NULL OR image_url = '') THEN 
        CONCAT('data:', COALESCE(content_type, 'image/jpeg'), ';base64,', image_data)
    ELSE image_url
END
WHERE image_data IS NOT NULL AND image_data != '';

-- 6. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_van_images_van_id ON van_images(van_id);
CREATE INDEX IF NOT EXISTS idx_van_images_uploaded_at ON van_images(uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_van_images_damage_level ON van_images(damage_level);

-- 7. Success message
SELECT 'SUCCESS: Database schema updated! Flutter app can now display Slack bot images!' as status;

-- 8. Show a sample of the data to verify
SELECT 
    van_number,
    damage_type,
    damage_level,
    location,
    description,
    uploaded_by,
    CASE 
        WHEN LENGTH(image_url) > 50 THEN CONCAT(LEFT(image_url, 50), '...')
        ELSE image_url
    END as image_url_preview
FROM van_images 
ORDER BY created_at DESC 
LIMIT 5; 
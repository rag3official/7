-- FIX UPLOADED_BY FIELD: Update to show actual driver names instead of 'slack_bot'
-- Run this in Supabase Dashboard -> SQL Editor

-- 1. First, let's see what data we have
SELECT 
    vi.id,
    vi.van_number,
    vi.uploaded_by,
    dp.driver_name,
    dp.slack_user_id,
    vi.created_at
FROM van_images vi
LEFT JOIN driver_profiles dp ON vi.driver_id = dp.id
WHERE vi.uploaded_by = 'slack_bot'
ORDER BY vi.created_at DESC;

-- 2. Update uploaded_by field to use actual driver names
UPDATE van_images 
SET uploaded_by = dp.driver_name
FROM driver_profiles dp
WHERE van_images.driver_id = dp.id 
AND van_images.uploaded_by = 'slack_bot'
AND dp.driver_name IS NOT NULL;

-- 3. For any records that still have 'slack_bot' but have a slack_user_id, 
-- try to find the driver by slack_user_id
UPDATE van_images 
SET uploaded_by = dp.driver_name
FROM driver_profiles dp
WHERE van_images.slack_user_id = dp.slack_user_id 
AND van_images.uploaded_by = 'slack_bot'
AND dp.driver_name IS NOT NULL;

-- 4. Add the missing columns that the Flutter app expects (if not already added)
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_level INTEGER DEFAULT 0;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_type TEXT;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS location TEXT DEFAULT 'general';
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS driver_name TEXT;

-- 5. Copy data from existing columns to new Flutter-expected columns
UPDATE van_images SET damage_level = van_rating WHERE damage_level IS NULL OR damage_level = 0;
UPDATE van_images SET damage_type = van_damage WHERE damage_type IS NULL;
UPDATE van_images SET uploaded_at = created_at WHERE uploaded_at IS NULL;
UPDATE van_images SET description = van_damage WHERE description IS NULL;

-- 6. Update driver_name field with the actual driver name for easy access
UPDATE van_images 
SET driver_name = dp.driver_name
FROM driver_profiles dp
WHERE van_images.driver_id = dp.id 
AND dp.driver_name IS NOT NULL;

-- 7. For records without driver_id but with slack_user_id, try to find driver
UPDATE van_images 
SET driver_name = dp.driver_name,
    driver_id = dp.id
FROM driver_profiles dp
WHERE van_images.slack_user_id = dp.slack_user_id 
AND van_images.driver_id IS NULL
AND dp.driver_name IS NOT NULL;

-- 8. Show the results
SELECT 
    vi.van_number,
    vi.uploaded_by,
    vi.driver_name,
    vi.damage_type,
    vi.damage_level,
    vi.location,
    CASE 
        WHEN LENGTH(vi.image_url) > 50 THEN CONCAT(LEFT(vi.image_url, 50), '...')
        WHEN LENGTH(vi.image_data) > 50 THEN 'Base64 image data available'
        ELSE vi.image_url
    END as image_preview,
    vi.created_at
FROM van_images vi
ORDER BY vi.created_at DESC
LIMIT 10;

-- 9. Success message
SELECT 'SUCCESS: Updated uploaded_by field to show actual driver names!' as status;

-- 10. Instructions for the Slack bot code fix
SELECT 'SLACK BOT FIX NEEDED: Change uploaded_by from "slack_bot" to driver_profile["driver_name"]' as next_step; 
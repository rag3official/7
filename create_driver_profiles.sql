
-- Create driver_profiles table if it doesn't exist
CREATE TABLE IF NOT EXISTS driver_profiles (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    slack_user_id TEXT UNIQUE NOT NULL,
    slack_username TEXT,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    license_number TEXT,
    license_expiry DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create driver_van_assignments table to track which van a driver used each day
CREATE TABLE IF NOT EXISTS driver_van_assignments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    driver_id UUID REFERENCES driver_profiles(id),
    van_id UUID REFERENCES vans(id),
    assignment_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(driver_id, assignment_date)
);

-- Create driver_images table to link images to drivers
CREATE TABLE IF NOT EXISTS driver_images (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    driver_id UUID REFERENCES driver_profiles(id),
    van_image_id UUID REFERENCES van_images(id),
    van_id UUID REFERENCES vans(id),
    image_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_driver_van_assignments_date ON driver_van_assignments(assignment_date);
CREATE INDEX IF NOT EXISTS idx_driver_images_date ON driver_images(image_date);
CREATE INDEX IF NOT EXISTS idx_slack_user_id ON driver_profiles(slack_user_id);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_driver_profiles_updated_at
    BEFORE UPDATE ON driver_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add helpful views for common queries
CREATE VIEW active_driver_assignments AS
SELECT 
    dp.slack_username,
    dp.slack_user_id,
    v.van_number,
    dva.assignment_date,
    dva.start_time,
    dva.status
FROM driver_van_assignments dva
JOIN driver_profiles dp ON dp.id = dva.driver_id
JOIN vans v ON v.id = dva.van_id
WHERE dva.status = 'active'
ORDER BY dva.assignment_date DESC;

CREATE VIEW driver_upload_summary AS
SELECT 
    dp.slack_username,
    v.van_number,
    COUNT(du.id) as total_uploads,
    MAX(du.upload_timestamp) as last_upload
FROM driver_profiles dp
JOIN driver_uploads du ON du.driver_id = dp.id
JOIN van_images vi ON vi.id = du.van_image_id
JOIN vans v ON v.id = vi.van_id
GROUP BY dp.slack_username, v.van_number
ORDER BY MAX(du.upload_timestamp) DESC;

-- Sample insert statements for testing
COMMENT ON TABLE driver_profiles IS 'Stores basic information about drivers from Slack';
COMMENT ON TABLE driver_van_assignments IS 'Tracks which driver is assigned to which van on which date';
COMMENT ON TABLE driver_images IS 'Links drivers to their uploaded van images';

-- Example queries:

/*
-- Get all images uploaded by a specific driver
SELECT vi.* 
FROM driver_uploads du
JOIN van_images vi ON vi.id = du.van_image_id
WHERE du.driver_id = 'driver_uuid_here';

-- Get driver assignment history for a specific van
SELECT dp.slack_username, dva.* 
FROM driver_van_assignments dva
JOIN driver_profiles dp ON dp.id = dva.driver_id
WHERE dva.van_id = 'van_uuid_here'
ORDER BY dva.assignment_date DESC;

-- Get all active drivers and their current van assignments
SELECT * FROM active_driver_assignments;

-- Get upload statistics by driver
SELECT * FROM driver_upload_summary;
*/

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
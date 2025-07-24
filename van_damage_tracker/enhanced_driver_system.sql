-- ENHANCED DRIVER PROFILE SYSTEM
-- Complete implementation for driver-van image tracking with navigation
-- Run this in Supabase Dashboard -> SQL Editor

BEGIN;

-- =============================================================================
-- 1. ENHANCE DRIVER_PROFILES TABLE
-- =============================================================================

-- Add missing columns for enhanced Slack user tracking
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS slack_real_name TEXT;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS slack_display_name TEXT;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS slack_username TEXT;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS total_uploads INTEGER DEFAULT 0;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS last_upload_date TIMESTAMPTZ;

-- Update existing driver names to use proper Slack display names
-- (This will be handled by the Slack bot going forward)

-- =============================================================================
-- 2. ENHANCE VAN_IMAGES TABLE FOR PROPER ATTRIBUTION
-- =============================================================================

-- Add missing columns that Flutter expects
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_level INTEGER DEFAULT 0;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_type TEXT;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS location TEXT DEFAULT 'exterior';
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS driver_name TEXT;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS slack_channel_id TEXT;

-- Copy data from existing columns to new Flutter-expected columns
UPDATE van_images SET damage_level = van_rating WHERE damage_level IS NULL OR damage_level = 0;
UPDATE van_images SET damage_type = van_damage WHERE damage_type IS NULL;
UPDATE van_images SET uploaded_at = created_at WHERE uploaded_at IS NULL;
UPDATE van_images SET description = van_damage WHERE description IS NULL;

-- Update uploaded_by and driver_name to use actual driver names instead of 'slack_bot'
UPDATE van_images 
SET uploaded_by = dp.driver_name,
    driver_name = dp.driver_name
FROM driver_profiles dp
WHERE van_images.driver_id = dp.id 
AND dp.driver_name IS NOT NULL;

-- For records without driver_id but with slack_user_id, link them
UPDATE van_images 
SET driver_name = dp.driver_name,
    driver_id = dp.id,
    uploaded_by = dp.driver_name
FROM driver_profiles dp
WHERE van_images.slack_user_id = dp.slack_user_id 
AND van_images.driver_id IS NULL
AND dp.driver_name IS NOT NULL;

-- =============================================================================
-- 3. CREATE ENHANCED VIEWS FOR DRIVER-VAN RELATIONSHIPS
-- =============================================================================

-- Driver Upload Summary View
CREATE OR REPLACE VIEW driver_upload_summary AS
SELECT 
    dp.id as driver_id,
    dp.driver_name,
    dp.slack_user_id,
    dp.slack_real_name,
    dp.slack_display_name,
    dp.slack_username,
    dp.email,
    dp.phone,
    dp.status,
    dp.created_at as member_since,
    
    -- Upload statistics
    COUNT(vi.id) as total_uploads,
    COUNT(DISTINCT vi.van_id) as vans_photographed,
    MAX(vi.uploaded_at) as last_upload_date,
    AVG(vi.van_rating) as avg_damage_rating,
    
    -- Van upload breakdown
    jsonb_agg(
        DISTINCT jsonb_build_object(
            'van_number', vi.van_number,
            'van_make', vp.make,
            'van_model', vp.model,
            'upload_count', (
                SELECT COUNT(*) 
                FROM van_images vi2 
                WHERE vi2.driver_id = dp.id 
                AND vi2.van_number = vi.van_number
            ),
            'last_upload', (
                SELECT MAX(uploaded_at) 
                FROM van_images vi3 
                WHERE vi3.driver_id = dp.id 
                AND vi3.van_number = vi.van_number
            ),
            'avg_rating', (
                SELECT AVG(van_rating) 
                FROM van_images vi4 
                WHERE vi4.driver_id = dp.id 
                AND vi4.van_number = vi.van_number
            )
        )
    ) FILTER (WHERE vi.id IS NOT NULL) as van_upload_summary
    
FROM driver_profiles dp
LEFT JOIN van_images vi ON dp.id = vi.driver_id
LEFT JOIN van_profiles vp ON vi.van_id = vp.id
GROUP BY dp.id, dp.driver_name, dp.slack_user_id, dp.slack_real_name, 
         dp.slack_display_name, dp.slack_username, dp.email, dp.phone, 
         dp.status, dp.created_at;

-- Van Driver History View
CREATE OR REPLACE VIEW van_driver_history AS
SELECT 
    vp.id as van_id,
    vp.van_number,
    vp.make as van_make,
    vp.model as van_model,
    vp.status as van_status,
    dp.id as driver_id,
    dp.driver_name,
    dp.slack_user_id,
    dp.slack_real_name,
    dp.email as driver_email,
    dp.phone as driver_phone,
    
    -- Upload statistics for this driver-van combination
    COUNT(vi.id) as upload_count,
    MIN(vi.uploaded_at) as first_upload,
    MAX(vi.uploaded_at) as last_upload,
    AVG(vi.van_rating) as avg_rating,
    
    -- Recent images (limit to 10 most recent)
    jsonb_agg(
        jsonb_build_object(
            'id', vi.id,
            'image_url', vi.image_url,
            'image_data', CASE 
                WHEN LENGTH(vi.image_data) > 50 THEN 'base64_available'
                ELSE vi.image_data
            END,
            'damage_description', vi.van_damage,
            'damage_type', vi.damage_type,
            'damage_level', vi.damage_level,
            'location', vi.location,
            'rating', vi.van_rating,
            'uploaded_at', vi.uploaded_at,
            'description', vi.description
        ) ORDER BY vi.uploaded_at DESC
    ) as images
    
FROM van_profiles vp
JOIN van_images vi ON vp.id = vi.van_id
JOIN driver_profiles dp ON vi.driver_id = dp.id
GROUP BY vp.id, vp.van_number, vp.make, vp.model, vp.status,
         dp.id, dp.driver_name, dp.slack_user_id, dp.slack_real_name,
         dp.email, dp.phone
ORDER BY vp.van_number, MAX(vi.uploaded_at) DESC;

-- Driver Images by Van View (for driver profile page)
CREATE OR REPLACE VIEW driver_images_by_van AS
SELECT 
    dp.id as driver_id,
    dp.driver_name,
    vp.van_number,
    vp.make as van_make,
    vp.model as van_model,
    vp.id as van_id,
    
    COUNT(vi.id) as image_count,
    MAX(vi.uploaded_at) as last_upload,
    AVG(vi.van_rating) as avg_rating,
    
    -- Recent images for thumbnails
    jsonb_agg(
        jsonb_build_object(
            'id', vi.id,
            'image_url', vi.image_url,
            'damage_level', vi.damage_level,
            'uploaded_at', vi.uploaded_at,
            'description', vi.description
        ) ORDER BY vi.uploaded_at DESC
    ) as images
    
FROM driver_profiles dp
JOIN van_images vi ON dp.id = vi.driver_id
JOIN van_profiles vp ON vi.van_id = vp.id
GROUP BY dp.id, dp.driver_name, vp.van_number, vp.make, vp.model, vp.id
ORDER BY dp.driver_name, MAX(vi.uploaded_at) DESC;

-- =============================================================================
-- 4. CREATE FUNCTIONS FOR ENHANCED QUERIES
-- =============================================================================

-- Function to get driver's uploads grouped by van (for Flutter app)
CREATE OR REPLACE FUNCTION get_driver_uploads_by_van(
    driver_slack_user_id text,
    limit_per_van int DEFAULT 20
) RETURNS TABLE (
    van_id uuid,
    van_number int,
    van_make text,
    van_model text,
    upload_count bigint,
    last_upload timestamptz,
    images jsonb
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vp.id as van_id,
        vp.van_number,
        vp.make as van_make,
        vp.model as van_model,
        COUNT(vi.id) as upload_count,
        MAX(vi.uploaded_at) as last_upload,
        jsonb_agg(
            jsonb_build_object(
                'id', vi.id,
                'image_url', vi.image_url,
                'damage_description', vi.van_damage,
                'damage_type', vi.damage_type,
                'damage_level', vi.damage_level,
                'location', vi.location,
                'van_rating', vi.van_rating,
                'uploaded_at', vi.uploaded_at,
                'description', vi.description
            ) ORDER BY vi.uploaded_at DESC
        ) as images
    FROM driver_profiles dp
    JOIN van_images vi ON dp.id = vi.driver_id
    JOIN van_profiles vp ON vi.van_id = vp.id
    WHERE dp.slack_user_id = driver_slack_user_id
    GROUP BY vp.id, vp.van_number, vp.make, vp.model
    ORDER BY MAX(vi.uploaded_at) DESC;
END;
$$;

-- Function to get van's images grouped by driver (for van profile page)
CREATE OR REPLACE FUNCTION get_van_images_by_driver(
    target_van_number int,
    image_limit int DEFAULT 50
) RETURNS TABLE (
    driver_id uuid,
    driver_name text,
    slack_user_id text,
    driver_email text,
    upload_count bigint,
    first_upload timestamptz,
    last_upload timestamptz,
    avg_rating numeric,
    images jsonb
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dp.id as driver_id,
        dp.driver_name,
        dp.slack_user_id,
        dp.email as driver_email,
        COUNT(vi.id) as upload_count,
        MIN(vi.uploaded_at) as first_upload,
        MAX(vi.uploaded_at) as last_upload,
        AVG(vi.van_rating) as avg_rating,
        jsonb_agg(
            jsonb_build_object(
                'id', vi.id,
                'image_url', vi.image_url,
                'damage_description', vi.van_damage,
                'damage_type', vi.damage_type,
                'damage_level', vi.damage_level,
                'location', vi.location,
                'van_rating', vi.van_rating,
                'uploaded_at', vi.uploaded_at,
                'description', vi.description
            ) ORDER BY vi.uploaded_at DESC
        ) as images
    FROM van_images vi
    JOIN driver_profiles dp ON vi.driver_id = dp.id
    WHERE vi.van_number = target_van_number
    GROUP BY dp.id, dp.driver_name, dp.slack_user_id, dp.email
    ORDER BY MAX(vi.uploaded_at) DESC;
END;
$$;

-- Function to update driver upload statistics (trigger function)
CREATE OR REPLACE FUNCTION update_driver_upload_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update driver's total uploads and last upload date
    UPDATE driver_profiles 
    SET 
        total_uploads = (
            SELECT COUNT(*) 
            FROM van_images 
            WHERE driver_id = NEW.driver_id
        ),
        last_upload_date = NEW.uploaded_at
    WHERE id = NEW.driver_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 5. CREATE TRIGGERS FOR AUTOMATIC STATISTICS UPDATES
-- =============================================================================

-- Trigger to update driver statistics when new image is uploaded
DROP TRIGGER IF EXISTS update_driver_stats_trigger ON van_images;
CREATE TRIGGER update_driver_stats_trigger
    AFTER INSERT ON van_images
    FOR EACH ROW
    EXECUTE FUNCTION update_driver_upload_stats();

-- =============================================================================
-- 6. UPDATE EXISTING DRIVER STATISTICS
-- =============================================================================

-- Update existing driver upload statistics
UPDATE driver_profiles 
SET 
    total_uploads = (
        SELECT COUNT(*) 
        FROM van_images 
        WHERE driver_id = driver_profiles.id
    ),
    last_upload_date = (
        SELECT MAX(uploaded_at) 
        FROM van_images 
        WHERE driver_id = driver_profiles.id
    );

-- =============================================================================
-- 7. CREATE INDEXES FOR PERFORMANCE
-- =============================================================================

-- Indexes for efficient driver-van queries
CREATE INDEX IF NOT EXISTS idx_van_images_driver_van ON van_images(driver_id, van_number);
CREATE INDEX IF NOT EXISTS idx_van_images_van_driver ON van_images(van_number, driver_id);
CREATE INDEX IF NOT EXISTS idx_van_images_uploaded_at ON van_images(uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_driver_profiles_slack_user ON driver_profiles(slack_user_id);
CREATE INDEX IF NOT EXISTS idx_driver_profiles_name ON driver_profiles(driver_name);

-- =============================================================================
-- 8. GRANT PERMISSIONS
-- =============================================================================

-- Grant permissions on new views and functions
GRANT SELECT ON driver_upload_summary TO authenticated, anon;
GRANT SELECT ON van_driver_history TO authenticated, anon;
GRANT SELECT ON driver_images_by_van TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_driver_uploads_by_van TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_van_images_by_driver TO authenticated, anon;

COMMIT;

-- =============================================================================
-- 9. VERIFICATION QUERIES
-- =============================================================================

-- Show driver upload summary
SELECT 
    driver_name,
    total_uploads,
    vans_photographed,
    last_upload_date,
    van_upload_summary
FROM driver_upload_summary
WHERE total_uploads > 0
ORDER BY last_upload_date DESC
LIMIT 5;

-- Show van driver history
SELECT 
    van_number,
    driver_name,
    upload_count,
    last_upload,
    avg_rating
FROM van_driver_history
ORDER BY van_number, last_upload DESC
LIMIT 10;

-- Test driver uploads function
SELECT * FROM get_driver_uploads_by_van('U08HRF3TM24', 10);

-- Test van images function  
SELECT * FROM get_van_images_by_driver(99, 20);

-- Success message
SELECT 'SUCCESS: Enhanced driver profile system implemented!' as status,
       'Features: Driver-van navigation, proper attribution, upload tracking' as features; 
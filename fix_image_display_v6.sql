-- Fix image display issues with proper data loading
-- Run this in Supabase Dashboard -> SQL Editor

BEGIN;

-- 1. Drop existing functions
DROP FUNCTION IF EXISTS get_van_images_batch(INTEGER[], INTEGER, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS get_latest_van_image(INTEGER) CASCADE;
DROP FUNCTION IF EXISTS save_van_image(INTEGER, TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;

-- 2. Create function to get van images with proper data
CREATE OR REPLACE FUNCTION get_van_images_batch(
    p_van_numbers INTEGER[],
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    van_number INTEGER,
    image_url TEXT,
    image_data TEXT,
    content_type TEXT,
    van_damage TEXT,
    van_rating INTEGER,
    van_side TEXT,
    damage_type TEXT,
    damage_severity TEXT,
    damage_location TEXT,
    created_at TIMESTAMPTZ,
    uploaded_at TIMESTAMPTZ,
    uploaded_by TEXT,
    driver_name TEXT,
    storage_type TEXT
) 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vi.id,
        vi.van_number,
        vi.image_url,
        vi.image_data,
        vi.content_type,
        vi.van_damage,
        vi.van_rating,
        vi.van_side,
        vi.damage_type,
        vi.damage_severity,
        vi.damage_location,
        vi.created_at,
        vi.uploaded_at,
        vi.uploaded_by,
        vi.driver_name,
        CASE 
            WHEN vi.image_data IS NOT NULL THEN 'base64'
            WHEN vi.image_url LIKE 'data:%' THEN 'data-url'
            ELSE 'storage-url'
        END as storage_type
    FROM van_images vi
    WHERE vi.van_number = ANY(p_van_numbers)
    ORDER BY COALESCE(vi.uploaded_at, vi.created_at) DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- 3. Create function to save van image
CREATE OR REPLACE FUNCTION save_van_image(
    p_van_number INTEGER,
    p_image_data TEXT,
    p_content_type TEXT DEFAULT 'image/jpeg',
    p_van_damage TEXT DEFAULT NULL,
    p_van_rating INTEGER DEFAULT NULL,
    p_van_side TEXT DEFAULT 'unknown',
    p_damage_type TEXT DEFAULT NULL,
    p_damage_severity TEXT DEFAULT NULL,
    p_damage_location TEXT DEFAULT NULL,
    p_uploaded_by TEXT DEFAULT 'flutter_app',
    p_driver_name TEXT DEFAULT NULL
) 
RETURNS UUID
SECURITY DEFINER 
SET search_path = public
AS $$
DECLARE
    v_van_id UUID;
    v_image_id UUID;
    v_image_url TEXT;
BEGIN
    -- Get van ID
    SELECT id INTO v_van_id FROM van_profiles WHERE van_number = p_van_number;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Van not found: %', p_van_number;
    END IF;
    
    -- Create data URL
    v_image_url := 'data:' || p_content_type || ';base64,' || p_image_data;
    
    -- Insert image record
    INSERT INTO van_images (
        van_id,
        van_number,
        image_data,
        content_type,
        image_url,
        van_damage,
        van_rating,
        van_side,
        damage_type,
        damage_severity,
        damage_location,
        uploaded_by,
        driver_name,
        upload_method,
        uploaded_at
    ) VALUES (
        v_van_id,
        p_van_number,
        p_image_data,
        p_content_type,
        v_image_url,
        p_van_damage,
        p_van_rating,
        p_van_side,
        p_damage_type,
        p_damage_severity,
        p_damage_location,
        p_uploaded_by,
        p_driver_name,
        'flutter_app',
        NOW()
    ) RETURNING id INTO v_image_id;
    
    RETURN v_image_id;
END;
$$ LANGUAGE plpgsql;

-- 4. Create function to get latest van image
CREATE OR REPLACE FUNCTION get_latest_van_image(p_van_number INTEGER)
RETURNS TABLE (
    id UUID,
    van_number INTEGER,
    image_url TEXT,
    image_data TEXT,
    content_type TEXT,
    van_damage TEXT,
    van_rating INTEGER,
    van_side TEXT,
    damage_type TEXT,
    damage_severity TEXT,
    damage_location TEXT,
    created_at TIMESTAMPTZ,
    uploaded_at TIMESTAMPTZ,
    uploaded_by TEXT,
    driver_name TEXT,
    storage_type TEXT
) 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vi.id,
        vi.van_number,
        vi.image_url,
        vi.image_data,
        vi.content_type,
        vi.van_damage,
        vi.van_rating,
        vi.van_side,
        vi.damage_type,
        vi.damage_severity,
        vi.damage_location,
        vi.created_at,
        vi.uploaded_at,
        vi.uploaded_by,
        vi.driver_name,
        CASE 
            WHEN vi.image_data IS NOT NULL THEN 'base64'
            WHEN vi.image_url LIKE 'data:%' THEN 'data-url'
            ELSE 'storage-url'
        END as storage_type
    FROM van_images vi
    WHERE vi.van_number = p_van_number
    ORDER BY COALESCE(vi.uploaded_at, vi.created_at) DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- 5. Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_van_images_batch(INTEGER[], INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_latest_van_image(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION save_van_image(INTEGER, TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- 6. Create index for better performance
CREATE INDEX IF NOT EXISTS idx_van_images_van_dates ON van_images(van_number, COALESCE(uploaded_at, created_at) DESC);

COMMIT;

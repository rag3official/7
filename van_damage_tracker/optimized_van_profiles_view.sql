-- Optimized Van Profiles View for Performance
-- This view aggregates van profile data with damage information to reduce query complexity

BEGIN;

-- Drop view if exists to avoid conflicts
DROP VIEW IF EXISTS public.optimized_van_profiles;

-- Create optimized van profiles view with aggregated damage data
CREATE VIEW public.optimized_van_profiles AS
SELECT 
    vp.id,
    vp.van_number,
    vp.make,
    vp.model,
    vp.year,
    vp.status,
    vp.current_driver_name,
    vp.driver_name,
    vp.notes,
    vp.created_at,
    vp.updated_at,
    vp.damage_description,
    vp.van_side,
    vp.uploaded_by,
    -- Aggregated damage information
    COALESCE(MAX(vi.van_rating), 0) as max_damage_rating,
    COALESCE(
        CASE 
            WHEN MAX(vi.van_rating) = 0 THEN 'No damage reported'
            WHEN MAX(vi.van_rating) = 1 THEN 'Minor damage detected'
            WHEN MAX(vi.van_rating) = 2 THEN 'Moderate damage detected'
            WHEN MAX(vi.van_rating) = 3 THEN 'Major damage detected'
            ELSE 'Damage status unknown'
        END, 
        'No damage reported'
    ) as aggregated_damage_description,
    -- Image count
    COUNT(vi.id) as image_count,
    -- Latest image info
    MAX(vi.created_at) as latest_image_date,
    -- Driver assignment info
    dp.id as driver_profile_id,
    dp.email as driver_email,
    dp.phone as driver_phone,
    dp.license_number as driver_license,
    dp.status as driver_status
FROM van_profiles vp
LEFT JOIN van_images vi ON vp.van_number = vi.van_number
LEFT JOIN driver_profiles dp ON vp.current_driver_name = dp.driver_name
GROUP BY 
    vp.id,
    vp.van_number,
    vp.make,
    vp.model,
    vp.year,
    vp.status,
    vp.current_driver_name,
    vp.driver_name,
    vp.notes,
    vp.created_at,
    vp.updated_at,
    vp.damage_description,
    vp.van_side,
    vp.uploaded_by,
    dp.id,
    dp.email,
    dp.phone,
    dp.license_number,
    dp.status;

-- Create index on van_number for faster joins
CREATE INDEX IF NOT EXISTS idx_van_images_van_number ON van_images(van_number);
CREATE INDEX IF NOT EXISTS idx_van_profiles_van_number ON van_profiles(van_number);
CREATE INDEX IF NOT EXISTS idx_driver_profiles_driver_name ON driver_profiles(driver_name);

-- Grant permissions
GRANT SELECT ON public.optimized_van_profiles TO authenticated;
GRANT SELECT ON public.optimized_van_profiles TO anon;

COMMIT;

-- Verify the view was created successfully
SELECT 'Optimized van profiles view created successfully' as status; 
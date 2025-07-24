-- Enhanced Driver-Van Image Linking System Setup
-- Run this script in your Supabase Dashboard SQL Editor

BEGIN;

-- Create van_profiles table
CREATE TABLE IF NOT EXISTS public.van_profiles (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    van_number int UNIQUE NOT NULL,
    make text DEFAULT 'Unknown',
    model text DEFAULT 'Unknown',
    year int,
    license_plate text,
    vin text,
    status text DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'retired')),
    current_driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE SET NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Enhance van_images table for driver linking
DO $$
BEGIN
    -- Add driver_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'driver_id'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE SET NULL;
        CREATE INDEX idx_van_images_driver_id ON public.van_images(driver_id);
    END IF;

    -- Add slack_user_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'slack_user_id'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN slack_user_id text;
        CREATE INDEX idx_van_images_slack_user_id ON public.van_images(slack_user_id);
    END IF;

    -- Add image_data column for base64 storage if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'image_data'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN image_data text;
    END IF;

    -- Make van_number nullable to fix Slack bot constraint violations
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'van_number' AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.van_images ALTER COLUMN van_number DROP NOT NULL;
    END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_van_profiles_van_number ON public.van_profiles(van_number);

-- Create driver images with van details view
CREATE OR REPLACE VIEW public.driver_images_with_van_details AS
SELECT 
    vi.id as image_id,
    vi.van_id,
    vi.van_number,
    vi.driver_id,
    vi.slack_user_id,
    vi.image_url,
    vi.image_data,
    vi.van_damage as damage_description,
    vi.van_rating as damage_rating,
    vi.created_at as uploaded_at,
    
    -- Driver details
    dp.driver_name,
    dp.slack_real_name,
    dp.slack_display_name,
    
    -- Van details for navigation
    vp.make as van_make,
    vp.model as van_model,
    vp.year as van_year,
    vp.status as van_status,
    
    -- For grouping images by van
    CONCAT(COALESCE(vp.make, 'Unknown'), ' ', COALESCE(vp.model, 'Van'), ' (#', vi.van_number, ')') as van_display_name
    
FROM public.van_images vi
JOIN public.driver_profiles dp ON vi.driver_id = dp.id
LEFT JOIN public.van_profiles vp ON vi.van_id = vp.id
ORDER BY vi.created_at DESC;

-- Function to link images to drivers
CREATE OR REPLACE FUNCTION public.link_images_to_drivers()
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
    updated_count int := 0;
BEGIN
    UPDATE public.van_images vi
    SET driver_id = dp.id,
        uploaded_by = COALESCE(dp.slack_real_name, dp.slack_display_name, dp.driver_name)
    FROM public.driver_profiles dp
    WHERE vi.slack_user_id = dp.slack_user_id
    AND vi.driver_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$;

-- Function to get driver's images grouped by van
CREATE OR REPLACE FUNCTION public.get_driver_images_by_van(
    p_driver_id uuid,
    p_limit_per_van int DEFAULT 10
) RETURNS TABLE (
    van_id uuid,
    van_number int,
    van_make text,
    van_model text,
    van_display_name text,
    image_count bigint,
    latest_upload timestamp with time zone,
    images jsonb
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(vp.id, gen_random_uuid()) as van_id,
        vi.van_number,
        COALESCE(vp.make, 'Unknown') as van_make,
        COALESCE(vp.model, 'Van') as van_model,
        CONCAT(COALESCE(vp.make, 'Unknown'), ' ', COALESCE(vp.model, 'Van'), ' (#', vi.van_number, ')') as van_display_name,
        COUNT(vi.id) as image_count,
        MAX(vi.created_at) as latest_upload,
        jsonb_agg(
            jsonb_build_object(
                'id', vi.id,
                'image_url', vi.image_url,
                'damage_description', vi.van_damage,
                'damage_rating', vi.van_rating,
                'uploaded_at', vi.created_at
            ) ORDER BY vi.created_at DESC
        ) as images
    FROM public.van_images vi
    LEFT JOIN public.van_profiles vp ON vi.van_id = vp.id
    WHERE vi.driver_id = p_driver_id
    GROUP BY vp.id, vi.van_number, vp.make, vp.model
    ORDER BY MAX(vi.created_at) DESC;
END;
$$;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON public.van_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.van_images TO authenticated;
GRANT SELECT ON public.driver_images_with_van_details TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_driver_images_by_van(uuid, int) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.link_images_to_drivers() TO authenticated;

-- Link existing images to drivers
SELECT public.link_images_to_drivers() as linked_images;

SELECT 'SUCCESS: Enhanced driver-van image linking system created!' as status;

COMMIT;

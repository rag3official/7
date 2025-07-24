-- Enhanced Driver-Van Image Linking System
-- This script creates proper relationships between driver_profiles, van_profiles, and van_images
-- Enables navigation between driver profiles and van profiles through images

BEGIN;

-- =============================================================================
-- 1. CREATE VAN_PROFILES TABLE
-- =============================================================================

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

CREATE INDEX IF NOT EXISTS idx_van_profiles_van_number ON public.van_profiles(van_number);
CREATE INDEX IF NOT EXISTS idx_van_profiles_current_driver ON public.van_profiles(current_driver_id);

-- =============================================================================
-- 2. ENHANCE VAN_IMAGES TABLE FOR DRIVER LINKING
-- =============================================================================

DO $$
BEGIN
    -- Add driver_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'driver_id'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE SET NULL;
        CREATE INDEX idx_van_images_driver_id ON public.van_images(driver_id);
        RAISE NOTICE 'Added driver_id column to van_images';
    END IF;

    -- Add slack_user_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'slack_user_id'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN slack_user_id text;
        CREATE INDEX idx_van_images_slack_user_id ON public.van_images(slack_user_id);
        RAISE NOTICE 'Added slack_user_id column to van_images';
    END IF;

    -- Add image_data column for base64 storage if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'image_data'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN image_data text;
        RAISE NOTICE 'Added image_data column to van_images';
    END IF;

    -- Add uploaded_by column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'uploaded_by'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN uploaded_by text DEFAULT 'slack_bot';
        RAISE NOTICE 'Added uploaded_by column to van_images';
    END IF;

    -- Add file_path column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'file_path'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN file_path text;
        RAISE NOTICE 'Added file_path column to van_images';
    END IF;

    -- Add file_size column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'file_size'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN file_size bigint;
        RAISE NOTICE 'Added file_size column to van_images';
    END IF;

    -- Add content_type column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'content_type'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN content_type text DEFAULT 'image/jpeg';
        RAISE NOTICE 'Added content_type column to van_images';
    END IF;

    -- Make van_number nullable to fix Slack bot constraint violations
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' AND column_name = 'van_number' AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.van_images ALTER COLUMN van_number DROP NOT NULL;
        RAISE NOTICE 'Made van_number nullable in van_images';
    END IF;
END $$;

-- =============================================================================
-- 3. CREATE DRIVER-VAN ASSIGNMENT TRACKING
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.driver_van_assignments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id uuid NOT NULL REFERENCES public.driver_profiles(id) ON DELETE CASCADE,
    van_id uuid NOT NULL REFERENCES public.van_profiles(id) ON DELETE CASCADE,
    van_number int NOT NULL,
    assigned_date date DEFAULT CURRENT_DATE,
    unassigned_date date,
    is_current boolean DEFAULT true,
    assignment_reason text,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_driver_van_assignments_driver_id ON public.driver_van_assignments(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_van_assignments_van_id ON public.driver_van_assignments(van_id);
CREATE INDEX IF NOT EXISTS idx_driver_van_assignments_current ON public.driver_van_assignments(is_current) WHERE is_current = true;

-- =============================================================================
-- 4. CREATE VIEWS FOR NAVIGATION
-- =============================================================================

-- Driver Profile Summary with Upload Statistics
CREATE OR REPLACE VIEW public.driver_profile_summary AS
SELECT 
    dp.id as driver_id,
    dp.slack_user_id,
    dp.driver_name,
    dp.email,
    dp.phone,
    dp.license_number,
    dp.hire_date,
    dp.status,
    dp.slack_real_name,
    dp.slack_display_name,
    dp.slack_username,
    dp.total_uploads,
    dp.last_upload_date,
    dp.created_at as member_since,
    dp.updated_at,
    
    -- Calculate upload statistics
    COALESCE(stats.total_images, 0) as total_images_uploaded,
    COALESCE(stats.unique_vans, 0) as vans_photographed,
    COALESCE(stats.recent_uploads, 0) as uploads_last_30_days,
    stats.avg_damage_rating,
    stats.last_image_upload
    
FROM public.driver_profiles dp
LEFT JOIN (
    SELECT 
        vi.driver_id,
        COUNT(*) as total_images,
        COUNT(DISTINCT vi.van_id) as unique_vans,
        COUNT(*) FILTER (WHERE vi.created_at >= NOW() - INTERVAL '30 days') as recent_uploads,
        AVG(vi.van_rating) as avg_damage_rating,
        MAX(vi.created_at) as last_image_upload
    FROM public.van_images vi
    WHERE vi.driver_id IS NOT NULL
    GROUP BY vi.driver_id
) stats ON dp.id = stats.driver_id;

-- Driver Images with Van Details (for driver profile page)
CREATE OR REPLACE VIEW public.driver_images_with_van_details AS
SELECT 
    vi.id as image_id,
    vi.van_id,
    vi.van_number,
    vi.driver_id,
    vi.slack_user_id,
    vi.image_url,
    vi.image_data,
    vi.file_path,
    vi.file_size,
    vi.content_type,
    vi.van_damage as damage_description,
    vi.van_rating as damage_rating,
    vi.uploaded_by,
    vi.created_at as uploaded_at,
    vi.updated_at,
    
    -- Driver details
    dp.driver_name,
    dp.slack_real_name,
    dp.slack_display_name,
    
    -- Van details for navigation
    vp.make as van_make,
    vp.model as van_model,
    vp.year as van_year,
    vp.status as van_status,
    vp.license_plate,
    
    -- For grouping images by van
    CONCAT(COALESCE(vp.make, 'Unknown'), ' ', COALESCE(vp.model, 'Van'), ' (#', vi.van_number, ')') as van_display_name
    
FROM public.van_images vi
JOIN public.driver_profiles dp ON vi.driver_id = dp.id
LEFT JOIN public.van_profiles vp ON vi.van_id = vp.id
ORDER BY vi.created_at DESC;

-- Van Images with Driver Details (for van profile page)
CREATE OR REPLACE VIEW public.van_images_with_driver_details AS
SELECT 
    vi.id as image_id,
    vi.van_id,
    vi.van_number,
    vi.driver_id,
    vi.image_url,
    vi.image_data,
    vi.van_damage as damage_description,
    vi.van_rating as damage_rating,
    vi.created_at as uploaded_at,
    
    -- Driver details for attribution
    dp.driver_name,
    dp.slack_real_name,
    dp.slack_display_name,
    dp.phone as driver_phone,
    dp.email as driver_email,
    
    -- Van details
    vp.make as van_make,
    vp.model as van_model,
    vp.year as van_year,
    vp.status as van_status
    
FROM public.van_images vi
LEFT JOIN public.driver_profiles dp ON vi.driver_id = dp.id
LEFT JOIN public.van_profiles vp ON vi.van_id = vp.id
ORDER BY vi.created_at DESC;

-- =============================================================================
-- 5. CREATE FUNCTIONS FOR COMMON OPERATIONS
-- =============================================================================

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
                'image_data', CASE WHEN LENGTH(COALESCE(vi.image_data, '')) > 100 THEN LEFT(vi.image_data, 100) || '...' ELSE vi.image_data END,
                'damage_description', vi.van_damage,
                'damage_rating', vi.van_rating,
                'uploaded_at', vi.created_at,
                'file_size', vi.file_size
            ) ORDER BY vi.created_at DESC
        ) as images
    FROM public.van_images vi
    LEFT JOIN public.van_profiles vp ON vi.van_id = vp.id
    WHERE vi.driver_id = p_driver_id
    GROUP BY vp.id, vi.van_number, vp.make, vp.model
    ORDER BY MAX(vi.created_at) DESC;
END;
$$;

-- Function to link images to drivers based on slack_user_id
CREATE OR REPLACE FUNCTION public.link_images_to_drivers()
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
    updated_count int := 0;
BEGIN
    -- Update van_images to link to driver_profiles based on slack_user_id
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

-- Function to update driver upload statistics
CREATE OR REPLACE FUNCTION public.update_driver_upload_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update total_uploads and last_upload_date in driver_profiles
    IF TG_OP = 'INSERT' AND NEW.driver_id IS NOT NULL THEN
        UPDATE public.driver_profiles 
        SET 
            total_uploads = COALESCE(total_uploads, 0) + 1,
            last_upload_date = NEW.created_at,
            updated_at = NOW()
        WHERE id = NEW.driver_id;
    ELSIF TG_OP = 'DELETE' AND OLD.driver_id IS NOT NULL THEN
        UPDATE public.driver_profiles 
        SET 
            total_uploads = GREATEST(COALESCE(total_uploads, 0) - 1, 0),
            updated_at = NOW()
        WHERE id = OLD.driver_id;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 6. CREATE TRIGGERS
-- =============================================================================

-- Create trigger for automatic driver stats updates
DROP TRIGGER IF EXISTS trigger_update_driver_upload_stats ON public.van_images;
CREATE TRIGGER trigger_update_driver_upload_stats
    AFTER INSERT OR DELETE ON public.van_images
    FOR EACH ROW
    EXECUTE FUNCTION public.update_driver_upload_stats();

-- =============================================================================
-- 7. GRANT PERMISSIONS
-- =============================================================================

-- Grant permissions on tables
GRANT SELECT, INSERT, UPDATE ON public.van_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.van_images TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.driver_van_assignments TO authenticated;

-- Grant permissions on views
GRANT SELECT ON public.driver_profile_summary TO authenticated, anon;
GRANT SELECT ON public.driver_images_with_van_details TO authenticated, anon;
GRANT SELECT ON public.van_images_with_driver_details TO authenticated, anon;

-- Grant permissions on functions
GRANT EXECUTE ON FUNCTION public.get_driver_images_by_van(uuid, int) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.link_images_to_drivers() TO authenticated;

-- =============================================================================
-- 8. INITIAL DATA LINKING
-- =============================================================================

-- Link existing images to drivers based on slack_user_id
DO $$
DECLARE
    linked_count int;
BEGIN
    SELECT public.link_images_to_drivers() INTO linked_count;
    RAISE NOTICE 'Linked % existing images to driver profiles', linked_count;
END $$;

-- =============================================================================
-- 9. SUCCESS MESSAGE
-- =============================================================================

SELECT 'SUCCESS: Enhanced driver-van image linking system created!' as status,
       'Now van images are properly linked to driver profiles for navigation' as description,
       'Use driver_images_with_van_details view for driver profile pages' as usage_note;

COMMIT; 
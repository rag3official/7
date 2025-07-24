-- CLEAN SLATE MIGRATION: Complete Van Fleet Management System
-- This script drops all existing tables and creates the new schema from scratch

-- Step 1: Drop all existing tables (in correct order to handle foreign keys)
DROP TABLE IF EXISTS public.van_images CASCADE;
DROP TABLE IF EXISTS public.van_assignments CASCADE;
DROP TABLE IF EXISTS public.van_profiles CASCADE;
DROP TABLE IF EXISTS public.driver_profiles CASCADE;
DROP TABLE IF EXISTS public.vans CASCADE;
DROP TABLE IF EXISTS public.vans_backup CASCADE;

-- Drop any existing views
DROP VIEW IF EXISTS public.driver_profile_summary CASCADE;
DROP VIEW IF EXISTS public.van_profile_summary CASCADE;

-- Drop any existing functions
DROP FUNCTION IF EXISTS public.slack_bot_upload_bypass(text, text, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.get_driver_images_by_van(text, int) CASCADE;

-- Step 2: Create new tables with proper structure

-- Driver Profiles Table
CREATE TABLE public.driver_profiles (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    slack_user_id text UNIQUE NOT NULL,
    driver_name text NOT NULL,
    email text,
    phone text,
    license_number text,
    hire_date date,
    status text DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Van Profiles Table
CREATE TABLE public.van_profiles (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    van_number int UNIQUE NOT NULL,
    make text,
    model text,
    year int,
    license_plate text,
    vin text,
    status text DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'retired')),
    current_driver_id uuid REFERENCES public.driver_profiles(id),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Van Images Table
CREATE TABLE public.van_images (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id uuid REFERENCES public.van_profiles(id) ON DELETE CASCADE,
    van_number int NOT NULL,
    driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE SET NULL,
    slack_user_id text,
    image_url text NOT NULL,
    file_path text NOT NULL,
    file_size bigint,
    content_type text DEFAULT 'image/jpeg',
    van_damage text,
    van_rating int CHECK (van_rating >= 0 AND van_rating <= 3),
    upload_method text DEFAULT 'slack_bot',
    upload_source text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Van Assignments Table (for tracking driver-van assignments over time)
CREATE TABLE public.van_assignments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id uuid REFERENCES public.van_profiles(id) ON DELETE CASCADE,
    driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE CASCADE,
    assigned_at timestamp with time zone DEFAULT now(),
    unassigned_at timestamp with time zone,
    assignment_reason text,
    notes text,
    created_at timestamp with time zone DEFAULT now()
);

-- Add foreign key constraint for van_number (after all tables are created)
ALTER TABLE public.van_images 
ADD CONSTRAINT van_images_van_number_fkey 
FOREIGN KEY (van_number) REFERENCES public.van_profiles(van_number) ON DELETE CASCADE;

-- Step 3: Create indexes for performance
CREATE INDEX idx_van_images_van_id ON public.van_images(van_id);
CREATE INDEX idx_van_images_driver_id ON public.van_images(driver_id);
CREATE INDEX idx_van_images_van_number ON public.van_images(van_number);
CREATE INDEX idx_van_images_created_at ON public.van_images(created_at DESC);
CREATE INDEX idx_van_images_slack_user ON public.van_images(slack_user_id);
CREATE INDEX idx_driver_slack_user ON public.driver_profiles(slack_user_id);
CREATE INDEX idx_van_assignments_van_id ON public.van_assignments(van_id);
CREATE INDEX idx_van_assignments_driver_id ON public.van_assignments(driver_id);
CREATE INDEX idx_van_assignments_assigned_at ON public.van_assignments(assigned_at DESC);

-- Step 4: Create views for easy querying
CREATE VIEW public.driver_profile_summary AS
SELECT 
    dp.*,
    COUNT(vi.id) as total_images_uploaded,
    COUNT(DISTINCT vi.van_id) as vans_photographed,
    MAX(vi.created_at) as last_upload_date
FROM public.driver_profiles dp
LEFT JOIN public.van_images vi ON dp.id = vi.driver_id
GROUP BY dp.id;

CREATE VIEW public.van_profile_summary AS
SELECT 
    vp.*,
    COUNT(vi.id) as total_images,
    AVG(vi.van_rating) as avg_rating,
    MAX(vi.created_at) as last_photo_date,
    dp.driver_name as current_driver_name
FROM public.van_profiles vp
LEFT JOIN public.van_images vi ON vp.id = vi.van_id
LEFT JOIN public.driver_profiles dp ON vp.current_driver_id = dp.id
GROUP BY vp.id, dp.driver_name;

-- Step 5: Enable Row Level Security
ALTER TABLE public.driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_assignments ENABLE ROW LEVEL SECURITY;

-- Create policies for service role access
CREATE POLICY "Service role can manage all data" ON public.driver_profiles
    FOR ALL USING (auth.role() = 'service_role');
    
CREATE POLICY "Service role can manage all data" ON public.van_profiles
    FOR ALL USING (auth.role() = 'service_role');
    
CREATE POLICY "Service role can manage all data" ON public.van_images
    FOR ALL USING (auth.role() = 'service_role');
    
CREATE POLICY "Service role can manage all data" ON public.van_assignments
    FOR ALL USING (auth.role() = 'service_role');

-- Step 6: Create the bot's upload function for new schema
CREATE OR REPLACE FUNCTION public.slack_bot_upload_bypass(
    bucket_name text,
    file_path text,
    file_data text,
    content_type text DEFAULT 'image/jpeg'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    file_size bigint;
    binary_data bytea;
    van_number_extracted int;
    van_record_id uuid;
    image_url text;
BEGIN
    -- Calculate file size
    binary_data := decode(file_data, 'base64');
    file_size := length(binary_data);
    
    -- Extract van number from file path (van_123/image.jpg -> 123)
    van_number_extracted := (regexp_match(file_path, 'van_(\d+)'))[1]::int;
    
    IF van_number_extracted IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Could not extract van number from file path',
            'method', 'path_parsing',
            'file_path', file_path
        );
    END IF;
    
    -- Check if van profile exists
    SELECT id INTO van_record_id 
    FROM public.van_profiles 
    WHERE van_number = van_number_extracted;
    
    IF van_record_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Van profile not found',
            'method', 'van_lookup',
            'van_number', van_number_extracted
        );
    END IF;
    
    -- Create image URL
    image_url := format('%s/storage/v1/object/public/%s/%s', 
                       current_setting('app.supabase_url', true), 
                       bucket_name, 
                       file_path);
    
    -- For now, just return success with metadata (actual storage upload handled by bot)
    RETURN jsonb_build_object(
        'success', true,
        'method', 'metadata_only',
        'file_path', file_path,
        'file_size', file_size,
        'content_type', content_type,
        'van_number', van_number_extracted,
        'image_url', image_url
    );
END;
$$;

-- Step 7: Create helper functions
CREATE OR REPLACE FUNCTION public.get_driver_images_by_van(
    driver_slack_user_id text,
    limit_per_van int DEFAULT 10
) RETURNS TABLE (
    van_id uuid,
    van_number int,
    van_make text,
    van_model text,
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
        jsonb_agg(
            jsonb_build_object(
                'id', vi.id,
                'image_url', vi.image_url,
                'van_damage', vi.van_damage,
                'van_rating', vi.van_rating,
                'created_at', vi.created_at
            ) ORDER BY vi.created_at DESC
        ) as images
    FROM public.driver_profiles dp
    JOIN public.van_images vi ON dp.id = vi.driver_id
    JOIN public.van_profiles vp ON vi.van_id = vp.id
    WHERE dp.slack_user_id = driver_slack_user_id
    GROUP BY vp.id, vp.van_number, vp.make, vp.model
    ORDER BY MAX(vi.created_at) DESC;
END;
$$;

-- Step 8: Create function to get van images with driver info
CREATE OR REPLACE FUNCTION public.get_van_images_with_drivers(
    target_van_number int,
    image_limit int DEFAULT 20
) RETURNS TABLE (
    image_id uuid,
    image_url text,
    van_damage text,
    van_rating int,
    driver_name text,
    driver_slack_id text,
    upload_date timestamp with time zone
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vi.id as image_id,
        vi.image_url,
        vi.van_damage,
        vi.van_rating,
        dp.driver_name,
        dp.slack_user_id as driver_slack_id,
        vi.created_at as upload_date
    FROM public.van_images vi
    JOIN public.driver_profiles dp ON vi.driver_id = dp.id
    WHERE vi.van_number = target_van_number
    ORDER BY vi.created_at DESC
    LIMIT image_limit;
END;
$$;

-- Final step: Print setup summary
DO $$
BEGIN
    RAISE NOTICE '=== CLEAN SLATE MIGRATION COMPLETE ===';
    RAISE NOTICE 'Tables created:';
    RAISE NOTICE '  - driver_profiles (for Slack user -> driver mapping)';
    RAISE NOTICE '  - van_profiles (enhanced van information)';
    RAISE NOTICE '  - van_images (complete image relationships)';
    RAISE NOTICE '  - van_assignments (driver-van assignment history)';
    RAISE NOTICE '';
    RAISE NOTICE 'Views created:';
    RAISE NOTICE '  - driver_profile_summary (driver stats)';
    RAISE NOTICE '  - van_profile_summary (van stats with current driver)';
    RAISE NOTICE '';
    RAISE NOTICE 'Functions created:';
    RAISE NOTICE '  - slack_bot_upload_bypass (for bot uploads)';
    RAISE NOTICE '  - get_driver_images_by_van (driver image history)';
    RAISE NOTICE '  - get_van_images_with_drivers (van image history)';
    RAISE NOTICE '';
    RAISE NOTICE 'Security: RLS enabled with service role policies';
    RAISE NOTICE 'Ready for profile-aware bot deployment!';
    RAISE NOTICE '=====================================';
END $$; 
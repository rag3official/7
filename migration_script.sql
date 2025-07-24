-- Migration Script: Transition to Profile-Based Van Fleet Management
-- This script safely migrates existing data to the new schema

-- Step 1: Check existing tables and backup data
DO $$
BEGIN
    -- Create backup of existing vans table if it exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vans') THEN
        CREATE TABLE IF NOT EXISTS vans_backup AS SELECT * FROM vans;
        RAISE NOTICE 'Backed up existing vans table to vans_backup';
    END IF;
END $$;

-- Step 2: Create new tables with proper structure
-- Driver Profiles Table
CREATE TABLE IF NOT EXISTS public.driver_profiles (
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

-- Van Profiles Table (NEW)
CREATE TABLE IF NOT EXISTS public.van_profiles (
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

-- Van Images Table (NEW)
CREATE TABLE IF NOT EXISTS public.van_images (
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
CREATE TABLE IF NOT EXISTS public.van_assignments (
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
DO $$
BEGIN
    -- Only add constraint if it doesn't already exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'van_images_van_number_fkey'
        AND table_name = 'van_images'
    ) THEN
        ALTER TABLE public.van_images 
        ADD CONSTRAINT van_images_van_number_fkey 
        FOREIGN KEY (van_number) REFERENCES public.van_profiles(van_number) ON DELETE CASCADE;
        
        RAISE NOTICE 'Added foreign key constraint van_images_van_number_fkey';
    END IF;
END $$;

-- Step 3: Migrate existing data from old vans table to new van_profiles
DO $$
DECLARE
    van_record RECORD;
BEGIN
    -- Check if old vans table exists and has data
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vans') THEN
        -- Migrate each van from old table to new van_profiles table
        FOR van_record IN SELECT * FROM vans LOOP
            INSERT INTO public.van_profiles (
                van_number,
                make,
                model,
                year,
                status,
                created_at
            ) VALUES (
                van_record.van_number,
                COALESCE(van_record.make, 'Unknown'),
                COALESCE(van_record.model, 'Unknown'),
                van_record.year,
                COALESCE(van_record.status, 'active'),
                COALESCE(van_record.created_at, now())
            ) ON CONFLICT (van_number) DO NOTHING;
        END LOOP;
        
        RAISE NOTICE 'Migrated data from vans table to van_profiles table';
    END IF;
END $$;

-- Step 4: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_van_images_van_id ON public.van_images(van_id);
CREATE INDEX IF NOT EXISTS idx_van_images_driver_id ON public.van_images(driver_id);
CREATE INDEX IF NOT EXISTS idx_van_images_van_number ON public.van_images(van_number);
CREATE INDEX IF NOT EXISTS idx_van_images_created_at ON public.van_images(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_van_images_slack_user ON public.van_images(slack_user_id);
CREATE INDEX IF NOT EXISTS idx_driver_slack_user ON public.driver_profiles(slack_user_id);
CREATE INDEX IF NOT EXISTS idx_van_assignments_van_id ON public.van_assignments(van_id);
CREATE INDEX IF NOT EXISTS idx_van_assignments_driver_id ON public.van_assignments(driver_id);
CREATE INDEX IF NOT EXISTS idx_van_assignments_assigned_at ON public.van_assignments(assigned_at DESC);

-- Step 5: Create views for easy querying
CREATE OR REPLACE VIEW public.driver_profile_summary AS
SELECT 
    dp.*,
    COUNT(vi.id) as total_images_uploaded,
    COUNT(DISTINCT vi.van_id) as vans_photographed,
    MAX(vi.created_at) as last_upload_date
FROM public.driver_profiles dp
LEFT JOIN public.van_images vi ON dp.id = vi.driver_id
GROUP BY dp.id;

CREATE OR REPLACE VIEW public.van_profile_summary AS
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

-- Step 6: Enable Row Level Security
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

-- Step 7: Update the bot's upload function to work with new schema
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

-- Step 8: Create helper functions
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

-- Final step: Print migration summary
DO $$
DECLARE
    van_count int;
    driver_count int;
    image_count int;
    assignment_count int;
BEGIN
    SELECT COUNT(*) INTO van_count FROM public.van_profiles;
    SELECT COUNT(*) INTO driver_count FROM public.driver_profiles;
    SELECT COUNT(*) INTO image_count FROM public.van_images;
    SELECT COUNT(*) INTO assignment_count FROM public.van_assignments;
    
    RAISE NOTICE '=== MIGRATION COMPLETE ===';
    RAISE NOTICE 'Van profiles: %', van_count;
    RAISE NOTICE 'Driver profiles: %', driver_count;
    RAISE NOTICE 'Image records: %', image_count;
    RAISE NOTICE 'Van assignments: %', assignment_count;
    RAISE NOTICE 'Tables created: driver_profiles, van_profiles, van_images, van_assignments';
    RAISE NOTICE 'Views created: driver_profile_summary, van_profile_summary';  
    RAISE NOTICE 'Functions updated: slack_bot_upload_bypass, get_driver_images_by_van';
    RAISE NOTICE '========================';
END $$; 
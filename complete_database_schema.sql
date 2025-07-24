-- Complete Database Schema for Van Fleet Management
-- Handles driver profiles, van profiles, and image uploads with proper relationships

-- 1. DRIVER PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.driver_profiles (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    slack_user_id text UNIQUE NOT NULL, -- Links to Slack user who uploaded
    driver_name text NOT NULL,
    email text,
    phone text,
    license_number text,
    hire_date date,
    status text DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- 2. VAN PROFILES TABLE (Enhanced)
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

-- 3. VAN IMAGES TABLE (Main image storage with all relationships)
CREATE TABLE IF NOT EXISTS public.van_images (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Relationships
    van_id uuid REFERENCES public.van_profiles(id) ON DELETE CASCADE,
    van_number int NOT NULL, -- Denormalized for easy querying
    driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE SET NULL,
    slack_user_id text, -- Links to who uploaded it
    
    -- Image details
    image_url text NOT NULL,
    file_path text NOT NULL, -- Path in storage bucket
    file_size bigint,
    content_type text DEFAULT 'image/jpeg',
    
    -- Van condition assessment
    van_damage text, -- Description of any damage observed
    van_rating int CHECK (van_rating >= 0 AND van_rating <= 3), -- 0-3 scale
    
    -- Metadata
    upload_method text DEFAULT 'slack_bot',
    upload_source text, -- e.g., 'slack_channel', 'mobile_app', etc.
    
    -- Timestamps
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    -- Indexes for performance
    CONSTRAINT van_images_van_number_fkey FOREIGN KEY (van_number) 
        REFERENCES public.van_profiles(van_number) ON DELETE CASCADE
);

-- 4. VAN ASSIGNMENTS TABLE (Track driver-van assignments over time)
CREATE TABLE IF NOT EXISTS public.van_assignments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id uuid REFERENCES public.van_profiles(id) ON DELETE CASCADE,
    driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE CASCADE,
    assigned_date timestamp with time zone DEFAULT now(),
    unassigned_date timestamp with time zone,
    is_current boolean DEFAULT true,
    notes text,
    created_at timestamp with time zone DEFAULT now()
);

-- 5. INDEXES for Performance
CREATE INDEX IF NOT EXISTS idx_van_images_van_id ON public.van_images(van_id);
CREATE INDEX IF NOT EXISTS idx_van_images_driver_id ON public.van_images(driver_id);
CREATE INDEX IF NOT EXISTS idx_van_images_van_number ON public.van_images(van_number);
CREATE INDEX IF NOT EXISTS idx_van_images_created_at ON public.van_images(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_van_images_slack_user ON public.van_images(slack_user_id);
CREATE INDEX IF NOT EXISTS idx_driver_slack_user ON public.driver_profiles(slack_user_id);
CREATE INDEX IF NOT EXISTS idx_van_assignments_current ON public.van_assignments(is_current) WHERE is_current = true;

-- 6. VIEWS for Easy Querying

-- Driver Profile with Image Counts
CREATE OR REPLACE VIEW public.driver_profile_summary AS
SELECT 
    dp.*,
    COUNT(vi.id) as total_images_uploaded,
    COUNT(DISTINCT vi.van_id) as vans_photographed,
    MAX(vi.created_at) as last_upload_date
FROM public.driver_profiles dp
LEFT JOIN public.van_images vi ON dp.id = vi.driver_id
GROUP BY dp.id;

-- Van Profile with Latest Images and Ratings
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

-- Recent Images by Driver (for driver profile page)
CREATE OR REPLACE VIEW public.recent_images_by_driver AS
SELECT 
    vi.*,
    vp.van_number,
    vp.make,
    vp.model,
    dp.driver_name,
    ROW_NUMBER() OVER (PARTITION BY vi.driver_id ORDER BY vi.created_at DESC) as image_rank
FROM public.van_images vi
JOIN public.van_profiles vp ON vi.van_id = vp.id
JOIN public.driver_profiles dp ON vi.driver_id = dp.id
ORDER BY vi.driver_id, vi.created_at DESC;

-- Recent Images by Van (for van profile page)
CREATE OR REPLACE VIEW public.recent_images_by_van AS
SELECT 
    vi.*,
    dp.driver_name,
    ROW_NUMBER() OVER (PARTITION BY vi.van_id ORDER BY vi.created_at DESC) as image_rank
FROM public.van_images vi
JOIN public.driver_profiles dp ON vi.driver_id = dp.id
ORDER BY vi.van_id, vi.created_at DESC;

-- 7. FUNCTIONS for Common Operations

-- Function to get driver's recent images grouped by van
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

-- Function to get van's recent images with driver info
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
    created_at timestamp with time zone
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
        vi.created_at
    FROM public.van_images vi
    JOIN public.driver_profiles dp ON vi.driver_id = dp.id
    WHERE vi.van_number = target_van_number
    ORDER BY vi.created_at DESC
    LIMIT image_limit;
END;
$$;

-- 8. ROW LEVEL SECURITY (Optional but recommended)
ALTER TABLE public.driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_assignments ENABLE ROW LEVEL SECURITY;

-- Allow service role full access
CREATE POLICY "Service role can manage all data" ON public.driver_profiles
    FOR ALL USING (auth.role() = 'service_role');
    
CREATE POLICY "Service role can manage all data" ON public.van_profiles
    FOR ALL USING (auth.role() = 'service_role');
    
CREATE POLICY "Service role can manage all data" ON public.van_images
    FOR ALL USING (auth.role() = 'service_role');
    
CREATE POLICY "Service role can manage all data" ON public.van_assignments
    FOR ALL USING (auth.role() = 'service_role'); 
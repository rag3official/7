-- UNIFIED DATABASE SCHEMA for Van Fleet Management
-- This schema works for both Slack bot and Flutter app
-- Ensures all constraints are properly handled

BEGIN;

-- =============================================================================
-- 1. DROP EXISTING TABLES AND RECREATE WITH PROPER CONSTRAINTS
-- =============================================================================

-- Drop tables in correct order to handle foreign keys
DROP TABLE IF EXISTS public.van_images CASCADE;
DROP TABLE IF EXISTS public.van_assignments CASCADE;
DROP TABLE IF EXISTS public.van_profiles CASCADE;
DROP TABLE IF EXISTS public.driver_profiles CASCADE;
DROP TABLE IF EXISTS public.vans CASCADE;

-- Drop any existing views and functions
DROP VIEW IF EXISTS public.driver_profile_summary CASCADE;
DROP VIEW IF EXISTS public.van_profile_summary CASCADE;
DROP FUNCTION IF EXISTS public.slack_bot_upload_bypass CASCADE;

-- =============================================================================
-- 2. CREATE CORE TABLES WITH UNIFIED SCHEMA
-- =============================================================================

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
    make text DEFAULT 'Unknown',
    model text DEFAULT 'Unknown',
    year int,
    license_plate text,
    vin text,
    status text DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'retired')),
    current_driver_id uuid REFERENCES public.driver_profiles(id),
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Van Images Table (with proper constraints and optional fields)
CREATE TABLE public.van_images (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Required relationships
    van_id uuid NOT NULL REFERENCES public.van_profiles(id) ON DELETE CASCADE,
    van_number int NOT NULL, -- Denormalized for easy querying
    
    -- Optional relationships (for Slack bot compatibility)
    driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE SET NULL,
    slack_user_id text,
    
    -- Image details (image_url OR image_data must be provided)
    image_url text,
    image_data text, -- Base64 encoded image data
    file_path text,
    file_size bigint,
    content_type text DEFAULT 'image/jpeg',
    
    -- Van condition assessment (optional)
    van_damage text DEFAULT 'No damage description',
    van_rating int CHECK (van_rating >= 0 AND van_rating <= 3),
    
    -- Metadata
    upload_method text DEFAULT 'slack_bot',
    upload_source text DEFAULT 'slack_channel',
    uploaded_by text DEFAULT 'slack_bot',
    
    -- Timestamps
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    uploaded_at timestamp with time zone DEFAULT now(),
    
    -- Ensure at least one image source is provided
    CONSTRAINT image_source_check CHECK (image_url IS NOT NULL OR image_data IS NOT NULL)
);

-- Add foreign key constraint for van_number
ALTER TABLE public.van_images 
ADD CONSTRAINT van_images_van_number_fkey 
FOREIGN KEY (van_number) REFERENCES public.van_profiles(van_number) ON DELETE CASCADE;

-- Van Assignments Table (for tracking driver-van assignments over time)
CREATE TABLE public.van_assignments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id uuid REFERENCES public.van_profiles(id) ON DELETE CASCADE,
    driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE CASCADE,
    assigned_at timestamp with time zone DEFAULT now(),
    unassigned_at timestamp with time zone,
    assignment_reason text,
    notes text,
    is_current boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);

-- =============================================================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- =============================================================================

CREATE INDEX idx_van_images_van_id ON public.van_images(van_id);
CREATE INDEX idx_van_images_driver_id ON public.van_images(driver_id);
CREATE INDEX idx_van_images_van_number ON public.van_images(van_number);
CREATE INDEX idx_van_images_created_at ON public.van_images(created_at DESC);
CREATE INDEX idx_van_images_slack_user ON public.van_images(slack_user_id);
CREATE INDEX idx_driver_slack_user ON public.driver_profiles(slack_user_id);
CREATE INDEX idx_van_assignments_van_id ON public.van_assignments(van_id);
CREATE INDEX idx_van_assignments_driver_id ON public.van_assignments(driver_id);
CREATE INDEX idx_van_assignments_current ON public.van_assignments(is_current) WHERE is_current = true;

-- =============================================================================
-- 4. CREATE VIEWS FOR EASY QUERYING
-- =============================================================================

-- Driver Profile Summary
CREATE VIEW public.driver_profile_summary AS
SELECT 
    dp.*,
    COUNT(vi.id) as total_images_uploaded,
    COUNT(DISTINCT vi.van_id) as vans_photographed,
    MAX(vi.created_at) as last_upload_date
FROM public.driver_profiles dp
LEFT JOIN public.van_images vi ON dp.id = vi.driver_id
GROUP BY dp.id;

-- Van Profile Summary
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

-- =============================================================================
-- 5. ENABLE ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE public.driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_assignments ENABLE ROW LEVEL SECURITY;

-- Create policies for service role access (allows Slack bot to work)
CREATE POLICY "Service role can manage all data" ON public.driver_profiles
    FOR ALL USING (auth.role() = 'service_role');
    
CREATE POLICY "Service role can manage all data" ON public.van_profiles
    FOR ALL USING (auth.role() = 'service_role');
    
CREATE POLICY "Service role can manage all data" ON public.van_images
    FOR ALL USING (auth.role() = 'service_role');
    
CREATE POLICY "Service role can manage all data" ON public.van_assignments
    FOR ALL USING (auth.role() = 'service_role');

-- Create policies for authenticated users (allows Flutter app to work)
CREATE POLICY "Authenticated users can read all data" ON public.driver_profiles
    FOR SELECT USING (auth.role() = 'authenticated');
    
CREATE POLICY "Authenticated users can read all data" ON public.van_profiles
    FOR SELECT USING (auth.role() = 'authenticated');
    
CREATE POLICY "Authenticated users can read all data" ON public.van_images
    FOR SELECT USING (auth.role() = 'authenticated');
    
CREATE POLICY "Authenticated users can read all data" ON public.van_assignments
    FOR SELECT USING (auth.role() = 'authenticated');

-- =============================================================================
-- 6. INSERT SAMPLE DATA FOR TESTING
-- =============================================================================

-- Insert sample driver profiles
INSERT INTO public.driver_profiles (slack_user_id, driver_name, email, status) VALUES
('U08HRF3TM24', 'triable-sass.0u', 'test@example.com', 'active'),
('SAMPLE_USER_1', 'John Smith', 'john@example.com', 'active'),
('SAMPLE_USER_2', 'Jane Doe', 'jane@example.com', 'active')
ON CONFLICT (slack_user_id) DO UPDATE SET
    driver_name = EXCLUDED.driver_name,
    email = EXCLUDED.email,
    updated_at = now();

-- Insert sample van profiles
INSERT INTO public.van_profiles (van_number, make, model, status) VALUES
(78, 'Ford', 'Transit', 'active'),
(99, 'Mercedes', 'Sprinter', 'active'),
(123, 'Ford', 'Transit', 'active'),
(556, 'Mercedes', 'Sprinter', 'active')
ON CONFLICT (van_number) DO UPDATE SET
    make = EXCLUDED.make,
    model = EXCLUDED.model,
    updated_at = now();

COMMIT;

-- =============================================================================
-- 7. VERIFICATION
-- =============================================================================

-- Check tables were created
SELECT 
    table_name, 
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name AND table_schema = 'public') as column_count
FROM information_schema.tables t
WHERE table_schema = 'public' 
AND table_name IN ('driver_profiles', 'van_profiles', 'van_images', 'van_assignments')
ORDER BY table_name;

-- Check sample data
SELECT 'driver_profiles' as table_name, count(*) as row_count FROM public.driver_profiles
UNION ALL
SELECT 'van_profiles', count(*) FROM public.van_profiles
UNION ALL  
SELECT 'van_images', count(*) FROM public.van_images
UNION ALL
SELECT 'van_assignments', count(*) FROM public.van_assignments
ORDER BY table_name; 
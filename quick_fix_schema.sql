-- Quick Fix Schema - Essential Tables Only
-- Run this in Supabase SQL Editor to fix the immediate issues

BEGIN;

-- =============================================================================
-- 1. CREATE ESSENTIAL TABLES
-- =============================================================================

-- Create driver_profiles table
CREATE TABLE IF NOT EXISTS public.driver_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slack_user_id TEXT UNIQUE,
    driver_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    license_number TEXT,
    license_expiry TIMESTAMPTZ,
    last_medical_check TIMESTAMPTZ,
    certifications TEXT[] DEFAULT '{}',
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create van_profiles table
CREATE TABLE IF NOT EXISTS public.van_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    van_number INTEGER UNIQUE NOT NULL,
    make TEXT DEFAULT 'Unknown',
    model TEXT DEFAULT 'Unknown',
    year INTEGER,
    status TEXT DEFAULT 'active',
    current_driver_id UUID REFERENCES public.driver_profiles(id),
    current_driver_name TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create van_images table
CREATE TABLE IF NOT EXISTS public.van_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    van_id UUID REFERENCES public.van_profiles(id),
    van_number INTEGER NOT NULL,
    driver_id UUID REFERENCES public.driver_profiles(id),
    slack_user_id TEXT,
    image_url TEXT,
    image_data TEXT, -- Base64 encoded image data
    file_path TEXT,
    file_size INTEGER,
    content_type TEXT DEFAULT 'image/jpeg',
    van_damage TEXT,
    van_rating INTEGER,
    uploaded_by TEXT DEFAULT 'slack_bot',
    slack_channel_id TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create van_assignments table
CREATE TABLE IF NOT EXISTS public.van_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    van_id UUID REFERENCES public.van_profiles(id),
    driver_id UUID REFERENCES public.driver_profiles(id),
    assigned_at TIMESTAMPTZ DEFAULT now(),
    unassigned_at TIMESTAMPTZ,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================================
-- 2. CREATE INDEXES FOR PERFORMANCE
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_driver_profiles_slack_user_id ON public.driver_profiles(slack_user_id);
CREATE INDEX IF NOT EXISTS idx_van_profiles_van_number ON public.van_profiles(van_number);
CREATE INDEX IF NOT EXISTS idx_van_images_van_id ON public.van_images(van_id);
CREATE INDEX IF NOT EXISTS idx_van_images_van_number ON public.van_images(van_number);
CREATE INDEX IF NOT EXISTS idx_van_assignments_van_id ON public.van_assignments(van_id);
CREATE INDEX IF NOT EXISTS idx_van_assignments_driver_id ON public.van_assignments(driver_id);

-- =============================================================================
-- 3. INSERT SAMPLE DATA FOR TESTING
-- =============================================================================

-- Insert sample driver
INSERT INTO public.driver_profiles (slack_user_id, driver_name, email, phone, status) 
VALUES 
    ('U08HRF3TM24', 'triable-sass.0u', 'driver@example.com', '+1234567890', 'active'),
    ('SAMPLE_USER_1', 'John Driver', 'john@example.com', '+1111111111', 'active'),
    ('SAMPLE_USER_2', 'Jane Driver', 'jane@example.com', '+2222222222', 'active')
ON CONFLICT (slack_user_id) DO NOTHING;

-- Insert sample vans
INSERT INTO public.van_profiles (van_number, make, model, year, status, current_driver_name) 
VALUES 
    (78, 'Ford', 'Transit', 2020, 'active', 'triable-sass.0u'),
    (99, 'Mercedes', 'Sprinter', 2021, 'active', 'triable-sass.0u'),
    (556, 'Ford', 'Transit', 2019, 'active', 'John Driver'),
    (123, 'Mercedes', 'Sprinter', 2022, 'active', 'Jane Driver')
ON CONFLICT (van_number) DO NOTHING;

-- =============================================================================
-- 4. ENABLE ROW LEVEL SECURITY (RLS) - BASIC
-- =============================================================================

ALTER TABLE public.driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_assignments ENABLE ROW LEVEL SECURITY;

-- Create permissive policies for now (can be restricted later)
CREATE POLICY IF NOT EXISTS "Allow all access to driver_profiles" ON public.driver_profiles FOR ALL USING (true);
CREATE POLICY IF NOT EXISTS "Allow all access to van_profiles" ON public.van_profiles FOR ALL USING (true);
CREATE POLICY IF NOT EXISTS "Allow all access to van_images" ON public.van_images FOR ALL USING (true);
CREATE POLICY IF NOT EXISTS "Allow all access to van_assignments" ON public.van_assignments FOR ALL USING (true);

COMMIT;

-- =============================================================================
-- 5. VERIFICATION QUERIES
-- =============================================================================

-- Check that tables exist and have data
SELECT 'driver_profiles' as table_name, count(*) as record_count FROM public.driver_profiles
UNION ALL
SELECT 'van_profiles', count(*) FROM public.van_profiles  
UNION ALL
SELECT 'van_images', count(*) FROM public.van_images
UNION ALL
SELECT 'van_assignments', count(*) FROM public.van_assignments;

-- Test join query (what Flutter app will use)
SELECT 
    vp.van_number, 
    vp.make, 
    vp.model, 
    vp.current_driver_name,
    dp.driver_name,
    COUNT(vi.id) as image_count
FROM public.van_profiles vp
LEFT JOIN public.driver_profiles dp ON vp.current_driver_id = dp.id  
LEFT JOIN public.van_images vi ON vp.id = vi.van_id
GROUP BY vp.van_number, vp.make, vp.model, vp.current_driver_name, dp.driver_name
ORDER BY vp.van_number;

-- Success message
SELECT '✅ Quick fix schema applied successfully! Flutter app and Slack bot should now work.' as status; 
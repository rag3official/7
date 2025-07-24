-- Van Damage Tracker - Complete Database Schema
-- Run this first in your new Supabase project

BEGIN;

-- =============================================================================
-- 1. CORE TABLES
-- =============================================================================

-- Create vans table
CREATE TABLE IF NOT EXISTS public.vans (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    van_number text NOT NULL UNIQUE,
    type text DEFAULT 'Transit',
    status text DEFAULT 'Active',
    driver text,
    last_maintenance_date timestamptz,
    maintenance_notes text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create van_images table
CREATE TABLE IF NOT EXISTS public.van_images (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id uuid NOT NULL REFERENCES public.vans(id) ON DELETE CASCADE,
    image_url text NOT NULL,
    uploaded_by text DEFAULT 'slack_bot',
    uploaded_at timestamptz DEFAULT now(),
    description text,
    damage_type text,
    damage_level integer DEFAULT 0,
    location text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create driver_profiles table
CREATE TABLE IF NOT EXISTS public.driver_profiles (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid,
    name text NOT NULL,
    email text,
    phone text,
    license_number text,
    hire_date date,
    status text DEFAULT 'active',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create driver_van_assignments table
CREATE TABLE IF NOT EXISTS public.driver_van_assignments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE CASCADE,
    van_id uuid NOT NULL REFERENCES public.vans(id) ON DELETE CASCADE,
    assignment_date date DEFAULT CURRENT_DATE,
    start_time timestamptz,
    end_time timestamptz,
    status text DEFAULT 'active',
    notes text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_vans_van_number ON public.vans(van_number);
CREATE INDEX IF NOT EXISTS idx_van_images_van_id ON public.van_images(van_id);
CREATE INDEX IF NOT EXISTS idx_van_images_uploaded_at ON public.van_images(uploaded_at);
CREATE INDEX IF NOT EXISTS idx_driver_assignments_van_id ON public.driver_van_assignments(van_id);
CREATE INDEX IF NOT EXISTS idx_driver_assignments_driver_id ON public.driver_van_assignments(driver_id);

-- =============================================================================
-- 2. STORAGE METADATA TABLE
-- =============================================================================

-- Create storage metadata table for tracking uploads
CREATE TABLE IF NOT EXISTS public.storage_metadata (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    object_name text NOT NULL,
    bucket_id text NOT NULL,
    file_size bigint,
    mime_type text,
    storage_method text,
    van_folder text,
    created_at timestamptz DEFAULT now(),
    UNIQUE(object_name, bucket_id)
);

CREATE INDEX IF NOT EXISTS idx_storage_metadata_bucket_id ON public.storage_metadata(bucket_id);
CREATE INDEX IF NOT EXISTS idx_storage_metadata_van_folder ON public.storage_metadata(van_folder);

-- =============================================================================
-- 3. ENABLE ROW LEVEL SECURITY
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE public.vans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.van_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_van_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.storage_metadata ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 4. CREATE BASIC RLS POLICIES (Permissive for development)
-- =============================================================================

-- Vans policies
CREATE POLICY "Allow all access to vans" ON public.vans FOR ALL USING (true);

-- Van images policies
CREATE POLICY "Allow all access to van_images" ON public.van_images FOR ALL USING (true);

-- Driver profiles policies
CREATE POLICY "Allow all access to driver_profiles" ON public.driver_profiles FOR ALL USING (true);

-- Driver assignments policies
CREATE POLICY "Allow all access to driver_van_assignments" ON public.driver_van_assignments FOR ALL USING (true);

-- Storage metadata policies
CREATE POLICY "Allow all access to storage_metadata" ON public.storage_metadata FOR ALL USING (true);

-- =============================================================================
-- 5. GRANT PERMISSIONS
-- =============================================================================

-- Grant access to authenticated users and service role
GRANT ALL ON public.vans TO authenticated, anon, service_role;
GRANT ALL ON public.van_images TO authenticated, anon, service_role;
GRANT ALL ON public.driver_profiles TO authenticated, anon, service_role;
GRANT ALL ON public.driver_van_assignments TO authenticated, anon, service_role;
GRANT ALL ON public.storage_metadata TO authenticated, anon, service_role;

-- =============================================================================
-- 6. INSERT SAMPLE DATA
-- =============================================================================

-- Insert sample vans
INSERT INTO public.vans (van_number, type, status, driver) VALUES
('001', 'Transit', 'Active', 'John Smith'),
('002', 'Transit', 'Active', 'Jane Doe'),
('003', 'Sprinter', 'Active', 'Mike Johnson'),
('123', 'Transit', 'Active', 'Test Driver'),
('999', 'Transit', 'Active', 'Test User')
ON CONFLICT (van_number) DO NOTHING;

-- Insert sample driver profiles
INSERT INTO public.driver_profiles (name, email, phone, license_number, status) VALUES
('John Smith', 'john.smith@company.com', '+1-555-0001', 'DL001', 'active'),
('Jane Doe', 'jane.doe@company.com', '+1-555-0002', 'DL002', 'active'),
('Mike Johnson', 'mike.johnson@company.com', '+1-555-0003', 'DL003', 'active'),
('Test Driver', 'test.driver@company.com', '+1-555-9999', 'DL999', 'active')
ON CONFLICT DO NOTHING;

COMMIT;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Check tables were created
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('vans', 'van_images', 'driver_profiles', 'driver_van_assignments', 'storage_metadata')
ORDER BY table_name;

-- Check sample data
SELECT 'vans' as table_name, count(*) as row_count FROM public.vans
UNION ALL
SELECT 'van_images', count(*) FROM public.van_images
UNION ALL  
SELECT 'driver_profiles', count(*) FROM public.driver_profiles
UNION ALL
SELECT 'driver_van_assignments', count(*) FROM public.driver_van_assignments
ORDER BY table_name; 
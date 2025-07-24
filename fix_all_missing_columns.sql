-- Comprehensive Fix for All Missing Columns
-- Run this to add missing columns to all tables and fix the view errors

BEGIN;

-- =============================================================================
-- 1. ADD MISSING COLUMNS TO VANS TABLE
-- =============================================================================

-- Add last_maintenance_date column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vans' 
        AND column_name = 'last_maintenance_date'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.vans ADD COLUMN last_maintenance_date timestamptz;
    END IF;
END $$;

-- Add maintenance_notes column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vans' 
        AND column_name = 'maintenance_notes'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.vans ADD COLUMN maintenance_notes text;
    END IF;
END $$;

-- Add created_at column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vans' 
        AND column_name = 'created_at'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.vans ADD COLUMN created_at timestamptz DEFAULT now();
    END IF;
END $$;

-- Add updated_at column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vans' 
        AND column_name = 'updated_at'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.vans ADD COLUMN updated_at timestamptz DEFAULT now();
    END IF;
END $$;

-- =============================================================================
-- 2. ADD MISSING COLUMNS TO DRIVER_PROFILES TABLE
-- =============================================================================

-- Add user_id column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'driver_profiles' 
        AND column_name = 'user_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.driver_profiles ADD COLUMN user_id uuid;
    END IF;
END $$;

-- Add email column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'driver_profiles' 
        AND column_name = 'email'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.driver_profiles ADD COLUMN email text;
    END IF;
END $$;

-- Add phone column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'driver_profiles' 
        AND column_name = 'phone'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.driver_profiles ADD COLUMN phone text;
    END IF;
END $$;

-- Add license_number column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'driver_profiles' 
        AND column_name = 'license_number'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.driver_profiles ADD COLUMN license_number text;
    END IF;
END $$;

-- Add hire_date column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'driver_profiles' 
        AND column_name = 'hire_date'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.driver_profiles ADD COLUMN hire_date date;
    END IF;
END $$;

-- Add status column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'driver_profiles' 
        AND column_name = 'status'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.driver_profiles ADD COLUMN status text DEFAULT 'active';
    END IF;
END $$;

-- Add created_at column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'driver_profiles' 
        AND column_name = 'created_at'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.driver_profiles ADD COLUMN created_at timestamptz DEFAULT now();
    END IF;
END $$;

-- Add updated_at column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'driver_profiles' 
        AND column_name = 'updated_at'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.driver_profiles ADD COLUMN updated_at timestamptz DEFAULT now();
    END IF;
END $$;

-- =============================================================================
-- 3. ADD MISSING COLUMNS TO VAN_IMAGES TABLE
-- =============================================================================

-- Add damage_type column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' 
        AND column_name = 'damage_type'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN damage_type text;
    END IF;
END $$;

-- Add damage_level column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' 
        AND column_name = 'damage_level'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN damage_level integer DEFAULT 0;
    END IF;
END $$;

-- Add location column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' 
        AND column_name = 'location'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.van_images ADD COLUMN location text;
    END IF;
END $$;

-- =============================================================================
-- 4. DROP AND RECREATE VIEWS (SAFE VERSION)
-- =============================================================================

-- Drop the problematic views
DROP VIEW IF EXISTS public.van_images_with_van CASCADE;
DROP VIEW IF EXISTS public.van_images_with_driver CASCADE;
DROP VIEW IF EXISTS public.active_driver_assignments CASCADE;

-- Recreate van_images_with_van view (safe version)
CREATE VIEW public.van_images_with_van AS
SELECT 
    vi.id as image_id,
    vi.image_url,
    COALESCE(vi.uploaded_by, 'unknown') as uploaded_by,
    vi.uploaded_at,
    COALESCE(vi.description, '') as description,
    COALESCE(vi.damage_type, '') as damage_type,
    COALESCE(vi.damage_level, 0) as damage_level,
    COALESCE(vi.location, '') as location,
    vi.created_at as image_created_at,
    vi.updated_at as image_updated_at,
    v.id as van_id,
    v.van_number,
    COALESCE(v.type, 'Transit') as van_type,
    COALESCE(v.status, 'Active') as van_status,
    COALESCE(v.driver, '') as driver,
    v.last_maintenance_date,
    COALESCE(v.maintenance_notes, '') as maintenance_notes,
    v.created_at as van_created_at,
    v.updated_at as van_updated_at
FROM van_images vi
INNER JOIN vans v ON vi.van_id = v.id;

-- Recreate van_images_with_driver view (safe version)
CREATE VIEW public.van_images_with_driver AS
SELECT 
    vi.id as image_id,
    vi.image_url,
    COALESCE(vi.uploaded_by, 'unknown') as uploaded_by,
    vi.uploaded_at,
    COALESCE(vi.description, '') as description,
    COALESCE(vi.damage_type, '') as damage_type,
    COALESCE(vi.damage_level, 0) as damage_level,
    COALESCE(vi.location, '') as location,
    v.id as van_id,
    v.van_number,
    COALESCE(v.type, 'Transit') as van_type,
    COALESCE(v.status, 'Active') as van_status,
    COALESCE(v.driver, '') as van_driver_name,
    dp.id as driver_profile_id,
    COALESCE(dp.name, '') as driver_name,
    COALESCE(dp.email, '') as driver_email,
    COALESCE(dp.phone, '') as driver_phone,
    COALESCE(dp.license_number, '') as license_number,
    dp.hire_date,
    COALESCE(dp.status, 'active') as driver_status
FROM van_images vi
INNER JOIN vans v ON vi.van_id = v.id
LEFT JOIN driver_profiles dp ON v.driver = dp.name;

-- Recreate active_driver_assignments view (simplified to avoid missing tables)
CREATE VIEW public.active_driver_assignments AS
SELECT 
    dp.id as driver_id,
    COALESCE(dp.name, 'Unknown') as driver_name,
    COALESCE(dp.email, '') as driver_email,
    COALESCE(dp.phone, '') as driver_phone,
    COALESCE(dp.license_number, '') as license_number,
    COALESCE(dp.status, 'active') as driver_status,
    v.id as van_id,
    v.van_number,
    COALESCE(v.type, 'Transit') as van_type,
    COALESCE(v.status, 'Active') as van_status,
    v.last_maintenance_date,
    COALESCE(v.maintenance_notes, '') as maintenance_notes
FROM driver_profiles dp
CROSS JOIN vans v
WHERE COALESCE(dp.status, 'active') = 'active'
AND COALESCE(v.status, 'Active') = 'Active'
AND COALESCE(v.driver, '') = COALESCE(dp.name, '');

-- Grant select permissions on all views
GRANT SELECT ON public.van_images_with_van TO authenticated, anon, service_role;
GRANT SELECT ON public.van_images_with_driver TO authenticated, anon, service_role;
GRANT SELECT ON public.active_driver_assignments TO authenticated, anon, service_role;

COMMIT;

-- =============================================================================
-- 5. VERIFICATION
-- =============================================================================

-- Test that views work
SELECT 'Views Test Results:' as test_name, '' as result
UNION ALL
SELECT 'van_images_with_van', COUNT(*)::text FROM public.van_images_with_van
UNION ALL
SELECT 'van_images_with_driver', COUNT(*)::text FROM public.van_images_with_driver
UNION ALL
SELECT 'active_driver_assignments', COUNT(*)::text FROM public.active_driver_assignments;

-- Final success message
SELECT 'SUCCESS: All columns added and views fixed' as result; 
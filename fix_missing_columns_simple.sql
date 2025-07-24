-- Simple Fix for Missing Columns and Views
-- Run this to add missing columns and fix the view errors

BEGIN;

-- =============================================================================
-- 1. ADD MISSING COLUMNS TO VANS TABLE (SAFE)
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
-- 2. DROP AND RECREATE VIEWS (FIXED VERSION)
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
    vi.uploaded_by,
    vi.uploaded_at,
    vi.description,
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
    vi.uploaded_by,
    vi.uploaded_at,
    vi.description,
    COALESCE(vi.damage_type, '') as damage_type,
    COALESCE(vi.damage_level, 0) as damage_level,
    COALESCE(vi.location, '') as location,
    v.id as van_id,
    v.van_number,
    COALESCE(v.type, 'Transit') as van_type,
    COALESCE(v.status, 'Active') as van_status,
    COALESCE(v.driver, '') as van_driver_name,
    dp.id as driver_profile_id,
    dp.name as driver_name,
    dp.email as driver_email,
    dp.phone as driver_phone,
    dp.license_number,
    dp.hire_date,
    COALESCE(dp.status, 'active') as driver_status
FROM van_images vi
INNER JOIN vans v ON vi.van_id = v.id
LEFT JOIN driver_profiles dp ON v.driver = dp.name;

-- Recreate active_driver_assignments view (safe version)
CREATE VIEW public.active_driver_assignments AS
SELECT 
    dva.id as assignment_id,
    dva.assignment_date,
    dva.start_time,
    dva.end_time,
    COALESCE(dva.status, 'active') as assignment_status,
    COALESCE(dva.notes, '') as assignment_notes,
    dp.id as driver_id,
    dp.name as driver_name,
    dp.email as driver_email,
    dp.phone as driver_phone,
    dp.license_number,
    COALESCE(dp.status, 'active') as driver_status,
    v.id as van_id,
    v.van_number,
    COALESCE(v.type, 'Transit') as van_type,
    COALESCE(v.status, 'Active') as van_status,
    v.last_maintenance_date,
    COALESCE(v.maintenance_notes, '') as maintenance_notes
FROM driver_van_assignments dva
INNER JOIN driver_profiles dp ON dva.driver_id = dp.id
INNER JOIN vans v ON dva.van_id = v.id
WHERE COALESCE(dva.status, 'active') = 'active' 
AND COALESCE(dp.status, 'active') = 'active'
AND COALESCE(v.status, 'Active') = 'Active';

-- Grant select permissions on all views
GRANT SELECT ON public.van_images_with_van TO authenticated, anon, service_role;
GRANT SELECT ON public.van_images_with_driver TO authenticated, anon, service_role;
GRANT SELECT ON public.active_driver_assignments TO authenticated, anon, service_role;

COMMIT;

-- =============================================================================
-- 3. SIMPLE VERIFICATION
-- =============================================================================

-- Test that views work
SELECT 'van_images_with_van' as view_name, COUNT(*) as row_count FROM public.van_images_with_van
UNION ALL
SELECT 'van_images_with_driver', COUNT(*) FROM public.van_images_with_driver
UNION ALL
SELECT 'active_driver_assignments', COUNT(*) FROM public.active_driver_assignments;

-- Show vans table structure (simple check)
SELECT column_name, data_type
FROM information_schema.columns 
WHERE table_name = 'vans' 
AND table_schema = 'public'
AND column_name IN ('van_number', 'type', 'status', 'driver', 'last_maintenance_date', 'maintenance_notes', 'created_at', 'updated_at');

-- Final success message
SELECT 'SUCCESS: Views fixed and columns added' as result; 
-- Quick Fix for Security Definer View Errors
-- Run this to fix the 3 views causing security warnings

BEGIN;

-- =============================================================================
-- DROP AND RECREATE VIEWS WITHOUT SECURITY DEFINER
-- =============================================================================

-- Drop the problematic views
DROP VIEW IF EXISTS public.van_images_with_van CASCADE;
DROP VIEW IF EXISTS public.van_images_with_driver CASCADE;
DROP VIEW IF EXISTS public.active_driver_assignments CASCADE;

-- Recreate van_images_with_van view (WITHOUT SECURITY DEFINER)
CREATE VIEW public.van_images_with_van AS
SELECT 
    vi.id as image_id,
    vi.image_url,
    vi.uploaded_by,
    vi.uploaded_at,
    vi.description,
    vi.damage_type,
    vi.damage_level,
    vi.location,
    vi.created_at as image_created_at,
    vi.updated_at as image_updated_at,
    v.id as van_id,
    v.van_number,
    v.type as van_type,
    v.status as van_status,
    v.driver,
    v.last_maintenance_date,
    v.maintenance_notes,
    v.created_at as van_created_at,
    v.updated_at as van_updated_at
FROM van_images vi
INNER JOIN vans v ON vi.van_id = v.id;

-- Recreate van_images_with_driver view (WITHOUT SECURITY DEFINER)
CREATE VIEW public.van_images_with_driver AS
SELECT 
    vi.id as image_id,
    vi.image_url,
    vi.uploaded_by,
    vi.uploaded_at,
    vi.description,
    vi.damage_type,
    vi.damage_level,
    vi.location,
    v.id as van_id,
    v.van_number,
    v.type as van_type,
    v.status as van_status,
    v.driver as van_driver_name,
    dp.id as driver_profile_id,
    dp.name as driver_name,
    dp.email as driver_email,
    dp.phone as driver_phone,
    dp.license_number,
    dp.hire_date,
    dp.status as driver_status
FROM van_images vi
INNER JOIN vans v ON vi.van_id = v.id
LEFT JOIN driver_profiles dp ON v.driver = dp.name;

-- Recreate active_driver_assignments view (WITHOUT SECURITY DEFINER)
CREATE VIEW public.active_driver_assignments AS
SELECT 
    dva.id as assignment_id,
    dva.assignment_date,
    dva.start_time,
    dva.end_time,
    dva.status as assignment_status,
    dva.notes as assignment_notes,
    dp.id as driver_id,
    dp.name as driver_name,
    dp.email as driver_email,
    dp.phone as driver_phone,
    dp.license_number,
    dp.status as driver_status,
    v.id as van_id,
    v.van_number,
    v.type as van_type,
    v.status as van_status,
    v.last_maintenance_date,
    v.maintenance_notes
FROM driver_van_assignments dva
INNER JOIN driver_profiles dp ON dva.driver_id = dp.id
INNER JOIN vans v ON dva.van_id = v.id
WHERE dva.status = 'active' 
AND dp.status = 'active'
AND v.status = 'Active';

-- Grant select permissions on all views
GRANT SELECT ON public.van_images_with_van TO authenticated, anon, service_role;
GRANT SELECT ON public.van_images_with_driver TO authenticated, anon, service_role;
GRANT SELECT ON public.active_driver_assignments TO authenticated, anon, service_role;

COMMIT;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

-- Check that views were created successfully
SELECT 
    table_name as view_name,
    'SUCCESS' as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'VIEW'
AND table_name IN ('van_images_with_van', 'van_images_with_driver', 'active_driver_assignments')
ORDER BY table_name;

-- Test that views work
SELECT 'van_images_with_van' as view_test, COUNT(*) as row_count FROM public.van_images_with_van
UNION ALL
SELECT 'van_images_with_driver', COUNT(*) FROM public.van_images_with_driver
UNION ALL
SELECT 'active_driver_assignments', COUNT(*) FROM public.active_driver_assignments;

-- Check for any remaining security definer issues (should return no rows)
SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views 
WHERE schemaname = 'public' 
AND viewname IN ('van_images_with_van', 'van_images_with_driver', 'active_driver_assignments')
AND definition ILIKE '%security definer%';

SELECT 'Security Fix Complete' as message, 'All views recreated without SECURITY DEFINER' as details; 
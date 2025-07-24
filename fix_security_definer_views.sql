-- Fix Security Definer Views
-- This script specifically addresses the three SECURITY DEFINER views causing security errors

BEGIN;

-- Check current view definitions and remove SECURITY DEFINER property
-- The SECURITY DEFINER property makes views run with creator's permissions instead of user's permissions

-- 1. Fix van_images_with_van view
DROP VIEW IF EXISTS public.van_images_with_van CASCADE;
CREATE VIEW public.van_images_with_van AS
SELECT 
    vi.id,
    vi.van_id,
    vi.image_url,
    vi.uploaded_by,
    vi.uploaded_at,
    vi.description,
    vi.damage_type,
    vi.damage_level,
    vi.location,
    vi.created_at,
    vi.updated_at,
    v.van_number,
    v.type as van_type,
    v.status as van_status,
    v.driver
FROM public.van_images vi
LEFT JOIN public.vans v ON vi.van_id = v.id;

-- 2. Fix active_driver_assignments view
DROP VIEW IF EXISTS public.active_driver_assignments CASCADE;
CREATE VIEW public.active_driver_assignments AS
SELECT 
    dva.id,
    dva.driver_id,
    dva.van_id,
    dva.assignment_date,
    dva.created_at,
    dva.updated_at,
    COALESCE(dva.start_time, dva.created_at) as start_time,
    COALESCE(dva.status, 'active') as status,
    dp.name as driver_name,
    dp.phone as driver_phone,
    dp.email as driver_email,
    v.van_number,
    v.type as van_type,
    v.status as van_status,
    v.driver as current_driver
FROM public.driver_van_assignments dva
LEFT JOIN public.driver_profiles dp ON dva.driver_id = dp.user_id
LEFT JOIN public.vans v ON dva.van_id = v.id
WHERE COALESCE(dva.status, 'active') = 'active';

-- 3. Fix van_images_with_driver view
DROP VIEW IF EXISTS public.van_images_with_driver CASCADE;
CREATE VIEW public.van_images_with_driver AS
SELECT 
    vi.id,
    vi.van_id,
    vi.image_url,
    vi.uploaded_by,
    vi.uploaded_at,
    vi.description,
    vi.damage_type,
    vi.damage_level,
    vi.location,
    vi.created_at,
    vi.updated_at,
    v.van_number,
    v.type as van_type,
    v.status as van_status,
    v.driver as current_driver,
    dva.driver_id as assignment_driver_id,
    dp.name as assigned_driver_name,
    dp.phone as assigned_driver_phone,
    dp.email as assigned_driver_email
FROM public.van_images vi
LEFT JOIN public.vans v ON vi.van_id = v.id
LEFT JOIN public.driver_van_assignments dva ON (
    v.id = dva.van_id 
    AND COALESCE(dva.status, 'active') = 'active'
)
LEFT JOIN public.driver_profiles dp ON dva.driver_id = dp.user_id;

-- Grant appropriate permissions on the recreated views
GRANT SELECT ON public.van_images_with_van TO authenticated, anon, service_role;
GRANT SELECT ON public.active_driver_assignments TO authenticated, anon, service_role;
GRANT SELECT ON public.van_images_with_driver TO authenticated, anon, service_role;

-- Add helpful comments
COMMENT ON VIEW public.van_images_with_van IS 'View of van images with van details - no SECURITY DEFINER';
COMMENT ON VIEW public.active_driver_assignments IS 'View of active driver assignments with details - no SECURITY DEFINER';
COMMENT ON VIEW public.van_images_with_driver IS 'View of van images with assigned driver details - no SECURITY DEFINER';

COMMIT;

-- Verification: Check that views exist and don't have SECURITY DEFINER
-- Run this after the migration:
-- SELECT schemaname, viewname, definition FROM pg_views 
-- WHERE viewname IN ('van_images_with_van', 'active_driver_assignments', 'van_images_with_driver')
-- AND definition NOT LIKE '%SECURITY DEFINER%'; 
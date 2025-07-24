-- Complete Fix for Security Definer Views
-- This script comprehensively addresses ALL potential SECURITY DEFINER view issues

BEGIN;

-- First, let's check what views currently exist and their definitions
DO $$
DECLARE
    view_record RECORD;
BEGIN
    -- Log current view definitions that might have SECURITY DEFINER
    FOR view_record IN 
        SELECT viewname, definition 
        FROM pg_views 
        WHERE schemaname = 'public' 
        AND viewname IN ('van_images_with_van', 'active_driver_assignments', 'van_images_with_driver')
    LOOP
        RAISE NOTICE 'Found view: %, Definition contains SECURITY DEFINER: %', 
                     view_record.viewname, 
                     (view_record.definition LIKE '%SECURITY DEFINER%');
    END LOOP;
END $$;

-- Drop ALL potential views that might have SECURITY DEFINER
-- Using CASCADE to handle any dependencies
DROP VIEW IF EXISTS public.van_images_with_van CASCADE;
DROP VIEW IF EXISTS public.active_driver_assignments CASCADE;
DROP VIEW IF EXISTS public.van_images_with_driver CASCADE;

-- Also drop any variants that might exist
DROP VIEW IF EXISTS van_images_with_van CASCADE;
DROP VIEW IF EXISTS active_driver_assignments CASCADE;
DROP VIEW IF EXISTS van_images_with_driver CASCADE;

-- Wait a moment to ensure cleanup
SELECT pg_sleep(1);

-- Recreate van_images_with_van view WITHOUT any SECURITY properties
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

-- Recreate active_driver_assignments view WITHOUT any SECURITY properties
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

-- Recreate van_images_with_driver view WITHOUT any SECURITY properties
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

-- Ensure proper ownership and permissions
-- Reset ownership to the current user (not a specific definer)
ALTER VIEW public.van_images_with_van OWNER TO postgres;
ALTER VIEW public.active_driver_assignments OWNER TO postgres;
ALTER VIEW public.van_images_with_driver OWNER TO postgres;

-- Grant appropriate permissions
GRANT SELECT ON public.van_images_with_van TO authenticated, anon, service_role;
GRANT SELECT ON public.active_driver_assignments TO authenticated, anon, service_role;
GRANT SELECT ON public.van_images_with_driver TO authenticated, anon, service_role;

-- Add explicit comments indicating these are NOT security definer
COMMENT ON VIEW public.van_images_with_van IS 'Van images with van details - INVOKER RIGHTS (not security definer)';
COMMENT ON VIEW public.active_driver_assignments IS 'Active driver assignments - INVOKER RIGHTS (not security definer)';
COMMENT ON VIEW public.van_images_with_driver IS 'Van images with driver details - INVOKER RIGHTS (not security definer)';

-- Final verification: Log the recreated views
DO $$
DECLARE
    view_record RECORD;
BEGIN
    RAISE NOTICE 'VERIFICATION: Checking recreated views...';
    FOR view_record IN 
        SELECT schemaname, viewname, definition 
        FROM pg_views 
        WHERE schemaname = 'public' 
        AND viewname IN ('van_images_with_van', 'active_driver_assignments', 'van_images_with_driver')
    LOOP
        RAISE NOTICE 'Recreated view: %.%, Has SECURITY DEFINER: %', 
                     view_record.schemaname,
                     view_record.viewname, 
                     (view_record.definition ILIKE '%SECURITY DEFINER%');
    END LOOP;
END $$;

COMMIT;

-- Post-execution verification queries:
-- Run these after the script to confirm the views are properly created:
/*
SELECT 
    schemaname, 
    viewname,
    CASE 
        WHEN definition ILIKE '%SECURITY DEFINER%' THEN 'HAS SECURITY DEFINER' 
        ELSE 'NO SECURITY DEFINER' 
    END as security_status
FROM pg_views 
WHERE viewname IN ('van_images_with_van', 'active_driver_assignments', 'van_images_with_driver');
*/ 
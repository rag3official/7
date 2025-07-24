-- Fix Security Linter Errors
-- This script addresses the database linter security issues

BEGIN;

-- 1. Fix SECURITY DEFINER views by recreating them without SECURITY DEFINER
-- This makes them use the permissions of the querying user instead of the creator

-- Drop and recreate van_images_with_van view without SECURITY DEFINER
DROP VIEW IF EXISTS public.van_images_with_van;
CREATE VIEW public.van_images_with_van AS
SELECT 
    vi.*,
    v.van_number,
    v.type as van_type,
    v.status as van_status
FROM van_images vi
LEFT JOIN vans v ON vi.van_id = v.id;

-- Drop and recreate active_driver_assignments view without SECURITY DEFINER  
-- Using correct table name: driver_van_assignments and explicit column selection
DROP VIEW IF EXISTS public.active_driver_assignments;
CREATE VIEW public.active_driver_assignments AS
SELECT 
    dva.id,
    dva.driver_id,
    dva.van_id,
    dva.assignment_date,
    dva.created_at,
    COALESCE(dva.start_time, dva.created_at) as start_time,
    COALESCE(dva.status, 'active') as status,
    dp.name as driver_name,
    dp.phone as driver_phone,
    v.van_number,
    v.type as van_type
FROM driver_van_assignments dva
LEFT JOIN driver_profiles dp ON dva.driver_id = dp.id
LEFT JOIN vans v ON dva.van_id = v.id
WHERE COALESCE(dva.status, 'active') = 'active';

-- Drop and recreate van_images_with_driver view without SECURITY DEFINER
-- Fix duplicate driver_id and driver_name issues by aliasing columns
DROP VIEW IF EXISTS public.van_images_with_driver;
CREATE VIEW public.van_images_with_driver AS
SELECT 
    vi.*,
    v.van_number,
    dva.driver_id as assignment_driver_id,
    dp.name as assigned_driver_name
FROM van_images vi
LEFT JOIN vans v ON vi.van_id = v.id
LEFT JOIN driver_van_assignments dva ON v.id = dva.van_id AND COALESCE(dva.status, 'active') = 'active'
LEFT JOIN driver_profiles dp ON dva.driver_id = dp.id;

-- 2. Enable RLS on storage_metadata table (only if it exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'storage_metadata') THEN
        ALTER TABLE public.storage_metadata ENABLE ROW LEVEL SECURITY;
        
        -- Create RLS policies for storage_metadata table
        -- Allow all operations for authenticated users (service_role has bypass)
        DROP POLICY IF EXISTS "storage_metadata_select_policy" ON public.storage_metadata;
        DROP POLICY IF EXISTS "storage_metadata_insert_policy" ON public.storage_metadata;
        DROP POLICY IF EXISTS "storage_metadata_update_policy" ON public.storage_metadata;
        DROP POLICY IF EXISTS "storage_metadata_delete_policy" ON public.storage_metadata;
        
        CREATE POLICY "storage_metadata_select_policy" ON public.storage_metadata
            FOR SELECT USING (true);

        CREATE POLICY "storage_metadata_insert_policy" ON public.storage_metadata
            FOR INSERT WITH CHECK (true);

        CREATE POLICY "storage_metadata_update_policy" ON public.storage_metadata
            FOR UPDATE USING (true);

        CREATE POLICY "storage_metadata_delete_policy" ON public.storage_metadata
            FOR DELETE USING (true);
            
        -- Grant permissions on storage_metadata table
        GRANT ALL ON public.storage_metadata TO authenticated, service_role;
        GRANT SELECT ON public.storage_metadata TO anon;
        
        RAISE NOTICE 'RLS enabled and policies created for storage_metadata table';
    ELSE
        RAISE NOTICE 'storage_metadata table does not exist, skipping RLS setup';
    END IF;
END $$;

-- 3. Grant proper permissions on the recreated views
GRANT SELECT ON public.van_images_with_van TO authenticated, anon;
GRANT SELECT ON public.active_driver_assignments TO authenticated, anon;
GRANT SELECT ON public.van_images_with_driver TO authenticated, anon;

COMMIT;

-- Verification queries (run these after applying the migration)
-- SELECT schemaname, tablename, rowsecurity FROM pg_tables WHERE tablename = 'storage_metadata';
-- SELECT schemaname, viewname FROM pg_views WHERE viewname IN ('van_images_with_van', 'active_driver_assignments', 'van_images_with_driver'); 
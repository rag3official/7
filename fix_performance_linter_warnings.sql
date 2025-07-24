-- Fix Performance Linter Warnings
-- This script optimizes RLS policies and removes duplicate indexes for better performance

BEGIN;

-- 1. Fix Auth RLS Initialization Plan Issues
-- Replace auth.uid() with (SELECT auth.uid()) to avoid re-evaluation per row

-- Fix vans table RLS policies
DROP POLICY IF EXISTS "Delete assigned vans" ON public.vans;
DROP POLICY IF EXISTS "Insert vans for authenticated drivers" ON public.vans;
DROP POLICY IF EXISTS "Update assigned vans" ON public.vans;
DROP POLICY IF EXISTS "View assigned vans" ON public.vans;

CREATE POLICY "Delete assigned vans" ON public.vans
FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM driver_van_assignments dva
        WHERE dva.van_id = vans.id 
        AND dva.driver_id = (SELECT auth.uid())
        AND dva.status = 'active'
    )
);

CREATE POLICY "Insert vans for authenticated drivers" ON public.vans
FOR INSERT WITH CHECK (
    (SELECT auth.role()) = 'authenticated'
);

CREATE POLICY "Update assigned vans" ON public.vans
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM driver_van_assignments dva
        WHERE dva.van_id = vans.id 
        AND dva.driver_id = (SELECT auth.uid())
        AND dva.status = 'active'
    )
);

CREATE POLICY "View assigned vans" ON public.vans
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM driver_van_assignments dva
        WHERE dva.van_id = vans.id 
        AND dva.driver_id = (SELECT auth.uid())
        AND dva.status = 'active'
    )
);

-- Fix maintenance_records table RLS policies
DROP POLICY IF EXISTS "Delete maintenance records for assigned vans" ON public.maintenance_records;
DROP POLICY IF EXISTS "Insert maintenance records for assigned vans" ON public.maintenance_records;
DROP POLICY IF EXISTS "Update maintenance records for assigned vans" ON public.maintenance_records;
DROP POLICY IF EXISTS "View maintenance records for assigned vans" ON public.maintenance_records;

CREATE POLICY "Delete maintenance records for assigned vans" ON public.maintenance_records
FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM driver_van_assignments dva
        WHERE dva.van_id = maintenance_records.van_id 
        AND dva.driver_id = (SELECT auth.uid())
        AND dva.status = 'active'
    )
);

CREATE POLICY "Insert maintenance records for assigned vans" ON public.maintenance_records
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM driver_van_assignments dva
        WHERE dva.van_id = maintenance_records.van_id 
        AND dva.driver_id = (SELECT auth.uid())
        AND dva.status = 'active'
    )
);

CREATE POLICY "Update maintenance records for assigned vans" ON public.maintenance_records
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM driver_van_assignments dva
        WHERE dva.van_id = maintenance_records.van_id 
        AND dva.driver_id = (SELECT auth.uid())
        AND dva.status = 'active'
    )
);

CREATE POLICY "View maintenance records for assigned vans" ON public.maintenance_records
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM driver_van_assignments dva
        WHERE dva.van_id = maintenance_records.van_id 
        AND dva.driver_id = (SELECT auth.uid())
        AND dva.status = 'active'
    )
);

-- Fix driver_profiles table RLS policies
DROP POLICY IF EXISTS "Users can delete their own profile" ON public.driver_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.driver_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.driver_profiles;

CREATE POLICY "Users can delete their own profile" ON public.driver_profiles
FOR DELETE USING (
    user_id = (SELECT auth.uid()) OR public.is_admin()
);

CREATE POLICY "Users can insert their own profile" ON public.driver_profiles
FOR INSERT WITH CHECK (
    user_id = (SELECT auth.uid())
);

CREATE POLICY "Users can update their own profile" ON public.driver_profiles
FOR UPDATE USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

-- Fix driver_van_assignments table RLS policies
DROP POLICY IF EXISTS "Users can delete their own assignments" ON public.driver_van_assignments;
DROP POLICY IF EXISTS "Users can insert their own assignments" ON public.driver_van_assignments;
DROP POLICY IF EXISTS "Users can update their own assignments" ON public.driver_van_assignments;
DROP POLICY IF EXISTS "Users can view their own assignments" ON public.driver_van_assignments;

CREATE POLICY "Users can delete their own assignments" ON public.driver_van_assignments
FOR DELETE USING (driver_id = (SELECT auth.uid()));

CREATE POLICY "Users can insert their own assignments" ON public.driver_van_assignments
FOR INSERT WITH CHECK (driver_id = (SELECT auth.uid()));

CREATE POLICY "Users can update their own assignments" ON public.driver_van_assignments
FOR UPDATE USING (driver_id = (SELECT auth.uid()))
WITH CHECK (driver_id = (SELECT auth.uid()));

CREATE POLICY "Users can view their own assignments" ON public.driver_van_assignments
FOR SELECT USING (driver_id = (SELECT auth.uid()));

-- Fix driver_uploads table RLS policies (if it exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'driver_uploads') THEN
        DROP POLICY IF EXISTS "Users can delete their own uploads" ON public.driver_uploads;
        DROP POLICY IF EXISTS "Users can insert their own uploads" ON public.driver_uploads;
        DROP POLICY IF EXISTS "Users can update their own uploads" ON public.driver_uploads;
        DROP POLICY IF EXISTS "Users can view their own uploads" ON public.driver_uploads;

        CREATE POLICY "Users can delete their own uploads" ON public.driver_uploads
        FOR DELETE USING (driver_id = (SELECT auth.uid()));

        CREATE POLICY "Users can insert their own uploads" ON public.driver_uploads
        FOR INSERT WITH CHECK (driver_id = (SELECT auth.uid()));

        CREATE POLICY "Users can update their own uploads" ON public.driver_uploads
        FOR UPDATE USING (driver_id = (SELECT auth.uid()))
        WITH CHECK (driver_id = (SELECT auth.uid()));

        CREATE POLICY "Users can view their own uploads" ON public.driver_uploads
        FOR SELECT USING (driver_id = (SELECT auth.uid()));
    END IF;
END $$;

-- Fix driver_images table RLS policies (if it exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'driver_images') THEN
        DROP POLICY IF EXISTS "Users can delete their own images" ON public.driver_images;
        DROP POLICY IF EXISTS "Users can insert their own images" ON public.driver_images;
        DROP POLICY IF EXISTS "Users can update their own images" ON public.driver_images;
        DROP POLICY IF EXISTS "Users can view their own images" ON public.driver_images;

        CREATE POLICY "Users can delete their own images" ON public.driver_images
        FOR DELETE USING (driver_id = (SELECT auth.uid()));

        CREATE POLICY "Users can insert their own images" ON public.driver_images
        FOR INSERT WITH CHECK (driver_id = (SELECT auth.uid()));

        CREATE POLICY "Users can update their own images" ON public.driver_images
        FOR UPDATE USING (driver_id = (SELECT auth.uid()))
        WITH CHECK (driver_id = (SELECT auth.uid()));

        CREATE POLICY "Users can view their own images" ON public.driver_images
        FOR SELECT USING (driver_id = (SELECT auth.uid()));
    END IF;
END $$;

-- Fix upload_rate_limits table RLS policies (if it exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'upload_rate_limits') THEN
        DROP POLICY IF EXISTS "Users can only access their own upload limits" ON public.upload_rate_limits;

        CREATE POLICY "Users can only access their own upload limits" ON public.upload_rate_limits
        FOR ALL USING (user_id = (SELECT auth.uid()));
    END IF;
END $$;

-- 2. Clean up duplicate policies to fix "Multiple Permissive Policies" warnings
-- Drop duplicate/conflicting policies

-- Clean up maintenance_records duplicate policies
DROP POLICY IF EXISTS "maintenance_records_delete_policy" ON public.maintenance_records;
DROP POLICY IF EXISTS "maintenance_records_insert_policy" ON public.maintenance_records;
DROP POLICY IF EXISTS "maintenance_records_select_policy" ON public.maintenance_records;
DROP POLICY IF EXISTS "maintenance_records_update_policy" ON public.maintenance_records;

-- Clean up van_images ALL duplicate policies - this is causing the multiple permissive policies warnings
DROP POLICY IF EXISTS "van_images_read_policy" ON public.van_images;
DROP POLICY IF EXISTS "Allow authenticated access to van_images" ON public.van_images;
DROP POLICY IF EXISTS "Allow anonymous access to van_images" ON public.van_images;
DROP POLICY IF EXISTS "van_images_delete_policy" ON public.van_images;
DROP POLICY IF EXISTS "van_images_insert_policy" ON public.van_images;
DROP POLICY IF EXISTS "van_images_update_policy" ON public.van_images;
DROP POLICY IF EXISTS "van_images_select_policy" ON public.van_images;
DROP POLICY IF EXISTS "Optimized van images access" ON public.van_images;

-- Clean up vans duplicate policies
DROP POLICY IF EXISTS "vans_delete_policy" ON public.vans;
DROP POLICY IF EXISTS "vans_insert_policy" ON public.vans;
DROP POLICY IF EXISTS "vans_select_policy" ON public.vans;
DROP POLICY IF EXISTS "vans_update_policy" ON public.vans;

-- 3. Fix duplicate indexes
-- Drop the duplicate index on driver_van_assignments
DROP INDEX IF EXISTS public.idx_driver_assignments_date;

-- Keep the properly named one: idx_driver_van_assignments_date

-- 4. Create single optimized policies for van_images to replace all the conflicting ones
-- Create comprehensive policies for van_images that handle all access patterns
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'van_images') THEN
        -- Single SELECT policy for both authenticated and anonymous users
        CREATE POLICY "van_images_optimized_select" ON public.van_images
        FOR SELECT USING (
            -- Allow access if user is assigned to the van or is admin or allow anonymous
            EXISTS (
                SELECT 1 FROM driver_van_assignments dva
                WHERE dva.van_id = van_images.van_id 
                AND dva.driver_id = (SELECT auth.uid())
                AND dva.status = 'active'
            ) OR public.is_admin() OR (SELECT auth.role()) = 'anon'
        );

        -- Single INSERT policy for authenticated users
        CREATE POLICY "van_images_optimized_insert" ON public.van_images
        FOR INSERT WITH CHECK (
            EXISTS (
                SELECT 1 FROM driver_van_assignments dva
                WHERE dva.van_id = van_images.van_id 
                AND dva.driver_id = (SELECT auth.uid())
                AND dva.status = 'active'
            ) OR public.is_admin()
        );

        -- Single UPDATE policy for authenticated users
        CREATE POLICY "van_images_optimized_update" ON public.van_images
        FOR UPDATE USING (
            EXISTS (
                SELECT 1 FROM driver_van_assignments dva
                WHERE dva.van_id = van_images.van_id 
                AND dva.driver_id = (SELECT auth.uid())
                AND dva.status = 'active'
            ) OR public.is_admin()
        );

        -- Single DELETE policy for authenticated users
        CREATE POLICY "van_images_optimized_delete" ON public.van_images
        FOR DELETE USING (
            EXISTS (
                SELECT 1 FROM driver_van_assignments dva
                WHERE dva.van_id = van_images.van_id 
                AND dva.driver_id = (SELECT auth.uid())
                AND dva.status = 'active'
            ) OR public.is_admin()
        );
    END IF;
END $$;

-- 5. Create optimized indexes to support the new policies
CREATE INDEX IF NOT EXISTS idx_driver_van_assignments_user_status 
ON public.driver_van_assignments(driver_id, status) 
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_driver_van_assignments_van_status 
ON public.driver_van_assignments(van_id, status) 
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_maintenance_records_van_id 
ON public.maintenance_records(van_id);

-- Add index for van_images to support the new policies
CREATE INDEX IF NOT EXISTS idx_van_images_van_id 
ON public.van_images(van_id);

-- Add helpful comments
COMMENT ON POLICY "Delete assigned vans" ON public.vans IS 'Optimized policy with auth.uid() subquery for performance';
COMMENT ON POLICY "View assigned vans" ON public.vans IS 'Optimized policy with auth.uid() subquery for performance';

COMMIT;

-- Verification queries (run these after applying the migration)
-- SELECT schemaname, tablename, policyname FROM pg_policies WHERE tablename IN ('vans', 'maintenance_records', 'driver_profiles', 'driver_van_assignments', 'van_images');
-- SELECT indexname FROM pg_indexes WHERE tablename = 'driver_van_assignments' AND indexname LIKE '%date%'; 
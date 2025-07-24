-- Van Damage Tracker - Storage Bucket Setup
-- Run this second to set up storage for images

BEGIN;

-- =============================================================================
-- 1. CREATE STORAGE BUCKET
-- =============================================================================

-- Create the van-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'van-images',
    'van-images',
    true,
    52428800, -- 50MB limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
) ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- =============================================================================
-- 2. CREATE STORAGE POLICIES
-- =============================================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "van_images_read_policy" ON storage.objects;
DROP POLICY IF EXISTS "van_images_upload_policy" ON storage.objects;
DROP POLICY IF EXISTS "van_images_update_policy" ON storage.objects;
DROP POLICY IF EXISTS "van_images_delete_policy" ON storage.objects;

-- Create comprehensive storage policies for van-images bucket
CREATE POLICY "van_images_read_policy" ON storage.objects
    FOR SELECT 
    USING (bucket_id = 'van-images');

CREATE POLICY "van_images_upload_policy" ON storage.objects
    FOR INSERT 
    WITH CHECK (
        bucket_id = 'van-images' AND
        (auth.role() = 'authenticated' OR auth.role() = 'service_role' OR auth.role() = 'anon')
    );

CREATE POLICY "van_images_update_policy" ON storage.objects
    FOR UPDATE 
    USING (bucket_id = 'van-images');

CREATE POLICY "van_images_delete_policy" ON storage.objects
    FOR DELETE 
    USING (bucket_id = 'van-images');

-- =============================================================================
-- 3. GRANT STORAGE PERMISSIONS
-- =============================================================================

-- Grant necessary permissions for storage operations
GRANT USAGE ON SCHEMA storage TO authenticated, anon, service_role;
GRANT ALL ON storage.objects TO authenticated, anon, service_role;
GRANT ALL ON storage.buckets TO authenticated, anon, service_role;

-- =============================================================================
-- 4. CREATE STORAGE HELPER FUNCTIONS
-- =============================================================================

-- Function to get storage bucket status
CREATE OR REPLACE FUNCTION public.get_storage_bucket_info()
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    bucket_info jsonb;
    policies_count integer;
BEGIN
    -- Get bucket information
    SELECT jsonb_build_object(
        'id', id,
        'name', name,
        'public', public,
        'file_size_limit', file_size_limit,
        'allowed_mime_types', allowed_mime_types,
        'created_at', created_at,
        'updated_at', updated_at
    ) INTO bucket_info
    FROM storage.buckets 
    WHERE id = 'van-images';
    
    -- Count policies
    SELECT COUNT(*) INTO policies_count
    FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname LIKE 'van_images_%';
    
    RETURN jsonb_build_object(
        'bucket_exists', bucket_info IS NOT NULL,
        'bucket_info', bucket_info,
        'policies_count', policies_count,
        'recommended_usage', 'supabase.storage.from("van-images").upload()',
        'file_path_format', 'van_{van_number}/image_{timestamp}.jpg'
    );
END $$;

-- Function to test storage upload capability
CREATE OR REPLACE FUNCTION public.test_storage_capability()
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    test_result jsonb;
BEGIN
    -- Basic capability test
    test_result := jsonb_build_object(
        'bucket_accessible', EXISTS(SELECT 1 FROM storage.buckets WHERE id = 'van-images'),
        'policies_active', EXISTS(SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'),
        'storage_schema_accessible', has_schema_privilege('storage', 'USAGE'),
        'test_timestamp', NOW()
    );
    
    RETURN test_result;
END $$;

-- Grant execute permissions on helper functions
GRANT EXECUTE ON FUNCTION public.get_storage_bucket_info TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.test_storage_capability TO authenticated, anon, service_role;

COMMIT;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

-- Test the bucket setup
SELECT public.get_storage_bucket_info() as bucket_status;

-- Test storage capability
SELECT public.test_storage_capability() as capability_test;

-- List all storage buckets
SELECT id, name, public, file_size_limit, allowed_mime_types 
FROM storage.buckets;

-- List storage policies
SELECT schemaname, tablename, policyname, cmd, qual
FROM pg_policies 
WHERE schemaname = 'storage' 
AND tablename = 'objects'
ORDER BY policyname; 
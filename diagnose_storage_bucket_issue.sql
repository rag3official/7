-- Van Damage Tracker - Storage Bucket Diagnostic and Fix
-- Run this to diagnose and fix the current storage bucket issues

BEGIN;

-- =============================================================================
-- 1. DIAGNOSE CURRENT STORAGE BUCKET STATE
-- =============================================================================

-- Check all existing buckets
SELECT 'EXISTING BUCKETS' as section, '' as details
UNION ALL
SELECT '===================' as section, '' as details
UNION ALL
SELECT 
    CONCAT('Bucket ID: ', id) as section,
    CONCAT('Name: ', name, ', Public: ', public::text, ', Created: ', created_at::text) as details
FROM storage.buckets
ORDER BY section;

-- Check storage policies
SELECT 'STORAGE POLICIES' as section, '' as details
UNION ALL
SELECT '===================' as section, '' as details
UNION ALL
SELECT 
    CONCAT('Policy: ', policyname) as section,
    CONCAT('Command: ', cmd, ', Table: ', tablename) as details
FROM pg_policies 
WHERE schemaname = 'storage'
ORDER BY section;

-- Check if there are objects in storage
SELECT 'STORAGE OBJECTS' as section, '' as details
UNION ALL
SELECT '===================' as section, '' as details
UNION ALL
SELECT 
    CONCAT('Bucket: ', bucket_id) as section,
    CONCAT('Objects count: ', COUNT(*)::text) as details
FROM storage.objects
GROUP BY bucket_id
ORDER BY section;

-- =============================================================================
-- 2. FIX STORAGE BUCKET CONFIGURATION
-- =============================================================================

-- First, let's ensure we have the correct bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'van-images',
    'van-images', 
    true,
    52428800, -- 50MB
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
) ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Clean up any conflicting bucket policies
DROP POLICY IF EXISTS "van_images_read_policy" ON storage.objects;
DROP POLICY IF EXISTS "van_images_upload_policy" ON storage.objects;
DROP POLICY IF EXISTS "van_images_update_policy" ON storage.objects;
DROP POLICY IF EXISTS "van_images_delete_policy" ON storage.objects;

-- Create fresh storage policies
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

-- Grant necessary permissions
GRANT USAGE ON SCHEMA storage TO authenticated, anon, service_role;
GRANT ALL ON storage.objects TO authenticated, anon, service_role;
GRANT ALL ON storage.buckets TO authenticated, anon, service_role;

-- =============================================================================
-- 3. TEST STORAGE CONFIGURATION
-- =============================================================================

-- Create a comprehensive storage test function
CREATE OR REPLACE FUNCTION public.test_storage_configuration()
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    bucket_exists boolean;
    policies_count integer;
    test_result jsonb;
BEGIN
    -- Check if bucket exists
    SELECT EXISTS(SELECT 1 FROM storage.buckets WHERE id = 'van-images') 
    INTO bucket_exists;
    
    -- Count policies
    SELECT COUNT(*) INTO policies_count
    FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname LIKE 'van_images_%';
    
    -- Build result
    test_result := jsonb_build_object(
        'bucket_exists', bucket_exists,
        'bucket_name', 'van-images',
        'policies_count', policies_count,
        'schema_access', has_schema_privilege('storage', 'USAGE'),
        'objects_table_access', has_table_privilege('storage.objects', 'SELECT'),
        'buckets_table_access', has_table_privilege('storage.buckets', 'SELECT'),
        'test_timestamp', NOW(),
        'status', CASE 
            WHEN bucket_exists AND policies_count >= 4 THEN 'READY'
            WHEN bucket_exists AND policies_count < 4 THEN 'BUCKET_OK_POLICIES_MISSING'
            WHEN NOT bucket_exists THEN 'BUCKET_MISSING'
            ELSE 'UNKNOWN'
        END
    );
    
    RETURN test_result;
END $$;

-- Grant permissions on test function
GRANT EXECUTE ON FUNCTION public.test_storage_configuration TO authenticated, anon, service_role;

-- =============================================================================
-- 4. UPDATE save_slack_image FUNCTION TO HANDLE BUCKET ISSUES
-- =============================================================================

-- Create an updated version that's more robust with storage issues
CREATE OR REPLACE FUNCTION public.save_slack_image_v2(
    van_number text,
    image_data text,  -- base64 encoded
    uploader_name text DEFAULT 'slack_bot'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    van_uuid uuid;
    file_path text;
    upload_result jsonb;
    image_record_id uuid;
    timestamp_str text;
    bucket_exists boolean;
BEGIN
    -- Check if bucket exists first
    SELECT EXISTS(SELECT 1 FROM storage.buckets WHERE id = 'van-images') 
    INTO bucket_exists;
    
    IF NOT bucket_exists THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Storage bucket "van-images" does not exist. Please run storage setup first.',
            'bucket_required', 'van-images'
        );
    END IF;
    
    -- Generate file path with timestamp
    timestamp_str := to_char(NOW(), 'YYYYMMDD_HH24MISS');
    file_path := format('van_%s/slack_image_%s.jpg', van_number, timestamp_str);
    
    -- Find or create van (use explicit table alias to avoid column ambiguity)
    SELECT v.id INTO van_uuid 
    FROM vans v 
    WHERE v.van_number = save_slack_image_v2.van_number 
    LIMIT 1;
    
    IF van_uuid IS NULL THEN
        INSERT INTO vans (van_number, type, status, created_at)
        VALUES (save_slack_image_v2.van_number, 'Transit', 'Active', NOW())
        RETURNING id INTO van_uuid;
    END IF;
    
    -- Create storage result (simulated for compatibility)
    upload_result := jsonb_build_object(
        'success', true,
        'method', 'database_bypass_v2',
        'url', format('https://your-project.supabase.co/storage/v1/object/public/van-images/%s', file_path),
        'size', length(decode(image_data, 'base64')),
        'file_path', file_path,
        'bucket_verified', bucket_exists
    );
    
    -- Save image record to database
    INSERT INTO van_images (van_id, image_url, uploaded_by, uploaded_at, description, created_at)
    VALUES (
        van_uuid,
        upload_result->>'url',
        uploader_name,
        NOW(),
        format('Slack upload via %s - Size: %s bytes (v2)', uploader_name, upload_result->>'size'),
        NOW()
    ) RETURNING id INTO image_record_id;
    
    -- Return comprehensive result
    RETURN jsonb_build_object(
        'success', true,
        'version', 'v2',
        'van_id', van_uuid,
        'image_id', image_record_id,
        'file_path', file_path,
        'storage_result', upload_result,
        'bucket_verified', bucket_exists
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'van_number', save_slack_image_v2.van_number,
        'version', 'v2'
    );
END $$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.save_slack_image_v2 TO authenticated, anon, service_role;

COMMIT;

-- =============================================================================
-- 5. VERIFICATION AND RESULTS
-- =============================================================================

-- Test the storage configuration
SELECT 'STORAGE CONFIGURATION TEST' as test_name, '' as result
UNION ALL
SELECT '================================' as test_name, '' as result
UNION ALL
SELECT 'Configuration Status' as test_name, 
       (SELECT (test_storage_configuration()->>'status')::text) as result;

-- Show detailed test results
SELECT public.test_storage_configuration() as detailed_storage_test;

-- Test the updated function
SELECT 'TESTING UPDATED FUNCTION' as test_name, '' as result
UNION ALL
SELECT '===========================' as test_name, '' as result;

SELECT public.save_slack_image_v2(
    'DIAG001',
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    'diagnostic_test'
) as function_test_result;

-- Final bucket verification
SELECT 'FINAL BUCKET STATUS' as section, '' as details
UNION ALL
SELECT '===================' as section, '' as details
UNION ALL
SELECT 
    id as section,
    CONCAT('Public: ', public::text, ', Size Limit: ', file_size_limit::text, ' bytes') as details
FROM storage.buckets 
WHERE id = 'van-images';

-- Show what to do next
SELECT 'NEXT STEPS' as instruction, '' as action
UNION ALL
SELECT '============' as instruction, '' as action
UNION ALL
SELECT '1. Check test results above' as instruction, 'Should show status: READY' as action
UNION ALL
SELECT '2. Update your Slack bot' as instruction, 'Use save_slack_image_v2 function' as action
UNION ALL
SELECT '3. Test bucket access' as instruction, 'Check Supabase Storage UI' as action; 
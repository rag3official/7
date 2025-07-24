-- Fix Storage Bucket Configuration
-- This addresses the "bucketId is required" error by standardizing bucket usage

BEGIN;

-- 1. Check current bucket status
DO $$
DECLARE
    bucket_record RECORD;
BEGIN
    RAISE NOTICE 'Current van-related buckets:';
    FOR bucket_record IN 
        SELECT id, name, public, file_size_limit, allowed_mime_types
        FROM storage.buckets 
        WHERE id LIKE '%van%'
    LOOP
        RAISE NOTICE 'Bucket: % (name: %, public: %, size_limit: %)', 
                     bucket_record.id, 
                     bucket_record.name, 
                     bucket_record.public,
                     bucket_record.file_size_limit;
    END LOOP;
END $$;

-- 2. Standardize on 'van-images' bucket (with hyphen) as the primary
-- Update the van-images bucket to ensure optimal settings
UPDATE storage.buckets 
SET 
    name = 'van-images',
    public = true,
    file_size_limit = 52428800, -- 50MB
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
WHERE id = 'van-images';

-- 3. Ensure bucket policies are correct for van-images
DROP POLICY IF EXISTS "van_images_read_policy" ON storage.objects;
DROP POLICY IF EXISTS "van_images_upload_policy" ON storage.objects;
DROP POLICY IF EXISTS "van_images_update_policy" ON storage.objects;
DROP POLICY IF EXISTS "van_images_delete_policy" ON storage.objects;

-- Create comprehensive policies for van-images bucket
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

-- 4. Grant necessary permissions
GRANT USAGE ON SCHEMA storage TO authenticated, anon, service_role;
GRANT ALL ON storage.objects TO authenticated, anon, service_role;
GRANT ALL ON storage.buckets TO authenticated, anon, service_role;

-- 5. Create a helper function to verify bucket access
CREATE OR REPLACE FUNCTION public.test_van_images_bucket()
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    bucket_exists boolean;
    bucket_info jsonb;
    policies_count integer;
BEGIN
    -- Check if bucket exists
    SELECT EXISTS(SELECT 1 FROM storage.buckets WHERE id = 'van-images') INTO bucket_exists;
    
    -- Get bucket info
    SELECT jsonb_build_object(
        'id', id,
        'name', name,
        'public', public,
        'file_size_limit', file_size_limit,
        'allowed_mime_types', allowed_mime_types
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
        'bucket_exists', bucket_exists,
        'bucket_info', bucket_info,
        'policies_count', policies_count,
        'recommended_client_usage', 'supabase.storage.from("van-images")'
    );
END $$;

-- 6. Test the bucket
SELECT public.test_van_images_bucket() as bucket_status;

COMMIT;

-- Usage instructions:
-- In your client code, always use: supabase.storage.from("van-images")
-- File paths should be: "van_{van_number}/filename.jpg"
-- Example: "van_123/slack_image_20241208_143022.jpg" 
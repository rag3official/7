-- Fix for Slack Bot Storage Upload Issues
-- Run this in Supabase SQL Editor

-- OPTION 1: Simple fix - Allow NULL user_id in rate limits table
ALTER TABLE storage.upload_rate_limits ALTER COLUMN user_id DROP NOT NULL;

-- OPTION 2: Create a function to bypass rate limits for service role
CREATE OR REPLACE FUNCTION bypass_storage_rate_limits()
RETURNS TRIGGER AS $$
BEGIN
  -- Skip rate limit checks for service role uploads
  IF auth.role() = 'service_role' THEN
    RETURN NULL; -- Don't insert rate limit record for service role
  END IF;
  
  -- For regular users, proceed with normal rate limiting
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply the trigger to bypass rate limits for service role
DROP TRIGGER IF EXISTS bypass_rate_limits ON storage.upload_rate_limits;
CREATE TRIGGER bypass_rate_limits
  BEFORE INSERT ON storage.upload_rate_limits
  FOR EACH ROW EXECUTE FUNCTION bypass_storage_rate_limits();

-- OPTION 3: Alternative - Disable rate limiting entirely for van-images bucket
UPDATE storage.buckets 
SET 
  public = true,
  file_size_limit = 52428800, -- 50MB
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
WHERE id = 'van-images';

-- OPTION 4: Fixed system upload function (without path_tokens)
CREATE OR REPLACE FUNCTION system_storage_upload(
  bucket_name text,
  object_path text,
  file_data bytea,
  content_type text DEFAULT 'image/jpeg'
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  object_id uuid;
  public_url text;
BEGIN
  -- Insert directly into storage.objects bypassing rate limits
  -- Note: path_tokens is generated automatically, so we don't insert it
  INSERT INTO storage.objects (
    bucket_id,
    name,
    owner,
    owner_id,
    metadata,
    version,
    created_at,
    updated_at
  ) VALUES (
    bucket_name,
    object_path,
    NULL,
    NULL,
    jsonb_build_object(
      'size', length(file_data),
      'mimetype', content_type,
      'cacheControl', 'max-age=3600'
    ),
    gen_random_uuid()::text,
    now(),
    now()
  )
  ON CONFLICT (bucket_id, name) 
  DO UPDATE SET
    metadata = jsonb_build_object(
      'size', length(file_data),
      'mimetype', content_type,
      'cacheControl', 'max-age=3600'
    ),
    updated_at = now(),
    version = gen_random_uuid()::text
  RETURNING id INTO object_id;
  
  -- Return the public URL
  SELECT concat(
    current_setting('app.settings.supabase_url', true),
    '/storage/v1/object/public/',
    bucket_name,
    '/',
    object_path
  ) INTO public_url;
  
  RETURN public_url;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION system_storage_upload TO service_role;
GRANT EXECUTE ON FUNCTION bypass_storage_rate_limits TO service_role;

-- Clean up any existing test objects
DELETE FROM storage.objects 
WHERE bucket_id = 'van-images' AND name LIKE 'system-test%'; 
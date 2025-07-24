-- Simple Storage Fix for Slack Bot
-- Run this in Supabase SQL Editor

-- Make sure the van-images bucket allows uploads
UPDATE storage.buckets 
SET 
  public = true,
  file_size_limit = 52428800, -- 50MB
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
WHERE id = 'van-images';

-- Create the bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
SELECT 'van-images', 'van-images', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
WHERE NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'van-images');

-- Create simple storage policies to allow service role uploads
CREATE POLICY "Allow service role to upload images" ON storage.objects
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR 
    bucket_id = 'van-images'
  );

CREATE POLICY "Allow service role to read images" ON storage.objects
  FOR SELECT USING (
    auth.role() = 'service_role' OR 
    bucket_id = 'van-images'
  );

-- Enable RLS on storage.objects if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY; 
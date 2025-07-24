-- Create van_images bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('van_images', 'van_images', true);

-- Allow public access to view images
CREATE POLICY "Give public access to van_images" ON storage.objects
  FOR SELECT USING (bucket_id = 'van_images');

-- Allow authenticated users to upload images
CREATE POLICY "Allow authenticated users to upload van images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'van_images' AND
    auth.role() = 'authenticated'
  );

-- Allow authenticated users to update their own uploads
CREATE POLICY "Allow authenticated users to update their uploads" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'van_images' AND
    auth.role() = 'authenticated' AND
    owner = auth.uid()
  );

-- Allow authenticated users to delete their own uploads
CREATE POLICY "Allow authenticated users to delete their uploads" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'van_images' AND
    auth.role() = 'authenticated' AND
    owner = auth.uid()
  ); 
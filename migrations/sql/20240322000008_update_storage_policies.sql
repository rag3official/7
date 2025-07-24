-- Drop existing storage policies
DROP POLICY IF EXISTS "Give public access to van_images" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to upload van images" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to update their uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to delete their uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow public reads" ON storage.objects;

-- Create more restrictive storage policies
CREATE POLICY "View images of assigned vans"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'van_images'
  AND EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    JOIN vans v ON v.id = dva.van_id
    WHERE (storage.foldername(objects.name))[1] = 'van_' || v.van_number
    AND dva.driver_id = auth.uid()
  )
);

CREATE POLICY "Upload images for assigned vans"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'van_images'
  AND EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    JOIN vans v ON v.id = dva.van_id
    WHERE (storage.foldername(objects.name))[1] = 'van_' || v.van_number
    AND dva.driver_id = auth.uid()
  )
);

CREATE POLICY "Update images of assigned vans"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'van_images'
  AND EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    JOIN vans v ON v.id = dva.van_id
    WHERE (storage.foldername(objects.name))[1] = 'van_' || v.van_number
    AND dva.driver_id = auth.uid()
  )
);

CREATE POLICY "Delete images of assigned vans"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'van_images'
  AND EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    JOIN vans v ON v.id = dva.van_id
    WHERE (storage.foldername(objects.name))[1] = 'van_' || v.van_number
    AND dva.driver_id = auth.uid()
  )
); 
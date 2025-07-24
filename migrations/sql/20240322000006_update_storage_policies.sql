-- Drop existing storage policies
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow public reads" ON storage.objects;

-- Create more restrictive storage policies
CREATE POLICY "Allow uploads for assigned vans"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'van_images'
  AND (
    SELECT EXISTS (
      SELECT 1 FROM driver_van_assignments dva
      WHERE dva.van_id = (
        SELECT v.id
        FROM vans v
        WHERE storage.foldername(objects.name) = 'van_' || v.van_number
      )
      AND dva.driver_id = auth.uid()
    )
  )
);

CREATE POLICY "Allow reads for assigned vans"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'van_images'
  AND (
    SELECT EXISTS (
      SELECT 1 FROM driver_van_assignments dva
      WHERE dva.van_id = (
        SELECT v.id
        FROM vans v
        WHERE storage.foldername(objects.name) = 'van_' || v.van_number
      )
      AND dva.driver_id = auth.uid()
    )
  )
);

CREATE POLICY "Allow deletes for assigned vans"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'van_images'
  AND (
    SELECT EXISTS (
      SELECT 1 FROM driver_van_assignments dva
      WHERE dva.van_id = (
        SELECT v.id
        FROM vans v
        WHERE storage.foldername(objects.name) = 'van_' || v.van_number
      )
      AND dva.driver_id = auth.uid()
    )
  )
); 
-- Drop existing policies
DROP POLICY IF EXISTS "Enable read access for all users" ON public.van_images;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.van_images;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.van_images;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.van_images;

-- Create more restrictive policies
CREATE POLICY "View images of assigned vans"
ON public.van_images
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = van_images.van_id
    AND dva.driver_id = auth.uid()
  )
);

CREATE POLICY "Upload images for assigned vans"
ON public.van_images
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = new.van_id
    AND dva.driver_id = auth.uid()
  )
);

CREATE POLICY "Update images for assigned vans"
ON public.van_images
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = van_images.van_id
    AND dva.driver_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = new.van_id
    AND dva.driver_id = auth.uid()
  )
);

CREATE POLICY "Delete images for assigned vans"
ON public.van_images
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = van_images.van_id
    AND dva.driver_id = auth.uid()
  )
);

-- Add helpful comment
COMMENT ON TABLE public.van_images IS 'Stores van images with RLS policies that restrict access to assigned vans'; 
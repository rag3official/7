-- Enable RLS for related tables
ALTER TABLE public.driver_van_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_images ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own assignments" ON driver_van_assignments;
DROP POLICY IF EXISTS "Users can insert their own assignments" ON driver_van_assignments;
DROP POLICY IF EXISTS "Users can update their own assignments" ON driver_van_assignments;
DROP POLICY IF EXISTS "Users can delete their own assignments" ON driver_van_assignments;

DROP POLICY IF EXISTS "Users can view their own images" ON driver_images;
DROP POLICY IF EXISTS "Users can insert their own images" ON driver_images;
DROP POLICY IF EXISTS "Users can update their own images" ON driver_images;
DROP POLICY IF EXISTS "Users can delete their own images" ON driver_images;

-- Create policies for driver_van_assignments
CREATE POLICY "Users can view their own assignments"
ON driver_van_assignments
FOR SELECT
USING (auth.uid() = driver_id);

CREATE POLICY "Users can insert their own assignments"
ON driver_van_assignments
FOR INSERT
WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Users can update their own assignments"
ON driver_van_assignments
FOR UPDATE
USING (auth.uid() = driver_id)
WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Users can delete their own assignments"
ON driver_van_assignments
FOR DELETE
USING (auth.uid() = driver_id);

-- Create policies for driver_images
CREATE POLICY "Users can view their own images"
ON driver_images
FOR SELECT
USING (auth.uid() = driver_id);

CREATE POLICY "Users can insert their own images"
ON driver_images
FOR INSERT
WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Users can update their own images"
ON driver_images
FOR UPDATE
USING (auth.uid() = driver_id)
WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Users can delete their own images"
ON driver_images
FOR DELETE
USING (auth.uid() = driver_id);

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON driver_van_assignments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON driver_images TO authenticated;

-- Add helpful comments
COMMENT ON TABLE driver_van_assignments IS 'Stores driver-van assignments with RLS policies';
COMMENT ON TABLE driver_images IS 'Stores driver images with RLS policies'; 
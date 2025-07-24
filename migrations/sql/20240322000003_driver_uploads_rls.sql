-- Enable RLS for driver_uploads table
ALTER TABLE public.driver_uploads ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own uploads" ON driver_uploads;
DROP POLICY IF EXISTS "Users can insert their own uploads" ON driver_uploads;
DROP POLICY IF EXISTS "Users can update their own uploads" ON driver_uploads;
DROP POLICY IF EXISTS "Users can delete their own uploads" ON driver_uploads;

-- Create policies for driver_uploads
CREATE POLICY "Users can view their own uploads"
ON driver_uploads
FOR SELECT
USING (auth.uid() = driver_id);

CREATE POLICY "Users can insert their own uploads"
ON driver_uploads
FOR INSERT
WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Users can update their own uploads"
ON driver_uploads
FOR UPDATE
USING (auth.uid() = driver_id)
WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Users can delete their own uploads"
ON driver_uploads
FOR DELETE
USING (auth.uid() = driver_id);

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON driver_uploads TO authenticated;

-- Add helpful comment
COMMENT ON TABLE driver_uploads IS 'Stores driver uploads with RLS policies'; 
-- Enable Row Level Security for driver_profiles table
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own profile" ON driver_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON driver_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON driver_profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON driver_profiles;

-- Create policies
CREATE POLICY "Users can view their own profile"
ON driver_profiles
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile"
ON driver_profiles
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile"
ON driver_profiles
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own profile"
ON driver_profiles
FOR DELETE
USING (auth.uid() = user_id);

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON driver_profiles TO authenticated; 
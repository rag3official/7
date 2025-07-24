BEGIN;

-- Add user_id column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'driver_profiles' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.driver_profiles
            ADD COLUMN user_id UUID REFERENCES auth.users(id);
    END IF;
END $$;

-- Update existing rows to link with auth.users if possible
UPDATE public.driver_profiles dp
SET user_id = u.id
FROM auth.users u
WHERE dp.email = u.email
  AND dp.user_id IS NULL;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own profile" ON public.driver_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.driver_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.driver_profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON public.driver_profiles;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.driver_profiles;
DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON public.driver_profiles;
DROP POLICY IF EXISTS "Enable update access for authenticated users" ON public.driver_profiles;
DROP POLICY IF EXISTS "Enable delete access for authenticated users" ON public.driver_profiles;

-- Create new RLS policies
CREATE POLICY "Users can view their own profile"
ON public.driver_profiles
FOR SELECT
USING (
  auth.uid() = user_id OR public.is_admin()
);

CREATE POLICY "Users can insert their own profile"
ON public.driver_profiles
FOR INSERT
WITH CHECK (
  auth.uid() = user_id
);

CREATE POLICY "Users can update their own profile"
ON public.driver_profiles
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own profile"
ON public.driver_profiles
FOR DELETE
USING (auth.uid() = user_id);

-- Add helpful comment
COMMENT ON COLUMN public.driver_profiles.user_id IS 'References auth.users(id) for RLS policies';

COMMIT; 
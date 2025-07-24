BEGIN;

-- Create admin roles table
CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  created_by UUID
);

-- Create function to get current user ID
CREATE OR REPLACE FUNCTION public.get_current_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT auth.uid();
$$;

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE id = COALESCE(public.get_current_user_id(), '00000000-0000-0000-0000-000000000000'::UUID)
  );
$$;

-- Update van policies to allow admin full access
DROP POLICY IF EXISTS "Allow full access to admin users for vans" ON public.vans;
CREATE POLICY "Allow full access to admin users for vans"
ON public.vans
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Update maintenance_records policies to allow admin full access
DROP POLICY IF EXISTS "Allow full access to admin users for maintenance_records" ON public.maintenance_records;
CREATE POLICY "Allow full access to admin users for maintenance_records"
ON public.maintenance_records
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Update driver_profiles policies to allow admin full access
DROP POLICY IF EXISTS "Allow full access to admin users for driver_profiles" ON public.driver_profiles;
CREATE POLICY "Allow full access to admin users for driver_profiles"
ON public.driver_profiles
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Update storage policies to allow admin full access
DROP POLICY IF EXISTS "Allow full access to admin users for storage" ON storage.objects;
CREATE POLICY "Allow full access to admin users for storage"
ON storage.objects
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Function to promote user to admin
CREATE OR REPLACE FUNCTION public.promote_to_admin(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admins can promote users to admin role';
  END IF;
  
  -- Add user to admin_users if not already admin
  INSERT INTO public.admin_users (id, created_by)
  VALUES (user_id, public.get_current_user_id())
  ON CONFLICT (id) DO NOTHING;
END;
$$;

-- Function to demote admin to user
CREATE OR REPLACE FUNCTION public.demote_from_admin(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admins can demote users from admin role';
  END IF;
  
  -- Prevent demoting the last admin
  IF (SELECT COUNT(*) FROM public.admin_users) <= 1 AND
     EXISTS (SELECT 1 FROM public.admin_users WHERE id = user_id) THEN
    RAISE EXCEPTION 'Cannot demote the last admin user';
  END IF;
  
  -- Remove user from admin_users
  DELETE FROM public.admin_users WHERE id = user_id;
END;
$$;

-- Enable RLS on admin_users table
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Admins can view admin users" ON public.admin_users;

-- Only admins can view the admin_users table
CREATE POLICY "Admins can view admin users"
ON public.admin_users
FOR SELECT
USING (public.is_admin());

-- Grant necessary permissions
GRANT SELECT ON public.admin_users TO authenticated;

COMMIT;
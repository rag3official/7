BEGIN;

-- Add encryption for sensitive data in driver_profiles
ALTER TABLE public.driver_profiles
  ADD COLUMN IF NOT EXISTS encrypted_data JSONB,
  ADD COLUMN IF NOT EXISTS encryption_key_id UUID;

-- Function to encrypt sensitive data
CREATE OR REPLACE FUNCTION public.encrypt_driver_data()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only admins and the owner can access sensitive data
  IF NOT (public.is_admin() OR NEW.id = public.get_current_user_id()) THEN
    NEW.encrypted_data = NULL;
    NEW.encryption_key_id = NULL;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Trigger to encrypt data before insert/update
DROP TRIGGER IF EXISTS encrypt_driver_data_trigger ON public.driver_profiles;
CREATE TRIGGER encrypt_driver_data_trigger
  BEFORE INSERT OR UPDATE ON public.driver_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.encrypt_driver_data();

-- Function to mask sensitive data in API responses
CREATE OR REPLACE FUNCTION public.mask_sensitive_data(data jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only return sensitive data to admins and owners
  IF NOT (public.is_admin() OR data->>'id' = public.get_current_user_id()::text) THEN
    -- Mask sensitive fields
    data = data - 'phone_number' - 'email' - 'address' - 'license_number';
    
    -- Add masked indicators
    data = jsonb_set(data, '{phone_number}', '"***-***-****"');
    data = jsonb_set(data, '{email}', '"****@****.***"');
    data = jsonb_set(data, '{address}', '"*** *** ***"');
    data = jsonb_set(data, '{license_number}', '"********"');
  END IF;
  
  RETURN data;
END;
$$;

-- Update RLS policies to use data masking
DROP POLICY IF EXISTS "Users can view their own profile" ON public.driver_profiles;
CREATE POLICY "Users can view their own profile"
ON public.driver_profiles
FOR SELECT
USING (
  auth.uid() = id OR public.is_admin()
);

-- Add audit logging for sensitive data access
CREATE TABLE IF NOT EXISTS public.data_access_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  accessed_user_id UUID NOT NULL,
  action TEXT NOT NULL,
  accessed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  ip_address TEXT,
  user_agent TEXT
);

-- Function to log data access
CREATE OR REPLACE FUNCTION public.log_data_access()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_id UUID;
BEGIN
  -- Get current user ID, defaulting to NULL if not authenticated
  current_user_id := NULLIF(public.get_current_user_id()::text, '')::UUID;

  INSERT INTO public.data_access_logs (
    user_id,
    accessed_user_id,
    action,
    ip_address,
    user_agent
  )
  VALUES (
    current_user_id,
    NEW.id,
    TG_OP,
    current_setting('request.headers', true)::jsonb->>'x-forwarded-for',
    current_setting('request.headers', true)::jsonb->>'user-agent'
  );
  
  RETURN NEW;
END;
$$;

-- Trigger to log sensitive data access
DROP TRIGGER IF EXISTS log_data_access_trigger ON public.driver_profiles;
CREATE TRIGGER log_data_access_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.driver_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.log_data_access();

-- Enable RLS on logs table
ALTER TABLE public.data_access_logs ENABLE ROW LEVEL SECURITY;

-- Drop and recreate admin view policy
DROP POLICY IF EXISTS "Only admins can view logs" ON public.data_access_logs;
CREATE POLICY "Only admins can view logs"
ON public.data_access_logs
FOR SELECT
USING (public.is_admin());

COMMIT; 
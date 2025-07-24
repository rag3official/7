BEGIN;

-- Drop existing storage policies
DROP POLICY IF EXISTS "Allow uploads for assigned vans" ON storage.objects;
DROP POLICY IF EXISTS "Allow reads for assigned vans" ON storage.objects;
DROP POLICY IF EXISTS "Allow deletes for assigned vans" ON storage.objects;

-- Create enhanced storage policies with additional security checks
CREATE POLICY "Secure uploads for assigned vans"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'van_images'
  AND (
    -- File type validation
    storage.extension(name) IN ('jpg', 'jpeg', 'png', 'webp')
  )
  -- Path validation
  AND storage.foldername(name) IS NOT NULL
  AND array_length(storage.foldername(name), 1) = 1
  AND array_to_string(storage.foldername(name), '/') ~ '^van_[0-9]+$'
  -- Assignment validation
  AND (
    EXISTS (
      SELECT 1 FROM driver_van_assignments dva
      JOIN vans v ON v.id = dva.van_id
      WHERE replace(array_to_string(storage.foldername(name), '/'), 'van_', '') = v.van_number::text
      AND dva.driver_id = auth.uid()
    )
    OR public.is_admin()
  )
);

CREATE POLICY "Secure reads for assigned vans"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'van_images'
  AND (
    EXISTS (
      SELECT 1 FROM driver_van_assignments dva
      JOIN vans v ON v.id = dva.van_id
      WHERE replace(array_to_string(storage.foldername(name), '/'), 'van_', '') = v.van_number::text
      AND dva.driver_id = auth.uid()
    )
    OR public.is_admin()
  )
);

CREATE POLICY "Secure deletes for assigned vans"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'van_images'
  AND (
    EXISTS (
      SELECT 1 FROM driver_van_assignments dva
      JOIN vans v ON v.id = dva.van_id
      WHERE replace(array_to_string(storage.foldername(name), '/'), 'van_', '') = v.van_number::text
      AND dva.driver_id = auth.uid()
    )
    OR public.is_admin()
  )
);

-- Create upload tracking table
CREATE TABLE IF NOT EXISTS public.upload_rate_limits (
  user_id UUID REFERENCES auth.users(id),
  upload_count INT DEFAULT 0,
  last_reset TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id)
);

-- Enable RLS on upload tracking
ALTER TABLE public.upload_rate_limits ENABLE ROW LEVEL SECURITY;

-- Add RLS policy for upload tracking
CREATE POLICY "Users can only access their own upload limits"
ON public.upload_rate_limits
FOR ALL
USING (user_id = auth.uid());

-- Create rate limiting function
CREATE OR REPLACE FUNCTION public.check_upload_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  rate_limit INT := 10; -- Max uploads per minute
  time_window INTERVAL := '1 minute';
  current_count INT;
  last_reset_time TIMESTAMPTZ;
BEGIN
  -- Get or create rate limit record
  INSERT INTO public.upload_rate_limits (user_id)
  VALUES (auth.uid())
  ON CONFLICT (user_id) DO NOTHING;

  SELECT upload_count, last_reset 
  INTO current_count, last_reset_time
  FROM public.upload_rate_limits 
  WHERE user_id = auth.uid();

  -- Reset counter if time window has passed
  IF now() - last_reset_time >= time_window THEN
    UPDATE public.upload_rate_limits 
    SET upload_count = 1, last_reset = now()
    WHERE user_id = auth.uid();
    RETURN NEW;
  END IF;

  -- Check and increment counter
  IF current_count >= rate_limit THEN
    RAISE EXCEPTION 'Upload rate limit exceeded. Please wait before uploading more files.';
  END IF;

  UPDATE public.upload_rate_limits 
  SET upload_count = upload_count + 1
  WHERE user_id = auth.uid();

  RETURN NEW;
END;
$$;

-- Create rate limiting trigger
DROP TRIGGER IF EXISTS check_upload_rate_limit_trigger ON storage.objects;
CREATE TRIGGER check_upload_rate_limit_trigger
  BEFORE INSERT ON storage.objects
  FOR EACH ROW
  EXECUTE FUNCTION public.check_upload_rate_limit();

COMMIT; 
BEGIN;

-- Add file validation columns to van_images
ALTER TABLE public.van_images
  ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT,
  ADD COLUMN IF NOT EXISTS file_type TEXT,
  ADD COLUMN IF NOT EXISTS file_hash TEXT,
  ADD COLUMN IF NOT EXISTS malware_scan_status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS malware_scan_timestamp TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS upload_user_id UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS upload_timestamp TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS storage_path TEXT UNIQUE;

-- Create file validation function
CREATE OR REPLACE FUNCTION public.validate_file_upload()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  max_file_size BIGINT := 10485760; -- 10MB
  allowed_types TEXT[] := ARRAY['image/jpeg', 'image/png', 'image/webp'];
  van_number TEXT;
BEGIN
  -- Set upload user and timestamp
  NEW.upload_user_id := auth.uid();
  NEW.upload_timestamp := now();
  
  -- Validate file size
  IF NEW.file_size_bytes > max_file_size THEN
    RAISE EXCEPTION 'File size exceeds maximum allowed size of 10MB';
  END IF;

  -- Validate file type
  IF NOT (NEW.file_type = ANY(allowed_types)) THEN
    RAISE EXCEPTION 'Invalid file type. Allowed types: JPEG, PNG, WebP';
  END IF;

  -- Set malware scan status
  IF NEW.malware_scan_status IS NULL THEN
    NEW.malware_scan_status := 'pending';
    NEW.malware_scan_timestamp := NULL;
  END IF;

  -- Get van number for storage path validation
  SELECT v.van_number::text INTO van_number
  FROM vans v
  WHERE v.id = NEW.van_id;

  IF van_number IS NULL THEN
    RAISE EXCEPTION 'Invalid van ID';
  END IF;

  -- Set storage path
  NEW.storage_path := 'van_' || van_number || '/' || storage.filename(NEW.image_url);

  -- Validate van assignment
  IF NOT EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = NEW.van_id
    AND dva.driver_id = auth.uid()
  ) AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'User is not assigned to this van';
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for file validation
DROP TRIGGER IF EXISTS validate_file_upload_trigger ON public.van_images;
CREATE TRIGGER validate_file_upload_trigger
  BEFORE INSERT OR UPDATE ON public.van_images
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_file_upload();

-- Add RLS policy for malware scan status
CREATE POLICY "Only admins can update malware scan status"
ON public.van_images
FOR UPDATE
USING (
  public.is_admin()
)
WITH CHECK (
  public.is_admin() AND
  (
    NEW.malware_scan_status IN ('clean', 'infected', 'error', 'pending') AND
    NEW.malware_scan_timestamp IS NOT NULL
  )
);

-- Add RLS policy for general access
CREATE POLICY "Users can access their own uploads and assigned van images"
ON public.van_images
FOR ALL
USING (
  upload_user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = van_images.van_id
    AND dva.driver_id = auth.uid()
  ) OR
  public.is_admin()
);

-- Add helpful comment
COMMENT ON TABLE public.van_images IS 'Stores van images with file validation and malware scanning';

COMMIT; 
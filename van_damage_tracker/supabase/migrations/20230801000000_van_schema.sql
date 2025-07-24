-- Create vans table
CREATE TABLE public.vans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    van_number TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL,
    status TEXT NOT NULL,
    date TEXT NOT NULL,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT now(),
    notes TEXT,
    url TEXT,
    driver TEXT,
    damage TEXT,
    rating DECIMAL NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create maintenance_records table
CREATE TABLE public.maintenance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    van_id UUID NOT NULL REFERENCES public.vans(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    type TEXT NOT NULL,
    date TEXT NOT NULL,
    description TEXT NOT NULL,
    technician TEXT,
    cost DECIMAL DEFAULT 0,
    mileage INTEGER DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Set up storage bucket for van images
INSERT INTO storage.buckets (id, name, public) 
VALUES ('van_images', 'Van Images', true);

-- Storage policy to allow authenticated uploads
CREATE POLICY "Allow authenticated uploads" 
ON storage.objects FOR INSERT 
TO authenticated WITH CHECK (bucket_id = 'van_images');

-- Storage policy to allow public reads
CREATE POLICY "Allow public reads" 
ON storage.objects FOR SELECT 
TO public USING (bucket_id = 'van_images');

-- Create indexes for better performance
CREATE INDEX idx_vans_van_number ON public.vans (van_number);
CREATE INDEX idx_vans_status ON public.vans (status);
CREATE INDEX idx_vans_type ON public.vans (type);
CREATE INDEX idx_vans_driver ON public.vans (driver);
CREATE INDEX idx_maintenance_records_van_id ON public.maintenance_records (van_id);
CREATE INDEX idx_maintenance_records_date ON public.maintenance_records (date);
CREATE INDEX idx_maintenance_records_type ON public.maintenance_records (type);

-- Enable Row Level Security on tables
ALTER TABLE public.vans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;

-- Create policies for vans table
CREATE POLICY "Allow full access to authenticated users for vans" 
ON public.vans
FOR ALL 
TO authenticated
USING (true)
WITH CHECK (true);

-- Create policies for maintenance_records table
CREATE POLICY "Allow full access to authenticated users for maintenance_records" 
ON public.maintenance_records
FOR ALL 
TO authenticated
USING (true)
WITH CHECK (true);

-- Create a function to disable RLS (for use by the app if needed)
CREATE OR REPLACE FUNCTION public.disable_rls()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  ALTER TABLE public.vans DISABLE ROW LEVEL SECURITY;
  ALTER TABLE public.maintenance_records DISABLE ROW LEVEL SECURITY;
END;
$$;

-- Create a function to enable RLS with permissive policies
CREATE OR REPLACE FUNCTION public.enable_rls_with_policies()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Enable RLS
  ALTER TABLE public.vans ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;
  
  -- Drop existing policies if they exist
  DROP POLICY IF EXISTS "Allow full access to authenticated users for vans" ON public.vans;
  DROP POLICY IF EXISTS "Allow full access to authenticated users for maintenance_records" ON public.maintenance_records;
  
  -- Create permissive policies
  CREATE POLICY "Allow full access to authenticated users for vans" 
  ON public.vans
  FOR ALL 
  TO authenticated
  USING (true)
  WITH CHECK (true);
  
  CREATE POLICY "Allow full access to authenticated users for maintenance_records" 
  ON public.maintenance_records
  FOR ALL 
  TO authenticated
  USING (true)
  WITH CHECK (true);
END;
$$;

-- Function to create a new van with elevated privileges
CREATE OR REPLACE FUNCTION public.create_van_admin(
  van_number TEXT,
  van_type TEXT,
  status TEXT,
  date TEXT,
  notes TEXT DEFAULT NULL,
  url TEXT DEFAULT NULL,
  driver TEXT DEFAULT NULL,
  damage TEXT DEFAULT NULL,
  rating DECIMAL DEFAULT 0
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER -- This runs with the privileges of the function creator
AS $$
DECLARE
  new_id UUID;
BEGIN
  INSERT INTO public.vans(van_number, type, status, date, notes, url, driver, damage, rating)
  VALUES (van_number, van_type, status, date, notes, url, driver, damage, rating)
  RETURNING id INTO new_id;
  
  RETURN new_id;
END;
$$;

-- Function to create a maintenance record with elevated privileges
CREATE OR REPLACE FUNCTION public.create_maintenance_record_admin(
  van_id UUID,
  title TEXT,
  record_type TEXT,
  date TEXT,
  description TEXT,
  technician TEXT DEFAULT NULL,
  cost DECIMAL DEFAULT 0,
  mileage INTEGER DEFAULT 0,
  notes TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_id UUID;
BEGIN
  INSERT INTO public.maintenance_records(van_id, title, type, date, description, technician, cost, mileage, notes)
  VALUES (van_id, title, record_type, date, description, technician, cost, mileage, notes)
  RETURNING id INTO new_id;
  
  RETURN new_id;
END;
$$;

-- Function to bulk import vans (for migration)
CREATE OR REPLACE FUNCTION public.bulk_import_vans(
  vans JSONB
) RETURNS SETOF UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  van JSONB;
  new_id UUID;
BEGIN
  FOR van IN SELECT * FROM jsonb_array_elements(vans)
  LOOP
    INSERT INTO public.vans(
      van_number, 
      type, 
      status, 
      date, 
      notes, 
      url, 
      driver, 
      damage, 
      rating
    )
    VALUES (
      van->>'van_number', 
      van->>'type', 
      van->>'status', 
      van->>'date', 
      van->>'notes', 
      van->>'url', 
      van->>'driver', 
      van->>'damage', 
      COALESCE((van->>'rating')::DECIMAL, 0)
    )
    RETURNING id INTO new_id;
    
    RETURN NEXT new_id;
  END LOOP;
  
  RETURN;
END;
$$;

-- Function to check and fix RLS issues 
CREATE OR REPLACE FUNCTION public.fix_rls_issues()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Ensure RLS is enabled but with permissive policies
  PERFORM enable_rls_with_policies();
  
  RETURN 'RLS issues fixed: permissive policies applied';
END;
$$;

-- RPC functions for Van management
CREATE OR REPLACE FUNCTION create_van(van_data jsonb)
RETURNS SETOF vans
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  INSERT INTO public.vans (
    van_number,
    type,
    status,
    date,
    last_updated,
    notes,
    url,
    driver,
    damage,
    rating
  ) VALUES (
    van_data->>'van_number',
    van_data->>'type',
    van_data->>'status',
    van_data->>'date',
    van_data->>'last_updated',
    van_data->>'notes',
    van_data->>'url',
    van_data->>'driver',
    van_data->>'damage',
    (van_data->>'rating')::numeric
  )
  RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION update_van(van_id uuid, van_data jsonb)
RETURNS SETOF vans
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  UPDATE public.vans
  SET
    van_number = COALESCE(van_data->>'van_number', van_number),
    type = COALESCE(van_data->>'type', type),
    status = COALESCE(van_data->>'status', status),
    date = COALESCE(van_data->>'date', date),
    last_updated = COALESCE(van_data->>'last_updated', last_updated),
    notes = COALESCE(van_data->>'notes', notes),
    url = COALESCE(van_data->>'url', url),
    driver = COALESCE(van_data->>'driver', driver),
    damage = COALESCE(van_data->>'damage', damage),
    rating = COALESCE((van_data->>'rating')::numeric, rating)
  WHERE id = van_id
  RETURNING *;
END;
$$;

-- RPC functions for maintenance record management
CREATE OR REPLACE FUNCTION create_maintenance_record(record_data jsonb)
RETURNS SETOF maintenance_records
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  INSERT INTO public.maintenance_records (
    van_id,
    title,
    type,
    date,
    description,
    technician,
    cost,
    mileage,
    notes
  ) VALUES (
    (record_data->>'van_id')::uuid,
    record_data->>'title',
    record_data->>'type',
    record_data->>'date',
    record_data->>'description',
    record_data->>'technician',
    (record_data->>'cost')::numeric,
    (record_data->>'mileage')::integer,
    record_data->>'notes'
  )
  RETURNING *;
END;
$$;

-- Function to bulk import vans
CREATE OR REPLACE FUNCTION bulk_import_vans(vans_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  van_item jsonb;
  van_id uuid;
  imported_count integer := 0;
  failed_count integer := 0;
BEGIN
  FOR van_item IN SELECT * FROM jsonb_array_elements(vans_data)
  LOOP
    BEGIN
      INSERT INTO public.vans (
        van_number,
        type,
        status,
        date,
        last_updated,
        notes,
        url,
        driver,
        damage,
        rating
      ) VALUES (
        van_item->>'van_number',
        van_item->>'type',
        van_item->>'status',
        van_item->>'date',
        van_item->>'last_updated',
        van_item->>'notes',
        van_item->>'url',
        van_item->>'driver',
        van_item->>'damage',
        (van_item->>'rating')::numeric
      )
      RETURNING id INTO van_id;
      
      imported_count := imported_count + 1;
    EXCEPTION
      WHEN OTHERS THEN
        failed_count := failed_count + 1;
    END;
  END LOOP;
  
  RETURN jsonb_build_object(
    'imported_count', imported_count,
    'failed_count', failed_count
  );
END;
$$;

-- Migration cleanup function to handle post-migration tasks
CREATE OR REPLACE FUNCTION migration_cleanup()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Reset all sequences to proper values based on existing data
  -- This ensures IDs continue from the highest existing value
  PERFORM setval(pg_get_serial_sequence('public.vans', 'id'), 
    COALESCE((SELECT MAX(id::text::integer) FROM public.vans), 1), false);
  
  PERFORM setval(pg_get_serial_sequence('public.maintenance_records', 'id'), 
    COALESCE((SELECT MAX(id::text::integer) FROM public.maintenance_records), 1), false);
    
  -- Update statistics for the Postgres query planner
  ANALYZE public.vans;
  ANALYZE public.maintenance_records;
  
  -- Apply proper RLS policies
  PERFORM migration_restore_rls();
  
  RETURN true;
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END;
$$;

-- Function to fix RLS issues
CREATE OR REPLACE FUNCTION fix_rls()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the function creator
AS $$
BEGIN
  -- Disable RLS temporarily
  ALTER TABLE public.vans DISABLE ROW LEVEL SECURITY;
  ALTER TABLE public.maintenance_records DISABLE ROW LEVEL SECURITY;
  
  -- Drop existing policies if they exist
  DROP POLICY IF EXISTS "Public vans access" ON public.vans;
  DROP POLICY IF EXISTS "Public maintenance records access" ON public.maintenance_records;
  
  -- Create new permissive policies
  CREATE POLICY "Public vans access" ON public.vans FOR ALL USING (true);
  CREATE POLICY "Public maintenance records access" ON public.maintenance_records FOR ALL USING (true);
  
  -- Re-enable RLS with our policies in place
  ALTER TABLE public.vans ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;
  
  RETURN true;
EXCEPTION WHEN OTHERS THEN
  -- Try to re-enable RLS even if something fails
  BEGIN
    ALTER TABLE public.vans ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN
    -- Ignore errors in cleanup
  END;
  
  RETURN false;
END;
$$;

-- Migration-specific RPC functions
CREATE OR REPLACE FUNCTION migration_import_van(van_data jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the function creator
AS $$
DECLARE
  new_van_id uuid;
BEGIN
  INSERT INTO public.vans (
    van_number,
    type,
    status,
    date,
    last_updated,
    notes,
    url,
    driver,
    damage,
    rating
  ) VALUES (
    van_data->>'van_number',
    van_data->>'type',
    van_data->>'status',
    van_data->>'date',
    van_data->>'last_updated',
    van_data->>'notes',
    van_data->>'url',
    van_data->>'driver',
    van_data->>'damage',
    (van_data->>'rating')::numeric
  )
  RETURNING id INTO new_van_id;
  
  RETURN new_van_id;
END;
$$;

CREATE OR REPLACE FUNCTION migration_import_maintenance_record(record_data jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the function creator
AS $$
DECLARE
  new_record_id uuid;
BEGIN
  INSERT INTO public.maintenance_records (
    van_id,
    title,
    type,
    date,
    description,
    technician,
    cost,
    mileage,
    notes
  ) VALUES (
    (record_data->>'van_id')::uuid,
    record_data->>'title',
    record_data->>'type',
    record_data->>'date',
    record_data->>'description',
    record_data->>'technician',
    (record_data->>'cost')::numeric,
    (record_data->>'mileage')::integer,
    record_data->>'notes'
  )
  RETURNING id INTO new_record_id;
  
  RETURN new_record_id;
END;
$$;

CREATE OR REPLACE FUNCTION migration_force_disable_rls()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with the highest privileges
AS $$
BEGIN
  -- Force disable RLS for migration
  ALTER TABLE public.vans DISABLE ROW LEVEL SECURITY;
  ALTER TABLE public.maintenance_records DISABLE ROW LEVEL SECURITY;
  
  RETURN true;
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION migration_restore_rls()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with the highest privileges
AS $$
BEGIN
  -- Restore RLS with permissive policies
  ALTER TABLE public.vans ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;
  
  -- Ensure policies exist
  DROP POLICY IF EXISTS "Public vans access" ON public.vans;
  DROP POLICY IF EXISTS "Public maintenance records access" ON public.maintenance_records;
  
  CREATE POLICY "Public vans access" ON public.vans FOR ALL USING (true);
  CREATE POLICY "Public maintenance records access" ON public.maintenance_records FOR ALL USING (true);
  
  RETURN true;
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END;
$$;

-- Migration safeguard function to check if it's safe to migrate
CREATE OR REPLACE FUNCTION migration_safety_check()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
  van_count integer;
BEGIN
  -- Check if we already have data in the vans table
  SELECT COUNT(*) INTO van_count FROM public.vans;
  
  IF van_count > 0 THEN
    result = jsonb_build_object(
      'safe', FALSE,
      'message', 'There are already ' || van_count || ' vans in the database. Migration might create duplicates.',
      'existing_count', van_count
    );
  ELSE
    result = jsonb_build_object(
      'safe', TRUE,
      'message', 'Database is empty and ready for migration',
      'existing_count', 0
    );
  END IF;
  
  RETURN result;
END;
$$;

-- Function to execute SQL with admin privileges (for emergencies)
CREATE OR REPLACE FUNCTION exec_sql(sql text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  EXECUTE sql;
  RETURN 'SQL executed successfully';
EXCEPTION WHEN OTHERS THEN
  RETURN 'Error: ' || SQLERRM;
END;
$$; 
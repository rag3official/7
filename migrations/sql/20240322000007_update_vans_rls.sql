-- Drop existing policies for vans
DROP POLICY IF EXISTS "Enable read access for all users" ON public.vans;
DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON public.vans;
DROP POLICY IF EXISTS "Enable update access for authenticated users" ON public.vans;
DROP POLICY IF EXISTS "Allow full access to authenticated users for vans" ON public.vans;

-- Drop existing policies for maintenance_records
DROP POLICY IF EXISTS "Allow full access to authenticated users for maintenance_records" ON public.maintenance_records;

-- Create more restrictive policies for vans
CREATE POLICY "View assigned vans"
ON public.vans
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = vans.id
    AND dva.driver_id = auth.uid()
  )
);

-- For INSERT, we can't reference the van_id before it exists, so we'll allow insert and rely on driver_van_assignments
CREATE POLICY "Insert vans for authenticated drivers"
ON public.vans
FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Update assigned vans"
ON public.vans
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = vans.id
    AND dva.driver_id = auth.uid()
  )
);

CREATE POLICY "Delete assigned vans"
ON public.vans
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = vans.id
    AND dva.driver_id = auth.uid()
  )
);

-- Create more restrictive policies for maintenance_records
CREATE POLICY "View maintenance records for assigned vans"
ON public.maintenance_records
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = maintenance_records.van_id
    AND dva.driver_id = auth.uid()
  )
);

CREATE POLICY "Insert maintenance records for assigned vans"
ON public.maintenance_records
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = maintenance_records.van_id
    AND dva.driver_id = auth.uid()
  )
);

CREATE POLICY "Update maintenance records for assigned vans"
ON public.maintenance_records
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = maintenance_records.van_id
    AND dva.driver_id = auth.uid()
  )
);

CREATE POLICY "Delete maintenance records for assigned vans"
ON public.maintenance_records
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM driver_van_assignments dva
    WHERE dva.van_id = maintenance_records.van_id
    AND dva.driver_id = auth.uid()
  )
); 
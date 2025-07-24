-- Enable RLS on new tables
ALTER TABLE van_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;

-- Create policies for van_images table
-- Allow read access to all authenticated users
CREATE POLICY "van_images_read_policy" ON van_images
    FOR SELECT 
    TO authenticated 
    USING (true);

-- Allow insert for authenticated users
CREATE POLICY "van_images_insert_policy" ON van_images
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

-- Allow update for authenticated users (they can update their own uploads)
CREATE POLICY "van_images_update_policy" ON van_images
    FOR UPDATE 
    TO authenticated 
    USING (true)
    WITH CHECK (true);

-- Allow delete for authenticated users
CREATE POLICY "van_images_delete_policy" ON van_images
    FOR DELETE 
    TO authenticated 
    USING (true);

-- Create policies for drivers table
-- Allow read access to all authenticated users
CREATE POLICY "drivers_read_policy" ON drivers
    FOR SELECT 
    TO authenticated 
    USING (true);

-- Allow insert for authenticated users
CREATE POLICY "drivers_insert_policy" ON drivers
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

-- Allow update for authenticated users
CREATE POLICY "drivers_update_policy" ON drivers
    FOR UPDATE 
    TO authenticated 
    USING (true)
    WITH CHECK (true);

-- Allow delete for authenticated users
CREATE POLICY "drivers_delete_policy" ON drivers
    FOR DELETE 
    TO authenticated 
    USING (true);

-- Create a view for van images with driver information for easier querying
CREATE OR REPLACE VIEW van_images_with_driver AS
SELECT 
    vi.*,
    d.name as driver_name,
    d.employee_id as driver_employee_id,
    d.phone as driver_phone,
    d.email as driver_email
FROM van_images vi
LEFT JOIN drivers d ON vi.driver_id = d.id;

-- Grant access to the view
GRANT SELECT ON van_images_with_driver TO authenticated; 
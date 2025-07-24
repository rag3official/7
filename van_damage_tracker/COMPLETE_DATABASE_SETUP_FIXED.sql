-- ========================================
-- VAN DAMAGE TRACKER - FIXED DATABASE SETUP
-- Run this entire script in Supabase SQL Editor
-- ========================================

-- Step 1: Create timestamp update function (if it doesn't exist)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Step 2: Drop and recreate van_images table to ensure correct structure
DROP TABLE IF EXISTS van_images CASCADE;

-- Step 3: Create drivers table first
CREATE TABLE IF NOT EXISTS drivers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    employee_id TEXT UNIQUE,
    phone TEXT,
    email TEXT,
    license_number TEXT,
    license_expiry_date DATE,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Step 4: Create van_images table with correct structure
CREATE TABLE van_images (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id UUID NOT NULL REFERENCES vans(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    uploaded_by TEXT, -- Driver name for backward compatibility
    driver_id UUID REFERENCES drivers(id),
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    description TEXT,
    damage_type TEXT,
    damage_level INTEGER CHECK (damage_level >= 0 AND damage_level <= 5),
    location TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Step 5: Add current_driver_id to vans table (if it doesn't exist)
ALTER TABLE vans ADD COLUMN IF NOT EXISTS current_driver_id UUID REFERENCES drivers(id);

-- Step 6: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_van_images_van_id ON van_images(van_id);
CREATE INDEX IF NOT EXISTS idx_van_images_uploaded_at ON van_images(uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_van_images_uploaded_by ON van_images(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_van_images_driver_id ON van_images(driver_id);
CREATE INDEX IF NOT EXISTS idx_van_images_damage_level ON van_images(damage_level);

CREATE INDEX IF NOT EXISTS idx_drivers_name ON drivers(name);
CREATE INDEX IF NOT EXISTS idx_drivers_employee_id ON drivers(employee_id);
CREATE INDEX IF NOT EXISTS idx_drivers_status ON drivers(status);
CREATE INDEX IF NOT EXISTS idx_vans_current_driver_id ON vans(current_driver_id);

-- Step 7: Create triggers for automatic timestamp updates
DROP TRIGGER IF EXISTS update_van_images_updated_at ON van_images;
CREATE TRIGGER update_van_images_updated_at 
    BEFORE UPDATE ON van_images 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_drivers_updated_at ON drivers;
CREATE TRIGGER update_drivers_updated_at 
    BEFORE UPDATE ON drivers 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Step 8: Insert sample drivers
INSERT INTO drivers (name, employee_id, phone, email, status) VALUES
('John Smith', 'EMP001', '+1-555-0101', 'john.smith@company.com', 'active'),
('Sarah Johnson', 'EMP002', '+1-555-0102', 'sarah.johnson@company.com', 'active'),
('Mike Davis', 'EMP003', '+1-555-0103', 'mike.davis@company.com', 'active'),
('Alex Wilson', 'EMP004', '+1-555-0104', 'alex.wilson@company.com', 'active'),
('Emma Brown', 'EMP005', '+1-555-0105', 'emma.brown@company.com', 'active')
ON CONFLICT (employee_id) DO NOTHING;

-- Step 9: Insert sample van images (only if vans exist)
INSERT INTO van_images (van_id, image_url, uploaded_by, driver_id, description, damage_type, damage_level, location, uploaded_at) 
SELECT 
    v.id as van_id,
    'https://images.unsplash.com/photo-1570993492881-25240ce854f4?w=800' as image_url,
    'John Smith' as uploaded_by,
    d.id as driver_id,
    'Minor scratch on left side door' as description,
    'Scratch' as damage_type,
    2 as damage_level,
    'left' as location,
    NOW() - INTERVAL '1 day' as uploaded_at
FROM vans v 
CROSS JOIN drivers d
WHERE d.name = 'John Smith'
LIMIT 1;

INSERT INTO van_images (van_id, image_url, uploaded_by, driver_id, description, damage_type, damage_level, location, uploaded_at) 
SELECT 
    v.id as van_id,
    'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800' as image_url,
    'Sarah Johnson' as uploaded_by,
    d.id as driver_id,
    'Front bumper damage from parking incident' as description,
    'Dent' as damage_type,
    3 as damage_level,
    'front' as location,
    NOW() - INTERVAL '2 days' as uploaded_at
FROM vans v 
CROSS JOIN drivers d
WHERE d.name = 'Sarah Johnson'
LIMIT 1;

INSERT INTO van_images (van_id, image_url, uploaded_by, driver_id, description, damage_type, damage_level, location, uploaded_at) 
SELECT 
    v.id as van_id,
    'https://images.unsplash.com/photo-1586244439413-bc2288941dda?w=800' as image_url,
    'Mike Davis' as uploaded_by,
    d.id as driver_id,
    'Interior wear and tear inspection' as description,
    'Wear' as damage_type,
    1 as damage_level,
    'interior' as location,
    NOW() - INTERVAL '3 days' as uploaded_at
FROM vans v 
CROSS JOIN drivers d
WHERE d.name = 'Mike Davis'
OFFSET 1 LIMIT 1;

INSERT INTO van_images (van_id, image_url, uploaded_by, driver_id, description, damage_type, damage_level, location, uploaded_at) 
SELECT 
    v.id as van_id,
    'https://images.unsplash.com/photo-1560473354-208d3fdcf7ae?w=800' as image_url,
    'John Smith' as uploaded_by,
    d.id as driver_id,
    'Close-up of left side damage' as description,
    'Scratch' as damage_type,
    2 as damage_level,
    'left' as location,
    NOW() - INTERVAL '1 day 2 hours' as uploaded_at
FROM vans v 
CROSS JOIN drivers d
WHERE d.name = 'John Smith'
OFFSET 2 LIMIT 1;

INSERT INTO van_images (van_id, image_url, uploaded_by, driver_id, description, damage_type, damage_level, location, uploaded_at) 
SELECT 
    v.id as van_id,
    'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=800' as image_url,
    'Alex Wilson' as uploaded_by,
    d.id as driver_id,
    'Weekly inspection photo - no issues' as description,
    NULL as damage_type,
    0 as damage_level,
    'exterior' as location,
    NOW() - INTERVAL '5 days' as uploaded_at
FROM vans v 
CROSS JOIN drivers d
WHERE d.name = 'Alex Wilson'
OFFSET 3 LIMIT 1;

INSERT INTO van_images (van_id, image_url, uploaded_by, driver_id, description, damage_type, damage_level, location, uploaded_at) 
SELECT 
    v.id as van_id,
    'https://images.unsplash.com/photo-1517524008697-84bbe3c3fd98?w=800' as image_url,
    'Sarah Johnson' as uploaded_by,
    d.id as driver_id,
    'Follow-up damage assessment' as description,
    'Dent' as damage_type,
    3 as damage_level,
    'front' as location,
    NOW() - INTERVAL '4 hours' as uploaded_at
FROM vans v 
CROSS JOIN drivers d
WHERE d.name = 'Sarah Johnson'
OFFSET 4 LIMIT 1;

-- Step 10: Update vans with current drivers (optional - links some vans to drivers)
UPDATE vans 
SET current_driver_id = d.id 
FROM drivers d 
WHERE vans.driver = d.name AND vans.current_driver_id IS NULL;

-- Step 11: Enable Row Level Security
ALTER TABLE van_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;

-- Step 12: Create RLS policies for van_images
DROP POLICY IF EXISTS "van_images_read_policy" ON van_images;
CREATE POLICY "van_images_read_policy" ON van_images
    FOR SELECT 
    TO authenticated 
    USING (true);

DROP POLICY IF EXISTS "van_images_insert_policy" ON van_images;
CREATE POLICY "van_images_insert_policy" ON van_images
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

DROP POLICY IF EXISTS "van_images_update_policy" ON van_images;
CREATE POLICY "van_images_update_policy" ON van_images
    FOR UPDATE 
    TO authenticated 
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "van_images_delete_policy" ON van_images;
CREATE POLICY "van_images_delete_policy" ON van_images
    FOR DELETE 
    TO authenticated 
    USING (true);

-- Step 13: Create RLS policies for drivers
DROP POLICY IF EXISTS "drivers_read_policy" ON drivers;
CREATE POLICY "drivers_read_policy" ON drivers
    FOR SELECT 
    TO authenticated 
    USING (true);

DROP POLICY IF EXISTS "drivers_insert_policy" ON drivers;
CREATE POLICY "drivers_insert_policy" ON drivers
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

DROP POLICY IF EXISTS "drivers_update_policy" ON drivers;
CREATE POLICY "drivers_update_policy" ON drivers
    FOR UPDATE 
    TO authenticated 
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "drivers_delete_policy" ON drivers;
CREATE POLICY "drivers_delete_policy" ON drivers
    FOR DELETE 
    TO authenticated 
    USING (true);

-- Step 14: Create the view for easy querying with driver information
DROP VIEW IF EXISTS van_images_with_driver;
CREATE VIEW van_images_with_driver AS
SELECT 
    vi.*,
    d.name as driver_name,
    d.employee_id as driver_employee_id,
    d.phone as driver_phone,
    d.email as driver_email
FROM van_images vi
LEFT JOIN drivers d ON vi.driver_id = d.id;

-- Step 15: Grant access to the view
GRANT SELECT ON van_images_with_driver TO authenticated;
GRANT SELECT ON van_images_with_driver TO anon;

-- Step 16: Verification queries
SELECT 'Setup completed successfully!' as status;
SELECT 'Drivers count:' as info, COUNT(*) as count FROM drivers;
SELECT 'Van images count:' as info, COUNT(*) as count FROM van_images;
SELECT 'View records:' as info, COUNT(*) as count FROM van_images_with_driver; 
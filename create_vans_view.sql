-- COMPATIBILITY FIX: Create 'vans' view pointing to 'van_profiles'
-- This allows old code to work with new schema
-- Run this in Supabase Dashboard -> SQL Editor

-- Create a view that maps van_profiles to vans for backward compatibility
CREATE OR REPLACE VIEW vans AS
SELECT 
    id,
    van_number,
    make,
    model,
    year,
    status,
    current_driver_id,
    created_at,
    updated_at
FROM van_profiles;

-- Note: Views inherit RLS from the underlying table (van_profiles)
-- So we don't need to enable RLS on the view itself

-- Verify the view works
SELECT 'SUCCESS: vans view created successfully' as status;
SELECT 'Current vans in view:' as info, COUNT(*) as count FROM vans; 
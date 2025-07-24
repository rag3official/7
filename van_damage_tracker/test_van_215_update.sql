-- Test van #215 status update manually
-- Run this in Supabase Dashboard -> SQL Editor to debug the issue

-- 1. Check if van #215 exists and what its current status is
SELECT 
    id,
    van_number, 
    status, 
    updated_at,
    created_at,
    make,
    model
FROM van_profiles 
WHERE van_number = 215;

-- 2. Check the table structure to see what fields exist
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'van_profiles' 
ORDER BY ordinal_position;

-- 3. Check if there are any constraints that might prevent updates
SELECT 
    constraint_name,
    constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'van_profiles';

-- 4. Try a manual status update
UPDATE van_profiles 
SET 
    status = 'maintenance',
    updated_at = NOW()
WHERE van_number = 215;

-- 5. Check if the update worked
SELECT 
    van_number, 
    status, 
    updated_at
FROM van_profiles 
WHERE van_number = 215;

-- 6. Try to revert it back
UPDATE van_profiles 
SET 
    status = 'active',
    updated_at = NOW()
WHERE van_number = 215;

-- 7. Final check
SELECT 
    van_number, 
    status, 
    updated_at
FROM van_profiles 
WHERE van_number = 215; 
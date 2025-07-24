-- Debug script for van status update issue
-- Run this in Supabase Dashboard -> SQL Editor

-- 1. Check current van #215 data
SELECT 'CURRENT VAN #215 DATA:' as info;
SELECT 
    id,
    van_number, 
    status, 
    updated_at,
    created_at
FROM van_profiles 
WHERE van_number = 215;

-- 2. Check if status column exists and its constraints
SELECT 'STATUS COLUMN INFO:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'van_profiles' 
AND column_name = 'status';

-- 3. Check status constraints
SELECT 'STATUS CONSTRAINTS:' as info;
SELECT 
    constraint_name,
    check_clause
FROM information_schema.check_constraints 
WHERE constraint_name LIKE '%status%';

-- 4. Try manual update with detailed response
SELECT 'ATTEMPTING MANUAL UPDATE:' as info;
UPDATE van_profiles 
SET 
    status = 'maintenance',
    updated_at = NOW()
WHERE van_number = 215
RETURNING van_number, status, updated_at;

-- 5. Verify the change
SELECT 'VERIFICATION AFTER UPDATE:' as info;
SELECT 
    van_number, 
    status, 
    updated_at
FROM van_profiles 
WHERE van_number = 215;

-- 6. Check RLS policies on van_profiles
SELECT 'RLS POLICIES ON VAN_PROFILES:' as info;
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'van_profiles';

-- 7. Check if RLS is enabled
SELECT 'RLS STATUS:' as info;
SELECT 
    schemaname, 
    tablename, 
    rowsecurity
FROM pg_tables 
WHERE tablename = 'van_profiles';

-- 8. Try reverting back to active
SELECT 'REVERTING TO ACTIVE:' as info;
UPDATE van_profiles 
SET 
    status = 'active',
    updated_at = NOW()
WHERE van_number = 215
RETURNING van_number, status, updated_at; 
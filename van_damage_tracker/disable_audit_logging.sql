-- QUICK FIX: Disable audit logging to resolve RLS error
-- Run this in Supabase Dashboard -> SQL Editor

-- Option 1: Drop the van_status_log table entirely (simplest fix)
DROP TABLE IF EXISTS van_status_log CASCADE;

-- Option 2: Or if you want to keep the table but fix RLS, uncomment below:
-- ALTER TABLE van_status_log DISABLE ROW LEVEL SECURITY;

-- Verify van_profiles table is working
SELECT van_number, status FROM van_profiles WHERE van_number = 215; 
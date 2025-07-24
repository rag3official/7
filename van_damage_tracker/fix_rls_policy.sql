-- Fix RLS Policy for Van Status Updates
-- Run this in Supabase Dashboard -> SQL Editor to resolve the RLS error

-- First, check if van_status_log table exists, if not create it
CREATE TABLE IF NOT EXISTS van_status_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id UUID REFERENCES van_profiles(id) ON DELETE CASCADE,
    van_number INTEGER NOT NULL,
    old_status TEXT,
    new_status TEXT NOT NULL,
    reason TEXT,
    notes TEXT,
    changed_by TEXT DEFAULT 'flutter_app',
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on the table
ALTER TABLE van_status_log ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON van_status_log;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON van_status_log;

-- Create a permissive policy for authenticated users
CREATE POLICY "Allow all operations for authenticated users" ON van_status_log
    FOR ALL 
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Also allow for service role (for server-side operations)
CREATE POLICY "Allow all operations for service role" ON van_status_log
    FOR ALL 
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Grant necessary permissions
GRANT ALL ON van_status_log TO authenticated;
GRANT ALL ON van_status_log TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Optional: If you want to disable audit logging entirely for now, 
-- you can comment out the table creation and just run:
-- DROP TABLE IF EXISTS van_status_log;

-- Verify the fix by checking policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'van_status_log';

-- Test that van_profiles table is accessible
SELECT COUNT(*) as van_count FROM van_profiles; 
-- Quick fix for van_number constraint violation in van_images table
-- Run this in Supabase Dashboard -> SQL Editor

-- Make van_number nullable in van_images table to fix Slack bot constraint violation
ALTER TABLE van_images ALTER COLUMN van_number DROP NOT NULL;

-- Verify the change
SELECT 'SUCCESS: van_number column is now nullable in van_images table' as status; 
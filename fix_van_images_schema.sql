-- Fix van_images table schema - add missing damage_type column
-- Run this in Supabase Dashboard -> SQL Editor

-- Add the missing damage_type column to van_images table
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_type VARCHAR(50) DEFAULT 'unknown';

-- Also add any other potentially missing columns that might be expected
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_severity VARCHAR(20) DEFAULT 'minor';
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_location VARCHAR(100);

-- Update existing records to have a default damage_type
UPDATE van_images SET damage_type = 'general' WHERE damage_type IS NULL;

-- Verify the changes
SELECT 'SUCCESS: van_images table updated with damage_type column' as status;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'van_images' 
ORDER BY ordinal_position; 
-- Check the actual structure of the vans table
-- Run this in Supabase SQL Editor

-- 1. Check what columns exist in the vans table
SELECT 'VANS TABLE COLUMNS:' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'vans'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Show a sample row to see the data
SELECT 'SAMPLE VAN DATA:' as info;
SELECT * FROM vans LIMIT 1;

-- 3. Check van_images table structure too
SELECT 'VAN_IMAGES TABLE COLUMNS:' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'van_images'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. Show sample van_images data
SELECT 'SAMPLE VAN_IMAGES DATA:' as info;
SELECT * FROM van_images LIMIT 1; 
-- Check the structure of the van_images_with_driver view
-- Run this in Supabase SQL Editor

-- 1. Check if the view exists
SELECT 'VIEW EXISTS:' as info;
SELECT viewname 
FROM pg_views 
WHERE viewname = 'van_images_with_driver';

-- 2. Check the columns in the view
SELECT 'VIEW COLUMNS:' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'van_images_with_driver'
ORDER BY ordinal_position;

-- 3. Check actual data in the view (first 3 rows)
SELECT 'SAMPLE DATA:' as info;
SELECT * FROM van_images_with_driver LIMIT 3;

-- 4. Check if van_images table exists and its columns
SELECT 'VAN_IMAGES TABLE COLUMNS:' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'van_images'
ORDER BY ordinal_position; 
-- Database Structure and Data Diagnostic Script
-- Run this in Supabase SQL Editor to see actual table structures and data

-- 1. Check the actual structure of the vans table
SELECT 'VANS TABLE STRUCTURE:' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'vans' 
ORDER BY ordinal_position;

-- 2. Check the actual structure of van_images table
SELECT 'VAN_IMAGES TABLE STRUCTURE:' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'van_images' 
ORDER BY ordinal_position;

-- 3. Check the actual structure of drivers table
SELECT 'DRIVERS TABLE STRUCTURE:' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'drivers' 
ORDER BY ordinal_position;

-- 4. Check what vans actually exist (using only id and any text columns)
SELECT 'ACTUAL VANS DATA:' as info;
SELECT 
    id, 
    van_number,
    CASE 
        WHEN column_exists.has_driver THEN driver
        ELSE 'N/A'
    END as driver_info,
    CASE 
        WHEN column_exists.has_date THEN date::text
        ELSE 'N/A'
    END as date_info
FROM vans,
(SELECT 
    COUNT(column_name) FILTER (WHERE column_name = 'driver') > 0 as has_driver,
    COUNT(column_name) FILTER (WHERE column_name = 'date') > 0 as has_date
 FROM information_schema.columns 
 WHERE table_name = 'vans') as column_exists
ORDER BY van_number 
LIMIT 10;

-- 5. Check drivers data  
SELECT 'DRIVERS DATA:' as info;
SELECT 
    id, 
    name, 
    employee_id, 
    phone
FROM drivers 
ORDER BY name;

-- 6. Check van_images data and their linkage
SELECT 'VAN_IMAGES DATA:' as info;
SELECT 
    vi.id,
    vi.van_id,
    vi.uploaded_by,
    vi.driver_id,
    d.name as driver_name,
    vi.damage_level,
    vi.location,
    vi.uploaded_at
FROM van_images vi
LEFT JOIN drivers d ON vi.driver_id = d.id
ORDER BY vi.uploaded_at DESC;

-- 7. Show van-image count summary
SELECT 'VAN IMAGE COUNTS BY VAN:' as info;
SELECT 
    v.van_number,
    v.id as van_id,
    COUNT(vi.id) as image_count
FROM vans v
LEFT JOIN van_images vi ON v.id = vi.van_id
GROUP BY v.id, v.van_number
ORDER BY image_count DESC, v.van_number
LIMIT 20;

-- 8. Check if the view exists and works
SELECT 'CHECKING VIEW:' as info;
SELECT COUNT(*) as view_record_count 
FROM van_images_with_driver; 
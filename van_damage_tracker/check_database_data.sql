-- Database Data Diagnostic Script
-- Run this in Supabase SQL Editor to see what data exists

-- 1. Check what vans exist in the database
SELECT 'VANS IN DATABASE:' as info;
SELECT 
    id, 
    van_number, 
    make, 
    model, 
    driver,
    current_driver_id
FROM vans 
ORDER BY van_number 
LIMIT 10;

-- 2. Check what drivers exist
SELECT 'DRIVERS IN DATABASE:' as info;
SELECT 
    id, 
    name, 
    employee_id, 
    phone
FROM drivers 
ORDER BY name;

-- 3. Check what van images exist and their linkage
SELECT 'VAN IMAGES IN DATABASE:' as info;
SELECT 
    vi.id,
    vi.van_id,
    v.van_number,
    vi.uploaded_by,
    vi.driver_id,
    d.name as driver_name,
    vi.damage_level,
    vi.location,
    vi.uploaded_at
FROM van_images vi
LEFT JOIN vans v ON vi.van_id = v.id
LEFT JOIN drivers d ON vi.driver_id = d.id
ORDER BY vi.uploaded_at DESC;

-- 4. Check the view that the app uses
SELECT 'VAN_IMAGES_WITH_DRIVER VIEW:' as info;
SELECT *
FROM van_images_with_driver
ORDER BY uploaded_at DESC;

-- 5. Show van-image count summary
SELECT 'VAN IMAGE COUNTS:' as info;
SELECT 
    v.van_number,
    v.id as van_id,
    COUNT(vi.id) as image_count
FROM vans v
LEFT JOIN van_images vi ON v.id = vi.van_id
GROUP BY v.id, v.van_number
ORDER BY image_count DESC, v.van_number
LIMIT 20; 
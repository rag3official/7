-- Check what image data exists in the vans table
-- Run this in Supabase SQL Editor

-- 1. Check the actual columns in vans table
SELECT 'VANS TABLE COLUMNS:' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'vans' 
AND column_name LIKE '%url%' OR column_name LIKE '%image%' OR column_name LIKE '%photo%'
ORDER BY ordinal_position;

-- 2. Check sample van data focusing on image-related fields
SELECT 'SAMPLE VAN DATA WITH IMAGES:' as info;
SELECT 
    id,
    van_number,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vans' AND column_name = 'url') 
        THEN url 
        ELSE 'NO URL COLUMN' 
    END as van_url,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vans' AND column_name = 'image_urls') 
        THEN image_urls::text 
        ELSE 'NO IMAGE_URLS COLUMN' 
    END as image_urls_array,
    driver,
    status
FROM vans 
WHERE (url IS NOT NULL AND url != '') 
   OR (image_urls IS NOT NULL AND array_length(image_urls, 1) > 0)
ORDER BY van_number 
LIMIT 10;

-- 3. Check all vans to see which ones have image data
SELECT 'ALL VANS IMAGE SUMMARY:' as info;
SELECT 
    van_number,
    CASE 
        WHEN url IS NOT NULL AND url != '' THEN 'HAS URL'
        ELSE 'NO URL'
    END as url_status,
    CASE 
        WHEN image_urls IS NOT NULL AND array_length(image_urls, 1) > 0 
        THEN CONCAT('HAS ', array_length(image_urls, 1), ' IMAGES')
        ELSE 'NO IMAGES'
    END as images_status,
    status,
    driver
FROM vans
ORDER BY van_number
LIMIT 20;

-- 4. Show actual URLs for vans that have them
SELECT 'VANS WITH ACTUAL IMAGE URLS:' as info;
SELECT 
    van_number,
    url as main_image_url,
    driver,
    status
FROM vans 
WHERE url IS NOT NULL 
  AND url != '' 
  AND url != 'N/A'
ORDER BY van_number
LIMIT 20; 
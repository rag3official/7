-- Add sample images to Van 92 specifically
-- Run this in Supabase SQL Editor

-- Get Van 92's ID and add images to it
WITH van_92 AS (
    SELECT id FROM vans WHERE van_number = '92' LIMIT 1
),
sample_driver AS (
    SELECT id FROM drivers LIMIT 1
)
INSERT INTO van_images (
    van_id, 
    image_url, 
    uploaded_by, 
    driver_id, 
    uploaded_at,
    description, 
    damage_type, 
    damage_level, 
    location
)
SELECT 
    v92.id,
    'https://example.com/images/van_92_damage_' || generate_series || '.jpg',
    'system',
    sd.id,
    NOW() - INTERVAL '1 day' * generate_series,
    'Sample damage report ' || generate_series || ' for van 92',
    CASE generate_series % 3 
        WHEN 0 THEN 'scratch'
        WHEN 1 THEN 'dent'
        ELSE 'paint_damage'
    END,
    (generate_series % 5) + 1,
    CASE generate_series % 4
        WHEN 0 THEN 'front_bumper'
        WHEN 1 THEN 'side_panel'
        WHEN 2 THEN 'rear_door'
        ELSE 'wheel_well'
    END
FROM van_92 v92
CROSS JOIN sample_driver sd
CROSS JOIN generate_series(1, 3);

-- Verify the images were added
SELECT 'Van 92 now has images:' as info;
SELECT 
    vi.description,
    vi.damage_type,
    vi.damage_level,
    vi.location,
    vi.uploaded_at::date as upload_date
FROM van_images vi
JOIN vans v ON vi.van_id = v.id
WHERE v.van_number = '92'
ORDER BY vi.uploaded_at DESC; 
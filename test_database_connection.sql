-- Simple database connection test
-- This file uses proper SQL comments with --

SELECT 'Database connection test successful' as message;

-- Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('vans', 'drivers', 'van_images')
ORDER BY table_name;

-- Get driver display info with employee ID if available (SQL comment)
SELECT 
    d.name,
    d.employee_id,
    COUNT(vi.id) as image_count
FROM drivers d 
LEFT JOIN van_images vi ON d.id = vi.driver_id 
GROUP BY d.id, d.name, d.employee_id
ORDER BY d.name; 
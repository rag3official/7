-- Debug Van Profiles Table
-- Run this in your Supabase SQL Editor to check what data exists

-- 1. Check if van_profiles table exists and its structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'van_profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check how many van profiles exist
SELECT COUNT(*) as total_van_profiles FROM van_profiles;

-- 3. Show sample van profiles (first 5)
SELECT 
    id,
    van_number,
    make,
    model,
    year,
    status,
    current_driver_name,
    driver_name,
    notes,
    created_at,
    updated_at
FROM van_profiles 
ORDER BY created_at DESC 
LIMIT 5;

-- 4. Check if there are any van images
SELECT COUNT(*) as total_van_images FROM van_images;

-- 5. Show sample van images (first 5)
SELECT 
    id,
    van_number,
    van_damage,
    van_rating,
    created_at
FROM van_images 
ORDER BY created_at DESC 
LIMIT 5;

-- 6. Check for any van profiles with specific van numbers
SELECT 
    van_number,
    make,
    model,
    status
FROM van_profiles 
WHERE van_number IS NOT NULL 
ORDER BY van_number; 
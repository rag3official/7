-- DIAGNOSTIC: Check Current Database Schema
-- Run this in Supabase Dashboard -> SQL Editor to see what tables exist

-- 1. Check what tables exist
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
    AND table_name IN ('vans', 'van_profiles', 'driver_profiles', 'van_images', 'drivers')
ORDER BY table_name;

-- 2. Check if vans table exists and show its structure
SELECT 
    'vans_table_structure' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
    AND table_name = 'vans'
ORDER BY ordinal_position;

-- 3. Check if van_profiles table exists and show its structure
SELECT 
    'van_profiles_table_structure' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
    AND table_name = 'van_profiles'
ORDER BY ordinal_position;

-- 4. Check what data exists in each table (safe version)
DO $$
BEGIN
    -- Check vans table
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vans' AND table_schema = 'public') THEN
        RAISE NOTICE 'vans table exists with % rows', (SELECT COUNT(*) FROM vans);
    ELSE
        RAISE NOTICE 'vans table does not exist';
    END IF;
    
    -- Check van_profiles table
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'van_profiles' AND table_schema = 'public') THEN
        RAISE NOTICE 'van_profiles table exists with % rows', (SELECT COUNT(*) FROM van_profiles);
    ELSE
        RAISE NOTICE 'van_profiles table does not exist';
    END IF;
    
    -- Check driver_profiles table
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'driver_profiles' AND table_schema = 'public') THEN
        RAISE NOTICE 'driver_profiles table exists with % rows', (SELECT COUNT(*) FROM driver_profiles);
    ELSE
        RAISE NOTICE 'driver_profiles table does not exist';
    END IF;
    
    -- Check van_images table
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'van_images' AND table_schema = 'public') THEN
        RAISE NOTICE 'van_images table exists with % rows', (SELECT COUNT(*) FROM van_images);
    ELSE
        RAISE NOTICE 'van_images table does not exist';
    END IF;
END $$;

-- 5. Show sample data from vans table if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vans' AND table_schema = 'public') THEN
        RAISE NOTICE 'Sample data from vans table will be shown below';
    ELSE
        RAISE NOTICE 'Cannot show vans data - table does not exist';
    END IF;
END $$;

-- Show vans data only if table exists (separate query to avoid syntax errors)
SELECT 'VANS_TABLE' as source, van_number::text, make, model 
FROM vans 
LIMIT 3;

-- 6. Show sample data from van_profiles table if it exists  
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'van_profiles' AND table_schema = 'public') THEN
        RAISE NOTICE 'Sample data from van_profiles table will be shown below';
    ELSE
        RAISE NOTICE 'Cannot show van_profiles data - table does not exist';
    END IF;
END $$;

-- Show van_profiles data only if table exists (separate query)
SELECT 'VAN_PROFILES_TABLE' as source, van_number::text, make, model 
FROM van_profiles 
LIMIT 3; 
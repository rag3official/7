-- Simple check of vans table structure and data
-- Run this in Supabase SQL Editor

-- 1. Show ALL columns in vans table
SELECT 'ALL VANS TABLE COLUMNS:' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'vans' 
ORDER BY ordinal_position;

-- 2. Show sample data from vans table (first 5 vans)
SELECT 'SAMPLE VAN DATA:' as info;
SELECT * FROM vans ORDER BY van_number LIMIT 5; 
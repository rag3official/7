-- SQL script to check the current structure of your vans table
-- Run this in your Supabase SQL Editor to see what columns exist

-- Check table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'vans' 
ORDER BY ordinal_position;

-- Check existing data (first 5 rows)
SELECT * FROM vans LIMIT 5; 
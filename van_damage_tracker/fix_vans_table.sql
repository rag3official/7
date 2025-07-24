-- SQL script to add missing columns to your existing vans table
-- Run this AFTER checking your current table structure

-- Add missing columns (run only the ones that don't exist)
-- Check the output from check_vans_table.sql first, then uncomment and run the needed ALTER statements

-- ALTER TABLE vans ADD COLUMN IF NOT EXISTS plate_number VARCHAR(50);
-- ALTER TABLE vans ADD COLUMN IF NOT EXISTS model VARCHAR(100);
-- ALTER TABLE vans ADD COLUMN IF NOT EXISTS year VARCHAR(10);
-- ALTER TABLE vans ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'Active';
-- ALTER TABLE vans ADD COLUMN IF NOT EXISTS driver_name VARCHAR(100);
-- ALTER TABLE vans ADD COLUMN IF NOT EXISTS last_inspection TIMESTAMP WITH TIME ZONE;
-- ALTER TABLE vans ADD COLUMN IF NOT EXISTS mileage DECIMAL(10,2);

-- If you need to copy data from existing columns with different names:
-- UPDATE vans SET plate_number = "plateNumber" WHERE plate_number IS NULL;  -- adjust column names as needed
-- UPDATE vans SET driver_name = "driverName" WHERE driver_name IS NULL;    -- adjust column names as needed 
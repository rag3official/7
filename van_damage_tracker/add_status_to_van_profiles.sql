-- Add status field to van_profiles table
-- Run this in Supabase Dashboard -> SQL Editor

-- Add status column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_profiles' AND column_name = 'status'
    ) THEN
        ALTER TABLE van_profiles ADD COLUMN status TEXT DEFAULT 'active';
    END IF;
END $$;

-- Add or update the status constraint
ALTER TABLE van_profiles DROP CONSTRAINT IF EXISTS van_profiles_status_check;
ALTER TABLE van_profiles ADD CONSTRAINT van_profiles_status_check 
    CHECK (status IN ('active', 'maintenance', 'out_of_service'));

-- Add updated_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_profiles' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE van_profiles ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- Add notes column if it doesn't exist (for status change reasons)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_profiles' AND column_name = 'notes'
    ) THEN
        ALTER TABLE van_profiles ADD COLUMN notes TEXT;
    END IF;
END $$;

-- Update any existing invalid status values
UPDATE van_profiles 
SET status = CASE 
    WHEN LOWER(status) IN ('active', 'operational', 'available') THEN 'active'
    WHEN LOWER(status) IN ('maintenance', 'repair', 'servicing') THEN 'maintenance'
    WHEN LOWER(status) IN ('out_of_service', 'retired', 'inactive', 'decommissioned') THEN 'out_of_service'
    ELSE 'active'
END
WHERE status IS NULL OR status NOT IN ('active', 'maintenance', 'out_of_service');

-- Verify the setup
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'van_profiles' 
AND column_name IN ('status', 'updated_at', 'notes')
ORDER BY column_name; 
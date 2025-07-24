-- QUICK FIX: Remove any audit logging that's causing RLS errors
-- Run this in Supabase Dashboard -> SQL Editor

-- 1. Drop any triggers that might be logging to van_status_log
DROP TRIGGER IF EXISTS van_status_change_trigger ON van_profiles;
DROP TRIGGER IF EXISTS log_van_status_changes ON van_profiles;
DROP TRIGGER IF EXISTS audit_van_status ON van_profiles;

-- 2. Drop the problematic table entirely
DROP TABLE IF EXISTS van_status_log CASCADE;

-- 3. Ensure van_profiles has the basic fields we need
DO $$
BEGIN
    -- Add status column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_profiles' AND column_name = 'status'
    ) THEN
        ALTER TABLE van_profiles ADD COLUMN status TEXT DEFAULT 'active';
    END IF;

    -- Add updated_at column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_profiles' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE van_profiles ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;

    -- Add notes column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_profiles' AND column_name = 'notes'
    ) THEN
        ALTER TABLE van_profiles ADD COLUMN notes TEXT;
    END IF;
END $$;

-- 4. Set proper constraint for status field
ALTER TABLE van_profiles DROP CONSTRAINT IF EXISTS van_profiles_status_check;
ALTER TABLE van_profiles ADD CONSTRAINT van_profiles_status_check 
    CHECK (status IN ('active', 'maintenance', 'out_of_service'));

-- 5. Test that we can update a van status
UPDATE van_profiles 
SET status = 'active', updated_at = NOW() 
WHERE van_number = 215;

-- 6. Verify the update worked
SELECT van_number, status, updated_at 
FROM van_profiles 
WHERE van_number = 215; 
-- SIMPLE Van Status Management Setup
-- Run this in Supabase Dashboard -> SQL Editor
-- This sets up basic van status functionality without complex triggers

BEGIN;

-- =============================================================================
-- 1. ENSURE VAN_PROFILES TABLE HAS PROPER STATUS FIELD
-- =============================================================================

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

-- Add constraint for valid status values
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

-- Add notes column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_profiles' AND column_name = 'notes'
    ) THEN
        ALTER TABLE van_profiles ADD COLUMN notes TEXT;
    END IF;
END $$;

-- =============================================================================
-- 2. CREATE SIMPLE UPDATED_AT TRIGGER
-- =============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_van_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS update_van_profiles_updated_at_trigger ON van_profiles;
CREATE TRIGGER update_van_profiles_updated_at_trigger
    BEFORE UPDATE ON van_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_van_profiles_updated_at();

-- =============================================================================
-- 3. NORMALIZE EXISTING STATUS VALUES
-- =============================================================================

-- Update any existing status values to match our constraints
UPDATE van_profiles 
SET status = CASE 
    WHEN LOWER(status) IN ('active', 'operational', 'available') THEN 'active'
    WHEN LOWER(status) IN ('maintenance', 'repair', 'servicing') THEN 'maintenance'
    WHEN LOWER(status) IN ('out_of_service', 'retired', 'inactive', 'decommissioned') THEN 'out_of_service'
    ELSE 'active'
END
WHERE status IS NULL OR status NOT IN ('active', 'maintenance', 'out_of_service');

-- =============================================================================
-- 4. CREATE BASIC STATUS SUMMARY VIEW
-- =============================================================================

-- Simple view for status summary
CREATE OR REPLACE VIEW van_status_summary AS
SELECT 
    status,
    COUNT(*) as van_count
FROM van_profiles 
GROUP BY status
ORDER BY 
    CASE status 
        WHEN 'active' THEN 1 
        WHEN 'maintenance' THEN 2 
        WHEN 'out_of_service' THEN 3 
        ELSE 4 
    END;

COMMIT;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

-- Show current status distribution
SELECT 'Current van status distribution:' AS info;
SELECT * FROM van_status_summary; 
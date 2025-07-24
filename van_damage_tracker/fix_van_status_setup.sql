-- CORRECTED Van Status Management Setup
-- Run this in Supabase Dashboard -> SQL Editor
-- This fixes the syntax error and ensures proper execution order

BEGIN;

-- =============================================================================
-- 1. ENSURE VAN_PROFILES TABLE HAS PROPER STATUS FIELD
-- =============================================================================

-- Update van_profiles table structure
DO $$
BEGIN
    -- Ensure status column exists with proper constraints
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_profiles' AND column_name = 'status'
    ) THEN
        ALTER TABLE van_profiles ADD COLUMN status TEXT DEFAULT 'active';
    END IF;

    -- Update status constraint to match Flutter app expectations
    ALTER TABLE van_profiles DROP CONSTRAINT IF EXISTS van_profiles_status_check;
    ALTER TABLE van_profiles ADD CONSTRAINT van_profiles_status_check 
        CHECK (status IN ('active', 'maintenance', 'out_of_service'));

    -- Ensure updated_at column exists for tracking status changes
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_profiles' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE van_profiles ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;

    -- Ensure notes column exists for status change reasons
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_profiles' AND column_name = 'notes'
    ) THEN
        ALTER TABLE van_profiles ADD COLUMN notes TEXT;
    END IF;
END $$;

-- =============================================================================
-- 2. CREATE STATUS CHANGE AUDIT LOG TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS van_status_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id UUID REFERENCES van_profiles(id) ON DELETE CASCADE,
    van_number INTEGER NOT NULL,
    old_status TEXT,
    new_status TEXT NOT NULL CHECK (new_status IN ('active', 'maintenance', 'out_of_service')),
    reason TEXT,
    notes TEXT,
    changed_by TEXT DEFAULT 'flutter_app',
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_van_status_log_van_id ON van_status_log(van_id);
CREATE INDEX IF NOT EXISTS idx_van_status_log_van_number ON van_status_log(van_number);
CREATE INDEX IF NOT EXISTS idx_van_status_log_changed_at ON van_status_log(changed_at DESC);

-- =============================================================================
-- 3. CREATE FUNCTIONS FOR TRIGGERS
-- =============================================================================

-- Function to log status changes
CREATE OR REPLACE FUNCTION log_van_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Only log if status actually changed
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO van_status_log (
            van_id,
            van_number,
            old_status,
            new_status,
            reason,
            notes,
            changed_by
        ) VALUES (
            NEW.id,
            NEW.van_number,
            OLD.status,
            NEW.status,
            'Status change via app',
            NEW.notes,
            'flutter_app'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_van_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 4. CREATE TRIGGERS
-- =============================================================================

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS van_status_change_trigger ON van_profiles;
DROP TRIGGER IF EXISTS update_van_profiles_updated_at_trigger ON van_profiles;

-- Create status change logging trigger
CREATE TRIGGER van_status_change_trigger
    AFTER UPDATE ON van_profiles
    FOR EACH ROW
    EXECUTE FUNCTION log_van_status_change();

-- Create updated_at timestamp trigger
CREATE TRIGGER update_van_profiles_updated_at_trigger
    BEFORE UPDATE ON van_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_van_profiles_updated_at();

-- =============================================================================
-- 5. UPDATE EXISTING RECORDS TO ENSURE CONSISTENT STATUS
-- =============================================================================

-- Normalize existing status values to match our constraints
UPDATE van_profiles 
SET status = CASE 
    WHEN LOWER(status) IN ('active', 'operational', 'available') THEN 'active'
    WHEN LOWER(status) IN ('maintenance', 'repair', 'servicing') THEN 'maintenance'
    WHEN LOWER(status) IN ('out_of_service', 'retired', 'inactive', 'decommissioned') THEN 'out_of_service'
    ELSE 'active'
END
WHERE status IS NULL OR status NOT IN ('active', 'maintenance', 'out_of_service');

-- =============================================================================
-- 6. CREATE HELPFUL VIEWS FOR STATUS REPORTING
-- =============================================================================

-- View for current van status summary
CREATE OR REPLACE VIEW van_status_summary AS
SELECT 
    status,
    COUNT(*) as van_count,
    ARRAY_AGG(van_number ORDER BY van_number) as van_numbers
FROM van_profiles 
GROUP BY status
ORDER BY 
    CASE status 
        WHEN 'active' THEN 1 
        WHEN 'maintenance' THEN 2 
        WHEN 'out_of_service' THEN 3 
        ELSE 4 
    END;

-- View for recent status changes
CREATE OR REPLACE VIEW recent_status_changes AS
SELECT 
    vsl.van_number,
    vp.make,
    vp.model,
    vsl.old_status,
    vsl.new_status,
    vsl.reason,
    vsl.notes,
    vsl.changed_at
FROM van_status_log vsl
JOIN van_profiles vp ON vsl.van_id = vp.id
ORDER BY vsl.changed_at DESC
LIMIT 50;

-- =============================================================================
-- 7. ENABLE ROW LEVEL SECURITY AND SET PERMISSIONS
-- =============================================================================

-- Enable RLS for audit table
ALTER TABLE van_status_log ENABLE ROW LEVEL SECURITY;

-- Create policies for van_status_log
DROP POLICY IF EXISTS "Enable all for authenticated users" ON van_status_log;
CREATE POLICY "Enable all for authenticated users" ON van_status_log
    FOR ALL USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

-- Grant permissions to authenticated users
GRANT ALL ON van_status_log TO authenticated;
GRANT ALL ON van_status_summary TO authenticated;
GRANT ALL ON recent_status_changes TO authenticated;

-- Grant usage on sequences
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

COMMIT;

-- =============================================================================
-- SUCCESS MESSAGE
-- =============================================================================
DO $$
BEGIN
    RAISE NOTICE 'Van Status Management System setup completed successfully!';
    RAISE NOTICE 'Available status values: active, maintenance, out_of_service';
    RAISE NOTICE 'Audit logging enabled in van_status_log table';
    RAISE NOTICE 'Views created: van_status_summary, recent_status_changes';
END $$; 
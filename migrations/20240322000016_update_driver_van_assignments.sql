-- Drop existing constraint if it exists
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'driver_van_assignments_status_check'
    ) THEN
        ALTER TABLE driver_van_assignments
        DROP CONSTRAINT driver_van_assignments_status_check;
    END IF;
END $$;

-- Add start_time and status columns to driver_van_assignments
ALTER TABLE driver_van_assignments
  ADD COLUMN IF NOT EXISTS start_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

-- Add constraint to validate status values
ALTER TABLE driver_van_assignments
  ADD CONSTRAINT driver_van_assignments_status_check
  CHECK (status IN ('active', 'inactive', 'completed'));

-- Update existing assignments to have a valid status
UPDATE driver_van_assignments
SET status = 'active'
WHERE status IS NULL;

-- Add index for faster status lookups
CREATE INDEX IF NOT EXISTS idx_driver_van_assignments_status
ON driver_van_assignments(status);

COMMENT ON COLUMN driver_van_assignments.start_time IS 'When the driver started using the van';
COMMENT ON COLUMN driver_van_assignments.status IS 'Current status of the assignment: active, inactive, or completed'; 
-- Drop dependent views first
DROP VIEW IF EXISTS active_driver_assignments CASCADE;
DROP VIEW IF EXISTS driver_upload_summary CASCADE;

-- Drop existing indexes and triggers
DROP TRIGGER IF EXISTS update_driver_profiles_updated_at ON driver_profiles;
DROP INDEX IF EXISTS idx_driver_slack_user;

-- Alter driver_profiles table to match the model
ALTER TABLE driver_profiles
  DROP COLUMN IF EXISTS slack_user_id CASCADE,
  DROP COLUMN IF EXISTS slack_username CASCADE,
  DROP COLUMN IF EXISTS full_name CASCADE,
  ADD COLUMN IF NOT EXISTS name VARCHAR(100) NOT NULL,
  ADD COLUMN IF NOT EXISTS license_number VARCHAR(50) NOT NULL,
  ADD COLUMN IF NOT EXISTS license_expiry DATE NOT NULL,
  ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20) NOT NULL,
  ADD COLUMN IF NOT EXISTS email VARCHAR(255) NOT NULL,
  ADD COLUMN IF NOT EXISTS last_medical_check DATE,
  ADD COLUMN IF NOT EXISTS certifications TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS additional_info JSONB;

-- Update status check constraint
ALTER TABLE driver_profiles
  DROP CONSTRAINT IF EXISTS driver_profiles_status_check,
  ADD CONSTRAINT driver_profiles_status_check 
    CHECK (status IN ('active', 'inactive', 'on_leave'));

-- Recreate updated_at trigger
CREATE OR REPLACE TRIGGER update_driver_profiles_updated_at
  BEFORE UPDATE ON driver_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Create new indexes
CREATE INDEX IF NOT EXISTS idx_driver_name ON driver_profiles(name);
CREATE INDEX IF NOT EXISTS idx_driver_license ON driver_profiles(license_number);
CREATE INDEX IF NOT EXISTS idx_driver_email ON driver_profiles(email);

-- Recreate views with new structure
CREATE VIEW active_driver_assignments AS
SELECT 
    dp.name as driver_name,
    v.van_number,
    dva.assignment_date,
    dva.start_time,
    dva.status
FROM driver_van_assignments dva
JOIN driver_profiles dp ON dp.id = dva.driver_id
JOIN vans v ON v.id = dva.van_id
WHERE dva.status = 'active'
ORDER BY dva.assignment_date DESC;

CREATE VIEW driver_upload_summary AS
SELECT 
    dp.name as driver_name,
    v.van_number,
    COUNT(du.id) as total_uploads,
    MAX(du.upload_timestamp) as last_upload
FROM driver_profiles dp
JOIN driver_uploads du ON du.driver_id = dp.id
JOIN van_images vi ON vi.id = du.van_image_id
JOIN vans v ON v.id = vi.van_id
GROUP BY dp.name, v.van_number
ORDER BY MAX(du.upload_timestamp) DESC;

COMMENT ON TABLE driver_profiles IS 'Stores driver information including license and medical details';
COMMENT ON COLUMN driver_profiles.name IS 'Full name of the driver';
COMMENT ON COLUMN driver_profiles.license_number IS 'Driver license number';
COMMENT ON COLUMN driver_profiles.license_expiry IS 'Date when the driver license expires';
COMMENT ON COLUMN driver_profiles.phone_number IS 'Contact phone number';
COMMENT ON COLUMN driver_profiles.email IS 'Contact email address';
COMMENT ON COLUMN driver_profiles.status IS 'Current status: active, inactive, or on_leave';
COMMENT ON COLUMN driver_profiles.last_medical_check IS 'Date of the last medical check';
COMMENT ON COLUMN driver_profiles.certifications IS 'Array of certification names/codes';
COMMENT ON COLUMN driver_profiles.additional_info IS 'Additional driver information stored as JSON'; 
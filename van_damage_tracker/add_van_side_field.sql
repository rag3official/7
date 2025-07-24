-- Add van_side field to van_images table for Claude AI processing
-- This field will store which side of the van the image shows
-- Run this in Supabase Dashboard -> SQL Editor

-- Add van_side column to store which side of the van is shown in the image
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS van_side VARCHAR(20) DEFAULT 'unknown';

-- Add a check constraint to ensure valid van side values
ALTER TABLE van_images ADD CONSTRAINT van_side_check 
CHECK (van_side IN ('front', 'rear', 'driver_side', 'passenger_side', 'interior', 'roof', 'undercarriage', 'unknown'));

-- Create an index for faster filtering by van side
CREATE INDEX IF NOT EXISTS idx_van_images_van_side ON van_images(van_side);

-- Add a comment to document the field
COMMENT ON COLUMN van_images.van_side IS 'Which side/view of the van this image shows (front, rear, driver_side, passenger_side, interior, roof, undercarriage, unknown)';

-- Update existing records to have a default value
UPDATE van_images SET van_side = 'unknown' WHERE van_side IS NULL;

-- Verify the changes
SELECT 'SUCCESS: van_side column added to van_images table' as status;

-- Show the updated table structure
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'van_images' AND table_schema = 'public'
ORDER BY ordinal_position; 
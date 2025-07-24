-- Fix van_images table schema to match Flutter app expectations
-- Add missing columns that the Flutter app is looking for

-- Add damage_level column (Flutter expects this instead of van_rating)
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_level INTEGER DEFAULT 0;

-- Copy data from van_rating to damage_level for existing records
UPDATE van_images SET damage_level = van_rating WHERE damage_level IS NULL;

-- Add damage_type column if it doesn't exist (Flutter expects this instead of van_damage)
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS damage_type TEXT;

-- Copy data from van_damage to damage_type for existing records
UPDATE van_images SET damage_type = van_damage WHERE damage_type IS NULL;

-- Success message
SELECT 'SUCCESS: van_images schema updated with damage_level and damage_type columns!' as status; 
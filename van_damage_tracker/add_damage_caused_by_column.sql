-- Add damage_caused_by column to van_profiles table
-- Run this in Supabase Dashboard -> SQL Editor

-- 1. Add damage_caused_by column to track which driver initially caused the damage
ALTER TABLE van_profiles 
ADD COLUMN IF NOT EXISTS damage_caused_by TEXT;

-- 2. Add comment for documentation
COMMENT ON COLUMN van_profiles.damage_caused_by IS 'Driver who initially caused damage that triggered an alert (L2/L3 damage)';

-- 3. Create index for efficient filtering
CREATE INDEX IF NOT EXISTS idx_van_profiles_damage_caused_by ON van_profiles(damage_caused_by);

-- 4. Verify the column was added
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'van_profiles' 
AND column_name = 'damage_caused_by';

-- 5. Show sample data with new column
SELECT 
    van_number,
    status,
    alerts,
    damage_caused_by,
    updated_at
FROM van_profiles 
ORDER BY van_number 
LIMIT 5; 
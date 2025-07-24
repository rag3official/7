-- Add alerts column to van_profiles table
-- Run this in Supabase Dashboard -> SQL Editor

-- 1. Add alerts column
ALTER TABLE van_profiles 
ADD COLUMN IF NOT EXISTS alerts TEXT DEFAULT 'no' CHECK (alerts IN ('yes', 'no'));

-- 2. Add comment for documentation
COMMENT ON COLUMN van_profiles.alerts IS 'Alert flag for vans with level 2/3 damage rating detected by AI';

-- 3. Update existing records to have 'no' alerts by default
UPDATE van_profiles 
SET alerts = 'no' 
WHERE alerts IS NULL;

-- 4. Create index for efficient filtering
CREATE INDEX IF NOT EXISTS idx_van_profiles_alerts ON van_profiles(alerts);

-- 5. Verify the column was added
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'van_profiles' 
AND column_name = 'alerts';

-- 6. Show sample data with new column
SELECT 
    van_number,
    status,
    alerts,
    updated_at
FROM van_profiles 
ORDER BY van_number 
LIMIT 5; 
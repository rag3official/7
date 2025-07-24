-- Create a view that maps van_profiles to vans for backward compatibility
-- This allows the Flutter app to continue using 'vans' while the Slack bot uses 'van_profiles'

CREATE OR REPLACE VIEW vans AS
SELECT 
    id,
    van_number,
    make,
    model,
    year,
    status,
    current_driver_id,
    created_at,
    updated_at,
    -- Add default values for columns that don't exist in van_profiles but are expected by Flutter
    NULL as color,
    NULL as license_plate,
    NULL as vin,
    NULL as location,
    NULL as mileage,
    NULL as fuel_level,
    NULL as last_maintenance_date,
    NULL as next_maintenance_due,
    NULL as insurance_expiry,
    NULL as registration_expiry,
    NULL as notes
FROM van_profiles;

-- Grant necessary permissions
GRANT SELECT ON vans TO authenticated;
GRANT SELECT ON vans TO anon;

-- Note: Views automatically inherit RLS from the underlying tables
-- No need to enable RLS on the view itself

-- Drop existing views
DROP VIEW IF EXISTS active_driver_assignments CASCADE;
DROP VIEW IF EXISTS driver_upload_summary CASCADE;

-- Recreate views with RLS-aware joins
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
  AND auth.uid() = dva.driver_id  -- Only show assignments for the current user
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
WHERE auth.uid() = du.driver_id  -- Only show uploads for the current user
GROUP BY dp.name, v.van_number
ORDER BY MAX(du.upload_timestamp) DESC;

-- Add helpful comments
COMMENT ON VIEW active_driver_assignments IS 'Shows active van assignments for the current user';
COMMENT ON VIEW driver_upload_summary IS 'Summarizes van image uploads for the current user'; 
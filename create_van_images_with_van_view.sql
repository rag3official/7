-- Create van_images_with_van view for Driver Profiles
-- This view shows all images uploaded by a driver with van details

CREATE OR REPLACE VIEW van_images_with_van AS
SELECT 
    vi.*,
    v.van_number,
    v.type as model,
    v.year,
    v.status as van_status,
    v.driver,
    v.url as van_main_image_url
FROM van_images vi
JOIN vans v ON vi.van_id = v.id
ORDER BY vi.updated_at DESC;

-- Grant access to the view
GRANT SELECT ON van_images_with_van TO authenticated;
GRANT SELECT ON van_images_with_van TO anon;

-- Test the view with a sample query
SELECT 'VIEW CREATED SUCCESSFULLY' as result;
SELECT * FROM van_images_with_van LIMIT 3; 
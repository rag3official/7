-- Van Damage Tracker - Database Views
-- Run this fourth to create helpful views for data analysis

BEGIN;

-- =============================================================================
-- 1. VAN IMAGES WITH VAN DETAILS VIEW
-- =============================================================================

-- Drop view if exists to avoid conflicts
DROP VIEW IF EXISTS public.van_images_with_van;

-- Create van_images_with_van view (without SECURITY DEFINER)
CREATE VIEW public.van_images_with_van AS
SELECT 
    vi.id as image_id,
    vi.image_url,
    vi.uploaded_by,
    vi.uploaded_at,
    vi.description,
    vi.damage_type,
    vi.damage_level,
    vi.location,
    vi.created_at as image_created_at,
    vi.updated_at as image_updated_at,
    v.id as van_id,
    v.van_number,
    v.type as van_type,
    v.status as van_status,
    v.driver,
    v.last_maintenance_date,
    v.maintenance_notes,
    v.created_at as van_created_at,
    v.updated_at as van_updated_at
FROM van_images vi
INNER JOIN vans v ON vi.van_id = v.id;

-- =============================================================================
-- 2. VAN IMAGES WITH DRIVER DETAILS VIEW
-- =============================================================================

-- Drop view if exists to avoid conflicts
DROP VIEW IF EXISTS public.van_images_with_driver;

-- Create van_images_with_driver view (without SECURITY DEFINER)
CREATE VIEW public.van_images_with_driver AS
SELECT 
    vi.id as image_id,
    vi.image_url,
    vi.uploaded_by,
    vi.uploaded_at,
    vi.description,
    vi.damage_type,
    vi.damage_level,
    vi.location,
    v.id as van_id,
    v.van_number,
    v.type as van_type,
    v.status as van_status,
    v.driver as van_driver_name,
    dp.id as driver_profile_id,
    dp.name as driver_name,
    dp.email as driver_email,
    dp.phone as driver_phone,
    dp.license_number,
    dp.hire_date,
    dp.status as driver_status
FROM van_images vi
INNER JOIN vans v ON vi.van_id = v.id
LEFT JOIN driver_profiles dp ON v.driver = dp.name;

-- =============================================================================
-- 3. ACTIVE DRIVER ASSIGNMENTS VIEW
-- =============================================================================

-- Drop view if exists to avoid conflicts
DROP VIEW IF EXISTS public.active_driver_assignments;

-- Create active_driver_assignments view (without SECURITY DEFINER)
CREATE VIEW public.active_driver_assignments AS
SELECT 
    dva.id as assignment_id,
    dva.assignment_date,
    dva.start_time,
    dva.end_time,
    dva.status as assignment_status,
    dva.notes as assignment_notes,
    dp.id as driver_id,
    dp.name as driver_name,
    dp.email as driver_email,
    dp.phone as driver_phone,
    dp.license_number,
    dp.status as driver_status,
    v.id as van_id,
    v.van_number,
    v.type as van_type,
    v.status as van_status,
    v.last_maintenance_date,
    v.maintenance_notes
FROM driver_van_assignments dva
INNER JOIN driver_profiles dp ON dva.driver_id = dp.id
INNER JOIN vans v ON dva.van_id = v.id
WHERE dva.status = 'active' 
AND dp.status = 'active'
AND v.status = 'Active';

-- =============================================================================
-- 4. VAN DAMAGE SUMMARY VIEW
-- =============================================================================

-- Create van damage summary view
CREATE OR REPLACE VIEW public.van_damage_summary AS
SELECT 
    v.id as van_id,
    v.van_number,
    v.type as van_type,
    v.status as van_status,
    v.driver,
    COUNT(vi.id) as total_images,
    COUNT(CASE WHEN vi.damage_level > 0 THEN 1 END) as damage_reports,
    AVG(vi.damage_level) as avg_damage_level,
    MAX(vi.uploaded_at) as last_image_upload,
    MIN(vi.uploaded_at) as first_image_upload,
    STRING_AGG(DISTINCT vi.damage_type, ', ') as damage_types,
    v.last_maintenance_date,
    v.created_at as van_created_at
FROM vans v
LEFT JOIN van_images vi ON v.id = vi.van_id
GROUP BY v.id, v.van_number, v.type, v.status, v.driver, v.last_maintenance_date, v.created_at;

-- =============================================================================
-- 5. RECENT ACTIVITY VIEW
-- =============================================================================

-- Create recent activity view
CREATE OR REPLACE VIEW public.recent_activity AS
SELECT 
    'image_upload' as activity_type,
    vi.uploaded_at as activity_time,
    vi.uploaded_by as actor,
    v.van_number,
    format('Image uploaded for van %s by %s', v.van_number, vi.uploaded_by) as description,
    vi.damage_level,
    vi.damage_type,
    vi.id as related_id
FROM van_images vi
INNER JOIN vans v ON vi.van_id = v.id

UNION ALL

SELECT 
    'van_created' as activity_type,
    v.created_at as activity_time,
    'system' as actor,
    v.van_number,
    format('Van %s added to system', v.van_number) as description,
    NULL as damage_level,
    NULL as damage_type,
    v.id as related_id
FROM vans v

UNION ALL

SELECT 
    'maintenance_update' as activity_type,
    v.updated_at as activity_time,
    'system' as actor,
    v.van_number,
    format('Maintenance updated for van %s', v.van_number) as description,
    NULL as damage_level,
    NULL as damage_type,
    v.id as related_id
FROM vans v
WHERE v.last_maintenance_date IS NOT NULL
AND v.updated_at > v.created_at

ORDER BY activity_time DESC;

-- =============================================================================
-- 6. DRIVER PERFORMANCE VIEW
-- =============================================================================

-- Create driver performance view
CREATE OR REPLACE VIEW public.driver_performance AS
SELECT 
    dp.id as driver_id,
    dp.name as driver_name,
    dp.email,
    dp.status as driver_status,
    dp.hire_date,
    COUNT(DISTINCT dva.van_id) as vans_assigned,
    COUNT(vi.id) as total_images_from_vans,
    COUNT(CASE WHEN vi.damage_level > 0 THEN 1 END) as damage_incidents,
    AVG(vi.damage_level) as avg_damage_severity,
    MAX(vi.uploaded_at) as last_incident_report,
    COUNT(CASE WHEN vi.uploaded_at >= NOW() - INTERVAL '30 days' THEN 1 END) as incidents_last_30_days
FROM driver_profiles dp
LEFT JOIN driver_van_assignments dva ON dp.id = dva.driver_id
LEFT JOIN van_images vi ON dva.van_id = vi.van_id 
    AND vi.uploaded_at BETWEEN dva.start_time AND COALESCE(dva.end_time, NOW())
GROUP BY dp.id, dp.name, dp.email, dp.status, dp.hire_date;

-- =============================================================================
-- 7. GRANT PERMISSIONS ON VIEWS
-- =============================================================================

-- Grant select permissions on all views
GRANT SELECT ON public.van_images_with_van TO authenticated, anon, service_role;
GRANT SELECT ON public.van_images_with_driver TO authenticated, anon, service_role;
GRANT SELECT ON public.active_driver_assignments TO authenticated, anon, service_role;
GRANT SELECT ON public.van_damage_summary TO authenticated, anon, service_role;
GRANT SELECT ON public.recent_activity TO authenticated, anon, service_role;
GRANT SELECT ON public.driver_performance TO authenticated, anon, service_role;

COMMIT;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Test all views are working
SELECT 'van_images_with_van' as view_name, COUNT(*) as row_count FROM public.van_images_with_van
UNION ALL
SELECT 'van_images_with_driver', COUNT(*) FROM public.van_images_with_driver
UNION ALL
SELECT 'active_driver_assignments', COUNT(*) FROM public.active_driver_assignments
UNION ALL
SELECT 'van_damage_summary', COUNT(*) FROM public.van_damage_summary
UNION ALL
SELECT 'recent_activity', COUNT(*) FROM public.recent_activity
UNION ALL
SELECT 'driver_performance', COUNT(*) FROM public.driver_performance
ORDER BY view_name;

-- Sample queries to test views
SELECT * FROM public.van_damage_summary LIMIT 5;
SELECT * FROM public.recent_activity LIMIT 5;

-- List all created views
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'VIEW'
AND table_name IN (
    'van_images_with_van',
    'van_images_with_driver', 
    'active_driver_assignments',
    'van_damage_summary',
    'recent_activity',
    'driver_performance'
)
ORDER BY table_name; 
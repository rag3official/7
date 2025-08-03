-- Fixed Sample Van and Driver Data for Testing
-- This script uses the correct column names from the actual van_profiles table

BEGIN;

-- First, let's add some sample van profiles using correct column names
INSERT INTO public.van_profiles (
    van_number,
    make,
    model,
    year,
    vin,
    license_plate,
    status,
    mileage,
    last_maintenance_date,
    next_maintenance_date,
    insurance_policy_number,
    registration_expiry,
    purchase_date,
    purchase_price,
    created_at,
    updated_at
) VALUES
('VAN001', 'Ford', 'Transit', 2022, 'WF0XXTTGXMWA12345', 'ABC123', 'active', 45000, '2024-01-15', '2024-07-15', 'INS-2024-001', '2025-03-15', '2022-01-10', 35000, NOW(), NOW()),
('VAN002', 'Mercedes', 'Sprinter', 2023, 'WD3PE7CD7NP123456', 'DEF456', 'active', 23000, '2024-02-10', '2024-08-10', 'INS-2024-002', '2025-04-20', '2023-02-15', 42000, NOW(), NOW()),
('VAN003', 'Ford', 'E-Series', 2021, 'WF0XXTTGXMWA54321', 'GHI789', 'maintenance', 67000, '2024-03-01', '2024-09-01', 'INS-2024-003', '2025-01-30', '2021-03-20', 32000, NOW(), NOW()),
('VAN004', 'Chevrolet', 'Express', 2022, '1GCWGBFG8N1234567', 'JKL012', 'active', 38000, '2024-01-20', '2024-07-20', 'INS-2024-004', '2025-05-10', '2022-04-05', 34000, NOW(), NOW()),
('VAN005', 'Ram', 'ProMaster', 2023, '3C6TRVBG5NE123456', 'MNO345', 'out_of_service', 15000, '2024-02-25', '2024-08-25', 'INS-2024-005', '2025-06-15', '2023-05-12', 38000, NOW(), NOW()),
('VAN006', 'Ford', 'Transit', 2022, 'WF0XXTTGXMWA98765', 'PQR678', 'active', 41000, '2024-01-30', '2024-07-30', 'INS-2024-006', '2025-02-28', '2022-06-18', 36000, NOW(), NOW()),
('VAN007', 'Mercedes', 'Sprinter', 2023, 'WD3PE7CD7NP987654', 'STU901', 'active', 19000, '2024-03-05', '2024-09-05', 'INS-2024-007', '2025-07-22', '2023-07-03', 43000, NOW(), NOW()),
('VAN008', 'Ford', 'E-Series', 2021, 'WF0XXTTGXMWA13579', 'VWX234', 'maintenance', 72000, '2024-02-15', '2024-08-15', 'INS-2024-008', '2025-03-12', '2021-08-14', 31000, NOW(), NOW());

-- Add some sample driver profiles using correct column names
INSERT INTO public.driver_profiles (
    driver_name,
    license_number,
    license_expiry,
    phone,
    email,
    hire_date,
    is_active,
    emergency_contact_name,
    emergency_contact_phone,
    address,
    date_of_birth,
    rating,
    notes,
    created_at,
    updated_at
) VALUES
('John Smith', 'DL123456789', '2026-03-15', '+1-555-0101', 'john.smith@vanfleet.com', '2023-01-15', true, 'Jane Smith', '+1-555-0102', '123 Main St, City, State 12345', '1985-06-20', 4.8, 'Excellent driver, very reliable', NOW(), NOW()),
('Maria Rodriguez', 'DL987654321', '2025-11-22', '+1-555-0201', 'maria.rodriguez@vanfleet.com', '2023-02-01', true, 'Carlos Rodriguez', '+1-555-0202', '456 Oak Ave, City, State 12345', '1990-09-12', 4.9, 'Outstanding safety record', NOW(), NOW()),
('David Johnson', 'DL456789123', '2026-07-08', '+1-555-0301', 'david.johnson@vanfleet.com', '2023-03-10', true, 'Sarah Johnson', '+1-555-0302', '789 Pine Rd, City, State 12345', '1988-04-03', 4.7, 'Good with customer service', NOW(), NOW()),
('Lisa Chen', 'DL789123456', '2025-12-30', '+1-555-0401', 'lisa.chen@vanfleet.com', '2023-04-05', true, 'Michael Chen', '+1-555-0402', '321 Elm St, City, State 12345', '1992-11-25', 4.6, 'Great attention to detail', NOW(), NOW()),
('Robert Wilson', 'DL321654987', '2026-02-14', '+1-555-0501', 'robert.wilson@vanfleet.com', '2023-05-20', true, 'Emily Wilson', '+1-555-0502', '654 Maple Dr, City, State 12345', '1987-08-17', 4.5, 'Experienced with heavy vehicles', NOW(), NOW()),
('Amanda Taylor', 'DL654987321', '2025-10-18', '+1-555-0601', 'amanda.taylor@vanfleet.com', '2023-06-12', true, 'James Taylor', '+1-555-0602', '987 Cedar Ln, City, State 12345', '1991-01-30', 4.7, 'Punctual and professional', NOW(), NOW());

-- Add some sample van images with damage reports using correct column names
INSERT INTO public.van_images (
    van_number,
    image_url,
    damage_description,
    damage_severity,
    damage_type,
    location_on_van,
    repair_status,
    repair_cost,
    reported_by,
    report_date,
    created_at,
    updated_at
) VALUES
('VAN001', 'https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=VAN001+Minor+Scratch', 'Small scratch on rear bumper', 'minor', 'scratch', 'rear_bumper', 'pending', 150.00, 'John Smith', '2024-03-10', NOW(), NOW()),
('VAN002', 'https://via.placeholder.com/400x300/FFE66D/000000?text=VAN002+Door+Dent', 'Dent on passenger side door', 'moderate', 'dent', 'side_door', 'in_progress', 350.00, 'Maria Rodriguez', '2024-03-08', NOW(), NOW()),
('VAN003', 'https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=VAN003+Engine+Issue', 'Engine overheating issue', 'major', 'mechanical', 'engine', 'pending', 1200.00, 'Maintenance Team', '2024-03-05', NOW(), NOW()),
('VAN004', 'https://via.placeholder.com/400x300/4ECDC4/FFFFFF?text=VAN004+Clean', 'No damage reported', 'none', 'none', 'none', 'completed', 0.00, 'David Johnson', '2024-03-12', NOW(), NOW()),
('VAN006', 'https://via.placeholder.com/400x300/FFE66D/000000?text=VAN006+Windshield+Chip', 'Small chip in windshield', 'minor', 'glass_damage', 'windshield', 'pending', 200.00, 'Lisa Chen', '2024-03-09', NOW(), NOW());

-- Show what we created
SELECT 
    'Van Profiles' as data_type,
    COUNT(*) as count
FROM public.van_profiles
UNION ALL
SELECT 
    'Driver Profiles' as data_type,
    COUNT(*) as count
FROM public.driver_profiles
UNION ALL
SELECT 
    'Van Images' as data_type,
    COUNT(*) as count
FROM public.van_images;

-- Show sample data
SELECT 
    v.van_number,
    v.make,
    v.model,
    v.status,
    COUNT(vi.id) as damage_reports
FROM public.van_profiles v
LEFT JOIN public.van_images vi ON v.van_number = vi.van_number
GROUP BY v.van_number, v.make, v.model, v.status
ORDER BY v.van_number;

COMMIT; 
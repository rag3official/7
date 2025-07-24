-- SQL script to create the vans table in Supabase
-- Run this in your Supabase SQL Editor

CREATE TABLE IF NOT EXISTS vans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    plate_number VARCHAR(50) NOT NULL UNIQUE,
    model VARCHAR(100) NOT NULL,
    year VARCHAR(10) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Active',
    driver_name VARCHAR(100),
    last_inspection TIMESTAMP WITH TIME ZONE,
    mileage DECIMAL(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert some sample data
INSERT INTO vans (plate_number, model, year, status, driver_name, last_inspection, mileage) VALUES
('VAN-001', 'Ford Transit', '2022', 'Active', 'John Smith', '2024-01-15T10:00:00Z', 45000.00),
('VAN-002', 'Mercedes Sprinter', '2023', 'Maintenance', 'Sarah Jones', '2024-01-10T14:30:00Z', 32000.00),
('VAN-003', 'Chevrolet Express', '2021', 'Active', 'Mike Johnson', '2024-01-20T09:15:00Z', 78000.00),
('VAN-004', 'Ford Transit Connect', '2023', 'Active', 'Emma Davis', '2024-01-18T11:45:00Z', 28500.00),
('VAN-005', 'Ram ProMaster', '2022', 'Out of Service', NULL, '2024-01-05T16:20:00Z', 55750.00);

-- Enable Row Level Security (RLS)
ALTER TABLE vans ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all operations for authenticated users
CREATE POLICY "Enable all operations for authenticated users" ON vans
    FOR ALL USING (auth.role() = 'authenticated');

-- Create policy to allow read access for anonymous users (if needed)
CREATE POLICY "Enable read access for all users" ON vans
    FOR SELECT USING (true); 
-- Create drivers table for managing driver information
CREATE TABLE IF NOT EXISTS drivers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    employee_id TEXT UNIQUE,
    phone TEXT,
    email TEXT,
    license_number TEXT,
    license_expiry_date DATE,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create indexes for drivers table
CREATE INDEX IF NOT EXISTS idx_drivers_name ON drivers(name);
CREATE INDEX IF NOT EXISTS idx_drivers_employee_id ON drivers(employee_id);
CREATE INDEX IF NOT EXISTS idx_drivers_status ON drivers(status);

-- Create trigger to automatically update updated_at timestamp for drivers
CREATE TRIGGER update_drivers_updated_at 
    BEFORE UPDATE ON drivers 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Insert sample drivers
INSERT INTO drivers (name, employee_id, phone, email, status) VALUES
('John Smith', 'EMP001', '+1-555-0101', 'john.smith@company.com', 'active'),
('Sarah Johnson', 'EMP002', '+1-555-0102', 'sarah.johnson@company.com', 'active'),
('Mike Davis', 'EMP003', '+1-555-0103', 'mike.davis@company.com', 'active'),
('Alex Wilson', 'EMP004', '+1-555-0104', 'alex.wilson@company.com', 'active'),
('Emma Brown', 'EMP005', '+1-555-0105', 'emma.brown@company.com', 'active')
ON CONFLICT (employee_id) DO NOTHING;

-- Add driver_id column to van_images table to properly reference drivers
-- First, let's add the column
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES drivers(id);

-- Create index for the new driver_id column
CREATE INDEX IF NOT EXISTS idx_van_images_driver_id ON van_images(driver_id);

-- Update existing van_images records to link with drivers based on uploaded_by name
UPDATE van_images 
SET driver_id = d.id 
FROM drivers d 
WHERE van_images.uploaded_by = d.name AND van_images.driver_id IS NULL;

-- Update the vans table to include current_driver_id for better tracking
ALTER TABLE vans ADD COLUMN IF NOT EXISTS current_driver_id UUID REFERENCES drivers(id);

-- Create index for current_driver_id
CREATE INDEX IF NOT EXISTS idx_vans_current_driver_id ON vans(current_driver_id);

-- Update some vans with current drivers based on existing driver field
UPDATE vans 
SET current_driver_id = d.id 
FROM drivers d 
WHERE vans.driver = d.name AND vans.current_driver_id IS NULL; 
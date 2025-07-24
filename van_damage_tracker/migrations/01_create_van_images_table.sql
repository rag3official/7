-- Create van_images table for storing van photos with metadata
CREATE TABLE IF NOT EXISTS van_images (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id UUID NOT NULL REFERENCES vans(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    uploaded_by TEXT, -- Driver name or ID who uploaded the image
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    description TEXT,
    damage_type TEXT, -- e.g., 'Scratch', 'Dent', 'Wear', etc.
    damage_level INTEGER CHECK (damage_level >= 0 AND damage_level <= 5), -- 0-5 scale
    location TEXT, -- e.g., 'front', 'rear', 'left', 'right', 'interior'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_van_images_van_id ON van_images(van_id);
CREATE INDEX IF NOT EXISTS idx_van_images_uploaded_at ON van_images(uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_van_images_uploaded_by ON van_images(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_van_images_damage_level ON van_images(damage_level);

-- Create trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_van_images_updated_at 
    BEFORE UPDATE ON van_images 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Add some sample data for testing
INSERT INTO van_images (van_id, image_url, uploaded_by, description, damage_type, damage_level, location, uploaded_at) 
SELECT 
    v.id as van_id,
    'https://images.unsplash.com/photo-1570993492881-25240ce854f4?w=800' as image_url,
    'John Smith' as uploaded_by,
    'Minor scratch on left side door' as description,
    'Scratch' as damage_type,
    2 as damage_level,
    'left' as location,
    NOW() - INTERVAL '1 day' as uploaded_at
FROM vans v LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO van_images (van_id, image_url, uploaded_by, description, damage_type, damage_level, location, uploaded_at) 
SELECT 
    v.id as van_id,
    'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800' as image_url,
    'Sarah Johnson' as uploaded_by,
    'Front bumper damage from parking incident' as description,
    'Dent' as damage_type,
    3 as damage_level,
    'front' as location,
    NOW() - INTERVAL '2 days' as uploaded_at
FROM vans v LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO van_images (van_id, image_url, uploaded_by, description, damage_type, damage_level, location, uploaded_at) 
SELECT 
    v.id as van_id,
    'https://images.unsplash.com/photo-1586244439413-bc2288941dda?w=800' as image_url,
    'Mike Davis' as uploaded_by,
    'Interior wear and tear' as description,
    'Wear' as damage_type,
    1 as damage_level,
    'interior' as location,
    NOW() - INTERVAL '3 days' as uploaded_at
FROM vans v LIMIT 1
ON CONFLICT DO NOTHING;

-- Add more sample images for different vans and drivers
INSERT INTO van_images (van_id, image_url, uploaded_by, description, damage_type, damage_level, location, uploaded_at) 
SELECT 
    v.id as van_id,
    'https://images.unsplash.com/photo-1560473354-208d3fdcf7ae?w=800' as image_url,
    'John Smith' as uploaded_by,
    'Close-up of left side damage' as description,
    'Scratch' as damage_type,
    2 as damage_level,
    'left' as location,
    NOW() - INTERVAL '1 day 2 hours' as uploaded_at
FROM vans v OFFSET 1 LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO van_images (van_id, image_url, uploaded_by, description, damage_type, damage_level, location, uploaded_at) 
SELECT 
    v.id as van_id,
    'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=800' as image_url,
    'Sarah Johnson' as uploaded_by,
    'Rear door inspection - no damage found' as description,
    NULL as damage_type,
    0 as damage_level,
    'rear' as location,
    NOW() - INTERVAL '5 days' as uploaded_at
FROM vans v OFFSET 2 LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO van_images (van_id, image_url, uploaded_by, description, damage_type, damage_level, location, uploaded_at) 
SELECT 
    v.id as van_id,
    'https://images.unsplash.com/photo-1517524008697-84bbe3c3fd98?w=800' as image_url,
    'Alex Wilson' as uploaded_by,
    'Weekly inspection photo' as description,
    NULL as damage_type,
    0 as damage_level,
    'exterior' as location,
    NOW() - INTERVAL '7 days' as uploaded_at
FROM vans v OFFSET 3 LIMIT 1
ON CONFLICT DO NOTHING; 
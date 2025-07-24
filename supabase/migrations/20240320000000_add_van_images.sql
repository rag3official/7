-- Create van_images table
CREATE TABLE van_images (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  van_id UUID REFERENCES vans(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  is_damage_photo BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Add RLS policies for van_images
ALTER TABLE van_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for all users" ON van_images
  FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users only" ON van_images
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable update for authenticated users only" ON van_images
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Enable delete for authenticated users only" ON van_images
  FOR DELETE USING (auth.role() = 'authenticated');

-- Add damage-related fields to vans table
ALTER TABLE vans
  ADD COLUMN IF NOT EXISTS damage_description TEXT,
  ADD COLUMN IF NOT EXISTS damage_reported_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS damage_reported_by UUID REFERENCES auth.users(id);

-- Create indexes
CREATE INDEX idx_van_images_van_id ON van_images(van_id);
CREATE INDEX idx_van_images_is_damage_photo ON van_images(is_damage_photo);

-- Create function to update van's updated_at timestamp
CREATE OR REPLACE FUNCTION update_van_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc', NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update van's updated_at
CREATE TRIGGER update_van_updated_at_trigger
  BEFORE UPDATE ON vans
  FOR EACH ROW
  EXECUTE FUNCTION update_van_updated_at();

-- Create trigger to automatically update van_images's updated_at
CREATE TRIGGER update_van_images_updated_at_trigger
  BEFORE UPDATE ON van_images
  FOR EACH ROW
  EXECUTE FUNCTION update_van_updated_at(); 
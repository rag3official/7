-- Create van_images table
CREATE TABLE IF NOT EXISTS public.van_images (
    id SERIAL PRIMARY KEY,  -- This will auto-generate 7-digit IDs
    van_id UUID REFERENCES public.vans(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    image_hash TEXT NOT NULL,
    damage_level INTEGER CHECK (damage_level >= 0 AND damage_level <= 3),
    damage_description TEXT,
    damage_location TEXT,
    confidence TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_assessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX idx_van_images_van_id ON public.van_images(van_id);
CREATE INDEX idx_van_images_image_hash ON public.van_images(image_hash);

-- Add RLS policies
ALTER TABLE public.van_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for all users" ON public.van_images
    FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users" ON public.van_images
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable update for authenticated users" ON public.van_images
    FOR UPDATE USING (auth.role() = 'authenticated');

-- Function to format ID as 7 digits
CREATE OR REPLACE FUNCTION format_image_id() RETURNS trigger AS $$
BEGIN
    -- Convert the ID to a 7-digit string with leading zeros
    NEW.id = LPAD(NEW.id::text, 7, '0')::integer;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to ensure 7-digit IDs
CREATE TRIGGER ensure_7digit_id
    BEFORE INSERT ON public.van_images
    FOR EACH ROW
    EXECUTE FUNCTION format_image_id(); 
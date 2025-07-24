-- Create van_images table with consistent schema
CREATE TABLE IF NOT EXISTS public.van_images (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id UUID REFERENCES public.vans(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    image_hash TEXT NOT NULL,
    damage_level INTEGER CHECK (damage_level >= 0 AND damage_level <= 3),
    damage_description TEXT,
    damage_location TEXT,
    confidence TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_assessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    original_format TEXT,
    original_mode TEXT,
    original_size JSONB,
    original_size_bytes BIGINT,
    processed_size JSONB,
    processed_size_bytes BIGINT,
    compression_ratio FLOAT,
    processed_at TIMESTAMP WITH TIME ZONE,
    retention_days INTEGER DEFAULT 90,
    status TEXT DEFAULT 'active'
);

-- Create necessary indexes for performance
CREATE INDEX IF NOT EXISTS idx_van_images_van_id ON public.van_images(van_id);
CREATE INDEX IF NOT EXISTS idx_van_images_image_hash ON public.van_images(image_hash);
CREATE INDEX IF NOT EXISTS idx_van_images_processed_at ON public.van_images(processed_at);
CREATE INDEX IF NOT EXISTS idx_van_images_status ON public.van_images(status);
CREATE INDEX IF NOT EXISTS idx_van_images_last_assessed_at ON public.van_images(last_assessed_at);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
CREATE TRIGGER update_van_images_updated_at
    BEFORE UPDATE ON public.van_images
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create function to check image expiration
CREATE OR REPLACE FUNCTION check_image_expiration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.processed_at < NOW() - (NEW.retention_days || ' days')::INTERVAL THEN
        NEW.status = 'expired';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for image expiration
CREATE TRIGGER check_image_expiration_trigger
    BEFORE UPDATE ON public.van_images
    FOR EACH ROW
    EXECUTE FUNCTION check_image_expiration();

-- Enable Row Level Security (RLS)
ALTER TABLE public.van_images ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Enable read access for all users" ON public.van_images
    FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users" ON public.van_images
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable update for authenticated users" ON public.van_images
    FOR UPDATE USING (auth.role() = 'authenticated'); 

CREATE POLICY "Enable delete for authenticated users" ON public.van_images
    FOR DELETE USING (auth.role() = 'authenticated');

-- Create function to get latest image for a van
CREATE OR REPLACE FUNCTION get_latest_van_image(van_number TEXT)
RETURNS TABLE (
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vi.image_url,
        vi.created_at
    FROM public.van_images vi
    JOIN public.vans v ON v.id = vi.van_id
    WHERE v.van_number = van_number
    AND vi.status = 'active'
    ORDER BY vi.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Create function to get all active images for a van
CREATE OR REPLACE FUNCTION get_van_images(van_number TEXT)
RETURNS TABLE (
    image_url TEXT,
    damage_level INTEGER,
    damage_description TEXT,
    damage_location TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    last_assessed_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vi.image_url,
        vi.damage_level,
        vi.damage_description,
        vi.damage_location,
        vi.created_at,
        vi.last_assessed_at
    FROM public.van_images vi
    JOIN public.vans v ON v.id = vi.van_id
    WHERE v.van_number = van_number
    AND vi.status = 'active'
    ORDER BY vi.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to update damage assessment
CREATE OR REPLACE FUNCTION update_damage_assessment(
    p_image_id UUID,
    p_damage_level INTEGER,
    p_damage_description TEXT,
    p_damage_location TEXT,
    p_confidence TEXT
)
RETURNS void AS $$
BEGIN
    UPDATE public.van_images
    SET 
        damage_level = p_damage_level,
        damage_description = p_damage_description,
        damage_location = p_damage_location,
        confidence = p_confidence,
        last_assessed_at = NOW()
    WHERE id = p_image_id;
END;
$$ LANGUAGE plpgsql;

-- Comments for table and columns
COMMENT ON TABLE public.van_images IS 'Stores images and their metadata for vans';
COMMENT ON COLUMN public.van_images.id IS 'Unique identifier for the image';
COMMENT ON COLUMN public.van_images.van_id IS 'Reference to the van this image belongs to';
COMMENT ON COLUMN public.van_images.image_url IS 'URL where the image is stored';
COMMENT ON COLUMN public.van_images.image_hash IS 'Hash of the image for deduplication';
COMMENT ON COLUMN public.van_images.damage_level IS 'Damage severity (0-3)';
COMMENT ON COLUMN public.van_images.damage_description IS 'Description of any damage visible in the image';
COMMENT ON COLUMN public.van_images.damage_location IS 'Location of damage on the van';
COMMENT ON COLUMN public.van_images.confidence IS 'Confidence level of damage assessment';
COMMENT ON COLUMN public.van_images.created_at IS 'When the image was uploaded';
COMMENT ON COLUMN public.van_images.last_assessed_at IS 'When the image was last assessed for damage';
COMMENT ON COLUMN public.van_images.updated_at IS 'When the record was last updated';
COMMENT ON COLUMN public.van_images.original_format IS 'Original image format (e.g., JPEG, PNG)';
COMMENT ON COLUMN public.van_images.original_mode IS 'Original color mode';
COMMENT ON COLUMN public.van_images.original_size IS 'Original image dimensions';
COMMENT ON COLUMN public.van_images.original_size_bytes IS 'Original file size in bytes';
COMMENT ON COLUMN public.van_images.processed_size IS 'Processed image dimensions';
COMMENT ON COLUMN public.van_images.processed_size_bytes IS 'Processed file size in bytes';
COMMENT ON COLUMN public.van_images.compression_ratio IS 'Compression ratio achieved';
COMMENT ON COLUMN public.van_images.processed_at IS 'When the image was processed';
COMMENT ON COLUMN public.van_images.retention_days IS 'How long to retain the image';
COMMENT ON COLUMN public.van_images.status IS 'Current status of the image (active/expired)'; 
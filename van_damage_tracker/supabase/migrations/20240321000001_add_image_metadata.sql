-- Add image metadata columns
ALTER TABLE public.van_images
    ADD COLUMN IF NOT EXISTS original_format TEXT,
    ADD COLUMN IF NOT EXISTS original_mode TEXT,
    ADD COLUMN IF NOT EXISTS original_size JSONB,
    ADD COLUMN IF NOT EXISTS original_size_bytes BIGINT,
    ADD COLUMN IF NOT EXISTS processed_size JSONB,
    ADD COLUMN IF NOT EXISTS processed_size_bytes BIGINT,
    ADD COLUMN IF NOT EXISTS compression_ratio FLOAT,
    ADD COLUMN IF NOT EXISTS processed_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS retention_days INTEGER DEFAULT 90;

-- Create index for faster queries on processed_at
CREATE INDEX IF NOT EXISTS idx_van_images_processed_at ON public.van_images(processed_at);

-- Create function to check image expiration
CREATE OR REPLACE FUNCTION check_image_expiration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.processed_at < NOW() - (NEW.retention_days || ' days')::INTERVAL THEN
        -- Mark image as expired by updating status
        NEW.status = 'expired';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for image expiration
DROP TRIGGER IF EXISTS check_image_expiration_trigger ON public.van_images;
CREATE TRIGGER check_image_expiration_trigger
    BEFORE UPDATE ON public.van_images
    FOR EACH ROW
    EXECUTE FUNCTION check_image_expiration();

-- Add status column with default value
ALTER TABLE public.van_images
    ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

-- Create index for status queries
CREATE INDEX IF NOT EXISTS idx_van_images_status ON public.van_images(status); 
-- Add image_data column to van_images table for base64 storage
-- This allows us to bypass Supabase storage constraints by storing images directly in the database

-- Add the image_data column to store base64 encoded images
ALTER TABLE van_images 
ADD COLUMN IF NOT EXISTS image_data TEXT;

-- Add a comment to document the column
COMMENT ON COLUMN van_images.image_data IS 'Base64 encoded image data to bypass storage constraints';

-- Optional: Add an index for better performance if needed
-- CREATE INDEX IF NOT EXISTS idx_van_images_has_data ON van_images (id) WHERE image_data IS NOT NULL;

-- Verify the column was added
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'van_images' 
AND column_name = 'image_data'; 
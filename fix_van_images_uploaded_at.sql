-- ========================================
-- FIX VAN_IMAGES UPLOADED_AT COLUMN
-- Run this in Supabase SQL Editor to fix the missing uploaded_at column
-- ========================================

BEGIN;

-- Check if uploaded_at column exists
DO $$ 
BEGIN
    -- Add uploaded_at column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' 
        AND column_name = 'uploaded_at'
        AND table_schema = 'public'
    ) THEN
        
        RAISE NOTICE 'Adding uploaded_at column to van_images table...';
        
        -- Add the column with NOT NULL constraint and default value
        ALTER TABLE public.van_images 
        ADD COLUMN uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL;
        
        -- Populate existing records with created_at value (or current time if created_at is null)
        UPDATE public.van_images 
        SET uploaded_at = COALESCE(created_at, NOW()) 
        WHERE uploaded_at IS NULL;
        
        -- Create index for better performance on uploaded_at queries
        CREATE INDEX IF NOT EXISTS idx_van_images_uploaded_at 
        ON public.van_images(uploaded_at DESC);
        
        RAISE NOTICE 'Successfully added uploaded_at column and populated existing records';
        
    ELSE
        RAISE NOTICE 'uploaded_at column already exists in van_images table';
    END IF;
    
    -- Ensure the column has proper constraints
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_images' 
        AND column_name = 'uploaded_at'
        AND is_nullable = 'YES'
        AND table_schema = 'public'
    ) THEN
        -- Make sure column is NOT NULL
        ALTER TABLE public.van_images 
        ALTER COLUMN uploaded_at SET NOT NULL;
        
        RAISE NOTICE 'Set uploaded_at column to NOT NULL';
    END IF;
    
    -- Update any NULL values that might exist
    UPDATE public.van_images 
    SET uploaded_at = COALESCE(created_at, updated_at, NOW()) 
    WHERE uploaded_at IS NULL;
    
END $$;

-- Create or replace trigger to automatically set uploaded_at for new records
CREATE OR REPLACE FUNCTION set_uploaded_at_on_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Set uploaded_at to NOW() if not explicitly provided
    IF NEW.uploaded_at IS NULL THEN
        NEW.uploaded_at := NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if it exists and recreate it
DROP TRIGGER IF EXISTS set_uploaded_at_trigger ON public.van_images;
CREATE TRIGGER set_uploaded_at_trigger
    BEFORE INSERT ON public.van_images
    FOR EACH ROW
    EXECUTE FUNCTION set_uploaded_at_on_insert();

-- Verify the fix by checking the table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'van_images'
AND table_schema = 'public'
AND column_name IN ('uploaded_at', 'created_at', 'updated_at')
ORDER BY column_name;

-- Show sample data to verify uploaded_at is populated
SELECT 
    id,
    image_url,
    uploaded_at,
    created_at,
    updated_at
FROM public.van_images
ORDER BY uploaded_at DESC
LIMIT 5;

-- Show count of records
SELECT 
    COUNT(*) as total_images,
    COUNT(uploaded_at) as images_with_uploaded_at,
    MIN(uploaded_at) as earliest_upload,
    MAX(uploaded_at) as latest_upload
FROM public.van_images;

COMMIT;

-- Success message
SELECT 'van_images.uploaded_at column fix completed successfully!' as result; 
-- Function to check if table exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'van_images') THEN
        RAISE NOTICE 'Creating van_images table...';
        
        -- Create van_images table
        CREATE TABLE van_images (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            van_id UUID REFERENCES vans(id),
            image_url TEXT NOT NULL,
            image_hash TEXT NOT NULL,
            damage_level NUMERIC(2,1) DEFAULT 0,
            damage_description TEXT,
            damage_location TEXT,
            confidence TEXT,
            last_assessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            CONSTRAINT fk_van FOREIGN KEY (van_id) REFERENCES vans(id) ON DELETE CASCADE
        );

        -- Create indexes
        CREATE INDEX idx_van_images_van_id ON van_images(van_id);
        CREATE INDEX idx_van_images_image_hash ON van_images(image_hash);

    ELSE
        RAISE NOTICE 'Table van_images exists, checking columns...';
        
        -- Add missing columns if they don't exist
        DO $columns$ 
        BEGIN 
            IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'van_images' AND column_name = 'damage_level') THEN
                ALTER TABLE van_images ADD COLUMN damage_level NUMERIC(2,1) DEFAULT 0;
                RAISE NOTICE 'Added damage_level column';
            END IF;

            IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'van_images' AND column_name = 'damage_description') THEN
                ALTER TABLE van_images ADD COLUMN damage_description TEXT;
                RAISE NOTICE 'Added damage_description column';
            END IF;

            IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'van_images' AND column_name = 'damage_location') THEN
                ALTER TABLE van_images ADD COLUMN damage_location TEXT;
                RAISE NOTICE 'Added damage_location column';
            END IF;

            IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'van_images' AND column_name = 'confidence') THEN
                ALTER TABLE van_images ADD COLUMN confidence TEXT;
                RAISE NOTICE 'Added confidence column';
            END IF;

            IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'van_images' AND column_name = 'last_assessed_at') THEN
                ALTER TABLE van_images ADD COLUMN last_assessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
                RAISE NOTICE 'Added last_assessed_at column';
            END IF;

            IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'van_images' AND column_name = 'updated_at') THEN
                ALTER TABLE van_images ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
                RAISE NOTICE 'Added updated_at column';
            END IF;
        END $columns$;
        
        -- Verify indexes exist
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'van_images' AND indexname = 'idx_van_images_van_id') THEN
            CREATE INDEX idx_van_images_van_id ON van_images(van_id);
            RAISE NOTICE 'Created missing van_id index';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'van_images' AND indexname = 'idx_van_images_image_hash') THEN
            CREATE INDEX idx_van_images_image_hash ON van_images(image_hash);
            RAISE NOTICE 'Created missing image_hash index';
        END IF;
    END IF;
END $$;

-- Create or replace the update trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_van_images_updated_at ON van_images;
CREATE TRIGGER update_van_images_updated_at
    BEFORE UPDATE ON van_images
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Verify the table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM 
    information_schema.columns 
WHERE 
    table_name = 'van_images'
ORDER BY 
    ordinal_position; 
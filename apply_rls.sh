#!/bin/bash

# Install Supabase CLI if not already installed
if ! command -v supabase &> /dev/null; then
    echo "Installing Supabase CLI..."
    curl -s -L https://github.com/supabase/cli/releases/download/v1.151.1/supabase_1.151.1_linux_amd64.deb -o supabase.deb
    sudo dpkg -i supabase.deb
    rm supabase.deb
fi

# Source environment variables
source .env

# Create a temporary migration file
cat > temp_migration.sql << 'EOL'
BEGIN;
  -- Enable Row Level Security if not already enabled
  DO $$ 
  BEGIN
      EXECUTE 'ALTER TABLE public.driver_profiles ENABLE ROW LEVEL SECURITY';
  EXCEPTION
      WHEN duplicate_object THEN
          NULL;
  END $$;

  -- Drop existing policies if they exist
  DO $$ 
  BEGIN
      EXECUTE 'DROP POLICY IF EXISTS "Enable read access for all users" ON public.driver_profiles';
      EXECUTE 'DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON public.driver_profiles';
      EXECUTE 'DROP POLICY IF EXISTS "Enable update access for authenticated users" ON public.driver_profiles';
      EXECUTE 'DROP POLICY IF EXISTS "Enable delete access for authenticated users" ON public.driver_profiles';
  END $$;

  -- Create policies for driver_profiles table
  CREATE POLICY "Enable read access for all users" ON public.driver_profiles
    FOR SELECT USING (true);

  CREATE POLICY "Enable insert access for authenticated users" ON public.driver_profiles
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

  CREATE POLICY "Enable update access for authenticated users" ON public.driver_profiles
    FOR UPDATE USING (auth.role() = 'authenticated');

  CREATE POLICY "Enable delete access for authenticated users" ON public.driver_profiles
    FOR DELETE USING (auth.role() = 'authenticated');

  -- Add comment
  COMMENT ON TABLE public.driver_profiles IS 'Stores driver information with RLS policies';
COMMIT;
EOL

# Initialize Supabase project if not already initialized
if [ ! -f "supabase/config.toml" ]; then
    echo "Initializing Supabase project..."
    supabase init
fi

# Link to the Supabase project
echo "Linking to Supabase project..."
supabase link --project-ref lcvbagsksedduygdzsca

# Apply the migration
echo "Applying RLS policies..."
supabase db push --db-url "postgres://postgres:${SUPABASE_KEY}@db.lcvbagsksedduygdzsca.supabase.co:5432/postgres" temp_migration.sql

# Clean up
rm temp_migration.sql 
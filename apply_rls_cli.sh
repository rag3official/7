#!/bin/bash

# Source environment variables
source .env

# Install Supabase CLI if not already installed
if ! command -v supabase &> /dev/null; then
    echo "Installing Supabase CLI..."
    curl -s -L https://github.com/supabase/cli/releases/download/v1.151.1/supabase_1.151.1_linux_amd64.deb -o supabase.deb
    sudo dpkg -i supabase.deb
    rm supabase.deb
fi

# Initialize Supabase project if not already initialized
if [ ! -f "supabase/config.toml" ]; then
    echo "Initializing Supabase project..."
    supabase init
fi

# Extract project reference from SUPABASE_URL
PROJECT_REF=$(echo $SUPABASE_URL | sed 's|https://||' | sed 's|\.supabase\.co.*||')

# Set up environment variables for psql
export PGPASSWORD=$SUPABASE_KEY
export PGSSLMODE=require

# Apply the SQL file directly using psql with Supavisor connection
echo "Applying RLS policies..."
psql "postgres://postgres.${PROJECT_REF}:${SUPABASE_KEY}@aws-0-us-east-1.pooler.supabase.com:5432/postgres?options=project%3D${PROJECT_REF}" -f apply_rls.sql -v ON_ERROR_STOP=1 -v ROLE=postgres -v SCHEMA=public

echo "Done!" 
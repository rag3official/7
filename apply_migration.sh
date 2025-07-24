#!/bin/bash

# Set up environment variables
export PGPASSWORD="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NDg1Njk3MSwiZXhwIjoyMDYwNDMyOTcxfQ.SHdnDSnCK6hvDToCYst6IbhPrCSk7aXGyjvmQJOGQqY"
export PGSSLMODE=require

# Set up connection parameters
PROJECT_REF="lcvbagsksedduygdzsca"
DB_HOST="db.${PROJECT_REF}.supabase.co"

# Apply migration
echo "Applying migration..."
psql -h $DB_HOST \
     -p 5432 \
     -U postgres \
     -d postgres \
     -f supabase/migrations/20240321000000_driver_profiles_rls.sql \
     -v ON_ERROR_STOP=1

# Check if the migration was successful
if [ $? -eq 0 ]; then
    echo "Migration applied successfully!"
    
    # Verify the policies
    echo "Verifying policies..."
    psql -h $DB_HOST \
         -p 5432 \
         -U postgres \
         -d postgres \
         -c "SELECT * FROM pg_policies WHERE tablename = 'driver_profiles';"
else
    echo "Failed to apply migration"
    exit 1
fi 
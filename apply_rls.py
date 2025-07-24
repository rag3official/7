import os
import requests
import json
import jwt

def read_env_file(file_path='.env'):
    """Read environment variables from .env file."""
    env_vars = {}
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                key, value = line.split('=', 1)
                env_vars[key.strip()] = value.strip().strip('"').strip("'")
    return env_vars

# Read environment variables from .env file
env_vars = read_env_file()
SUPABASE_URL = env_vars.get('SUPABASE_URL')
SUPABASE_KEY = env_vars.get('SUPABASE_KEY')
PROJECT_ID = 'lcvbagsksedduygdzsca'  # Extracted from SUPABASE_URL

print(f"SUPABASE_URL: {SUPABASE_URL}")
print(f"SUPABASE_KEY: {SUPABASE_KEY}")
print(f"PROJECT_ID: {PROJECT_ID}")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("Error: SUPABASE_URL and SUPABASE_KEY must be set in .env file")
    exit(1)

# SQL statements to apply
sql = """
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
"""

try:
    # Decode JWT to get claims
    claims = jwt.decode(SUPABASE_KEY, options={"verify_signature": False})
    print(f"Claims: {claims}")

    # Use JWT claims for authentication
    headers = {
        'apikey': SUPABASE_KEY,
        'Authorization': f'Bearer {SUPABASE_KEY}',
        'Content-Type': 'application/json',
        'X-Client-Info': 'supabase-py/0.0.1',
        'X-Project-Id': claims.get('ref', ''),
        'X-Project-Role': claims.get('role', '')
    }

    # Execute SQL using Management API
    response = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=headers,
        json={'sql': sql}
    )
    
    if response.status_code == 200:
        print("Successfully applied RLS policies!")
    else:
        print(f"Error: {response.status_code} - {response.text}")
        raise Exception(f"Failed to execute SQL: {response.text}")

except Exception as e:
    print(f"Error: {str(e)}")
    print("Failed to apply RLS policies") 
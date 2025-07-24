import os
import requests
import json

# Use the service role key directly
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NDg1Njk3MSwiZXhwIjoyMDYwNDMyOTcxfQ.SHdnDSnCK6hvDToCYst6IbhPrCSk7aXGyjvmQJOGQqY"
PROJECT_ID = 'lcvbagsksedduygdzsca'

print("Using service role key for authentication...")

# Read the SQL file
with open('supabase/migrations/20240321000000_driver_profiles_rls.sql', 'r') as f:
    sql = f.read()

# Set up headers for the Management API request
headers = {
    'Authorization': f'Bearer {SERVICE_ROLE_KEY}',
    'Content-Type': 'application/json'
}

# Make the API request to execute the SQL using the Management API
try:
    # Execute the SQL directly
    response = requests.post(
        f"https://api.supabase.com/v1/projects/{PROJECT_ID}/sql",
        headers=headers,
        json={'query': sql}
    )
    
    if response.status_code == 200:
        print("Successfully applied RLS policies!")
        
        # Verify the policies
        verify_sql = "SELECT * FROM pg_policies WHERE tablename = 'driver_profiles';"
        verify_response = requests.post(
            f"https://api.supabase.com/v1/projects/{PROJECT_ID}/sql",
            headers=headers,
            json={'query': verify_sql}
        )
        
        if verify_response.status_code == 200:
            print("\nCurrent policies:")
            print(json.dumps(verify_response.json(), indent=2))
        else:
            print(f"Failed to verify policies: {verify_response.text}")
    else:
        print(f"Error: {response.status_code}")
        print(response.text)
        
except Exception as e:
    print(f"Error: {str(e)}") 
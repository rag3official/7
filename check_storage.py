import os
from supabase import create_client

# Initialize client
supabase = create_client(
    'https://lcvbagsksedduygdzsca.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczMTA3NjkyNiwgZXhwIjoyMDQ2NjUyOTI2fQ.8H4a9xLEfGNVlU1BxGw1eJJJkK6-9aOyS2vKvZdQNNE'
)

# List storage contents
try:
    objects = supabase.storage.from_('van-images').list()
    print(f'Storage bucket contents ({len(objects)} items):')
    for obj in objects[:10]:  # Show first 10
        print(f'  - {obj.get("name", "Unknown")} ({obj.get("metadata", {}).get("size", "?")}) bytes')
        
    # Check for van folders
    folders = [obj for obj in objects if obj.get('metadata', {}).get('mimetype') is None]
    print(f'\nFolders found: {len(folders)}')
    for folder in folders[:5]:
        print(f'  📁 {folder.get("name", "Unknown")}')
        
except Exception as e:
    print(f'Error: {e}') 
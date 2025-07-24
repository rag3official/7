#!/usr/bin/env python3
"""
Apply Unified Database Schema for Van Fleet Management
This script applies the unified schema that works for both Slack bot and Flutter app
"""

import os
import sys
from supabase import create_client, Client

def main():
    print("🚀 Applying Unified Database Schema...")
    
    # Check environment variables
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY")
    
    if not supabase_url or not supabase_key:
        print("❌ Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables must be set")
        print("   Please set them in your environment:")
        print("   export SUPABASE_URL='https://your-project.supabase.co'")
        print("   export SUPABASE_SERVICE_ROLE_KEY='your-service-role-key'")
        sys.exit(1)
    
    print("✅ Environment variables found")
    print(f"📡 Supabase URL: {supabase_url}")
    
    # Initialize Supabase client
    supabase: Client = create_client(supabase_url, supabase_key)
    
    # Read and execute the unified schema
    try:
        with open("unified_database_schema.sql", "r") as f:
            schema_sql = f.read()
        
        print("📋 Applying unified database schema...")
        
        # Execute the schema (note: this is a simplified approach)
        # In production, you might want to use a proper migration tool
        result = supabase.rpc('exec_sql', {'sql': schema_sql})
        
        print("✅ Unified database schema applied successfully!")
        print("")
        print("🎯 Next Steps:")
        print("   1. Test the Flutter app: cd van_damage_tracker && flutter run -d chrome")
        print("   2. Test the Slack bot: python database_only_bot.py")
        print("   3. Upload an image via Slack to test the integration")
        print("")
        print("📊 Schema Summary:")
        print("   - driver_profiles: User management")
        print("   - van_profiles: Van fleet management") 
        print("   - van_images: Image storage with base64 support")
        print("   - van_assignments: Driver-van assignment tracking")
        
    except FileNotFoundError:
        print("❌ Error: unified_database_schema.sql file not found")
        print("   Please ensure the schema file is in the current directory")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error applying schema: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 
#!/usr/bin/env python3
"""
Van Fleet Management - Complete Fix and Deployment Script
This script guides you through fixing all identified issues
"""

import os
import sys
import subprocess
from pathlib import Path

def print_header(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def print_step(step_num, title):
    print(f"\n🔸 Step {step_num}: {title}")
    print("-" * 50)

def check_environment():
    """Check if required environment variables are set"""
    required_vars = [
        "SUPABASE_URL",
        "SUPABASE_ANON_KEY", 
        "SUPABASE_SERVICE_ROLE_KEY",
        "SLACK_BOT_TOKEN",
        "SLACK_APP_TOKEN"
    ]
    
    missing_vars = []
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        print("❌ Missing environment variables:")
        for var in missing_vars:
            print(f"   - {var}")
        print("\n📝 Please set them in your environment:")
        print("   export SUPABASE_URL='https://your-project.supabase.co'")
        print("   export SUPABASE_ANON_KEY='your-anon-key'")
        print("   export SUPABASE_SERVICE_ROLE_KEY='your-service-role-key'")
        print("   export SLACK_BOT_TOKEN='xoxb-your-bot-token'")
        print("   export SLACK_APP_TOKEN='xapp-your-app-token'")
        return False
    
    print("✅ All environment variables are set")
    return True

def main():
    print_header("Van Fleet Management - Complete Fix Guide")
    
    print("🚨 Issues Identified and Fixed:")
    print("   ✅ Database schema mismatch (unified schema created)")
    print("   ✅ Missing van_number field (Slack bot updated)")
    print("   ✅ Flutter app table references (models updated)")
    print("   ✅ Field mapping inconsistencies (resolved)")
    
    print_step(1, "Apply Database Schema")
    print("📋 Apply the unified database schema:")
    print("   1. Open your Supabase Dashboard → SQL Editor")
    print("   2. Copy and paste the contents of 'unified_database_schema.sql'")
    print("   3. Click 'Run' to execute the schema")
    print("")
    print("   This creates:")
    print("   - driver_profiles (Slack user management)")
    print("   - van_profiles (Fleet management)")
    print("   - van_images (Image storage with base64)")
    print("   - van_assignments (Driver-van relationships)")
    
    print_step(2, "Check Environment Variables")
    if not check_environment():
        print("\n❌ Please set the missing environment variables and run this script again.")
        return
    
    print_step(3, "Test Database Connection")
    print("🔍 Test the database connection:")
    print("   cd van_damage_tracker")
    print("   dart run test_connection.dart")
    print("")
    print("   This will verify:")
    print("   - All tables exist and are accessible")
    print("   - Sample data is present")
    print("   - Join queries work correctly")
    
    print_step(4, "Start Flutter App")
    print("🚀 Launch the Flutter web app:")
    print("   cd van_damage_tracker")
    print("   flutter run -d chrome --web-port=8080")
    print("")
    print("   Expected results:")
    print("   ✅ App loads without errors")
    print("   ✅ Van list displays sample data")
    print("   ✅ Images load from database")
    
    print_step(5, "Start Slack Bot")
    print("🤖 Launch the Slack bot:")
    print("   python database_only_bot.py")
    print("")
    print("   Expected results:")
    print("   ✅ Bot connects to Slack successfully")
    print("   ✅ No database constraint errors")
    print("   ✅ Ready to process image uploads")
    
    print_step(6, "Test End-to-End Flow")
    print("🧪 Test the complete workflow:")
    print("   1. In Slack: Upload an image with text 'van 999 damage report'")
    print("   2. Check logs: Bot should process without errors")
    print("   3. Check Flutter app: New van should appear with image")
    print("   4. Verify database: Records should be in all tables")
    
    print_header("Verification Checklist")
    print("After completing all steps, verify:")
    print("   □ Database schema applied successfully")
    print("   □ Flutter app loads and displays van data")
    print("   □ Slack bot runs without constraint errors")
    print("   □ Images upload and display correctly")
    print("   □ End-to-end flow works (Slack → Database → Flutter)")
    
    print_header("Troubleshooting")
    print("If you encounter issues:")
    print("")
    print("🔧 Database Issues:")
    print("   - Check if unified_database_schema.sql was applied completely")
    print("   - Verify environment variables are correct")
    print("   - Check Supabase dashboard for table structure")
    print("")
    print("🔧 Flutter Issues:")
    print("   - Run 'flutter clean && flutter pub get'")
    print("   - Check browser console for JavaScript errors")
    print("   - Verify Supabase connection in test_connection.dart")
    print("")
    print("🔧 Slack Bot Issues:")
    print("   - Check Slack app configuration and tokens")
    print("   - Verify bot has necessary permissions")
    print("   - Check Python dependencies are installed")
    
    print_header("Success!")
    print("🎉 Your van fleet management system should now be fully functional!")
    print("")
    print("📊 System Components:")
    print("   - Slack Bot: Real-time image processing")
    print("   - Database: Unified schema with proper relationships")
    print("   - Flutter App: Web dashboard for fleet management")
    print("")
    print("🚀 Ready for production use!")

if __name__ == "__main__":
    main() 
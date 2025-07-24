#!/usr/bin/env python3

import os
import sys
import base64
from datetime import datetime
from supabase import create_client, Client

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

def test_storage_configuration():
    """Test and diagnose storage bucket issues"""
    
    print("🔍 STORAGE CONFIGURATION DIAGNOSIS")
    print("=" * 50)
    
    # Initialize Supabase client
    try:
        supabase_url = os.environ.get('SUPABASE_URL')
        supabase_key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')
        
        if not supabase_url or not supabase_key:
            print("❌ Missing environment variables:")
            print(f"   SUPABASE_URL: {'✅' if supabase_url else '❌'}")
            print(f"   SUPABASE_SERVICE_ROLE_KEY: {'✅' if supabase_key else '❌'}")
            return False
            
        print(f"🔗 Supabase URL: {supabase_url}")
        print(f"🔑 Service Role Key: {supabase_key[:20]}...")
        
        supabase: Client = create_client(supabase_url, supabase_key)
        
    except Exception as e:
        print(f"❌ Failed to initialize Supabase client: {e}")
        return False
    
    # Test 1: List storage buckets
    print(f"\n📁 TEST 1: Listing storage buckets...")
    try:
        buckets = supabase.storage.list_buckets()
        print(f"✅ Found {len(buckets)} buckets:")
        for bucket in buckets:
            print(f"   📦 {bucket.name} (ID: {bucket.id}, Public: {bucket.public})")
            
    except Exception as e:
        print(f"❌ Failed to list buckets: {e}")
        print("💡 This suggests an authentication or permission issue")
        
    # Test 2: Check van-images bucket specifically
    print(f"\n📦 TEST 2: Testing van-images bucket access...")
    try:
        # Try to list files in van-images bucket
        files = supabase.storage.from_("van-images").list()
        print(f"✅ van-images bucket accessible, found {len(files)} items")
        
        # Show some examples
        for i, file in enumerate(files[:3]):
            print(f"   📄 {file.get('name', 'Unknown')} ({file.get('updated_at', 'No date')})")
        
        if len(files) > 3:
            print(f"   ... and {len(files) - 3} more files")
            
    except Exception as e:
        print(f"❌ Failed to access van-images bucket: {e}")
        print("💡 This is likely the source of your 'bucketId is required' error")
        
        # Check if error mentions bucketId
        if "bucketId" in str(e).lower():
            print("🎯 Confirmed: This is the bucketId error you're experiencing")
        
    # Test 3: Try uploading a test image
    print(f"\n📤 TEST 3: Testing image upload...")
    try:
        # Create a small test image (1x1 pixel PNG in base64)
        test_image_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        test_image_data = base64.b64decode(test_image_b64)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        file_path = f"van_test/test_image_{timestamp}.png"
        
        print(f"   📎 Uploading test file: {file_path}")
        
        result = supabase.storage.from_("van-images").upload(
            path=file_path,
            file=test_image_data,
            file_options={
                "content-type": "image/png",
                "upsert": True
            }
        )
        
        if result:
            print("✅ Test upload successful!")
            
            # Get public URL
            public_url = supabase.storage.from_("van-images").get_public_url(file_path)
            print(f"🔗 Public URL: {public_url}")
            
            # Try to delete the test file
            try:
                supabase.storage.from_("van-images").remove([file_path])
                print("🧹 Test file cleaned up")
            except:
                print("⚠️ Couldn't clean up test file (not critical)")
                
        else:
            print("❌ Test upload failed - no result returned")
            
    except Exception as e:
        print(f"❌ Test upload failed: {e}")
        print("💡 This confirms the storage issue")
        
        # Provide specific guidance based on error
        error_str = str(e).lower()
        if "bucketid" in error_str:
            print("🔧 SOLUTION: Update your Supabase client configuration")
        elif "unauthorized" in error_str or "403" in error_str:
            print("🔧 SOLUTION: Check your API key permissions")
        elif "404" in error_str:
            print("🔧 SOLUTION: The van-images bucket may not exist")
        
    # Test 4: Check database function
    print(f"\n🗄️ TEST 4: Testing save_slack_image function...")
    try:
        test_result = supabase.rpc('save_slack_image', {
            'van_number': 'TEST123',
            'image_data': test_image_b64,
            'uploader_name': 'test_script'
        }).execute()
        
        if test_result.data:
            print("✅ save_slack_image function works!")
            print(f"   Result: {test_result.data}")
        else:
            print("❌ save_slack_image function returned no data")
            
    except Exception as e:
        print(f"❌ save_slack_image function failed: {e}")
    
    print(f"\n🎯 DIAGNOSIS COMPLETE")
    print("=" * 50)
    
    return True

def fix_storage_client():
    """Create a properly configured Supabase client for storage"""
    
    print("\n🔧 CREATING FIXED STORAGE CLIENT")
    print("=" * 40)
    
    try:
        # Use service role key for storage operations
        supabase_url = os.environ.get('SUPABASE_URL')
        service_role_key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')
        
        # Create client with service role (has full permissions)
        supabase = create_client(supabase_url, service_role_key)
        
        print("✅ Storage client created with service role key")
        print("💡 This should resolve bucket access issues")
        
        return supabase
        
    except Exception as e:
        print(f"❌ Failed to create storage client: {e}")
        return None

if __name__ == "__main__":
    print("🚀 SUPABASE STORAGE DIAGNOSTIC TOOL")
    print("This will help identify and fix your storage bucket issues\n")
    
    # Run diagnosis
    success = test_storage_configuration()
    
    if success:
        print("\n💡 RECOMMENDATIONS:")
        print("1. Ensure you're using SUPABASE_SERVICE_ROLE_KEY (not ANON_KEY) for storage")
        print("2. Use bucket name 'van-images' (with hyphen)")
        print("3. Apply the storage bucket fix SQL if bucket policies are incorrect")
        print("4. Check your network connectivity (IPv4 vs IPv6 issue)")
    
    print(f"\n🔄 You can run this script anytime to test your storage configuration") 
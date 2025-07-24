#!/usr/bin/env python3
"""
Van Damage Tracker - Slack Bot (Bucket Issues Fixed)
Handles storage bucket configuration issues and provides better error reporting.
"""

import os
import logging
import base64
from io import BytesIO
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from supabase import create_client, Client
import requests
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

print("🚀 SLACK BOT - VAN DAMAGE TRACKER (BUCKET FIXED VERSION)")
print("=" * 60)

# Environment validation
required_env_vars = [
    'SUPABASE_URL', 
    'SUPABASE_KEY', 
    'SLACK_BOT_TOKEN', 
    'SLACK_SIGNING_SECRET'
]

missing_vars = [var for var in required_env_vars if not os.getenv(var)]
if missing_vars:
    logger.error(f"❌ Missing environment variables: {', '.join(missing_vars)}")
    exit(1)

logger.info("✅ All environment variables present")

# Initialize Supabase client
supabase_url = os.getenv('SUPABASE_URL')
supabase_key = os.getenv('SUPABASE_KEY')
supabase: Client = create_client(supabase_url, supabase_key)

# Initialize Slack app
app = App(
    token=os.getenv('SLACK_BOT_TOKEN'),
    signing_secret=os.getenv('SLACK_SIGNING_SECRET')
)

print("✅ Environment validated")
print("✅ Using enhanced bucket-aware storage system")
print("✅ Better error handling and diagnostics included")

def test_storage_configuration():
    """Test the current storage bucket configuration."""
    try:
        result = supabase.rpc('test_storage_configuration').execute()
        if result.data:
            return result.data
        return {"status": "ERROR", "error": "No data returned"}
    except Exception as e:
        logger.error(f"Storage configuration test failed: {e}")
        return {"status": "ERROR", "error": str(e)}

def save_image_to_database(van_number: str, image_data: str, uploader_name: str = "slack_bot"):
    """
    Save image using the enhanced v2 function that checks bucket configuration.
    """
    try:
        logger.info(f"Attempting to save image for van {van_number} using v2 function")
        
        # Try the v2 function first (with bucket verification)
        result = supabase.rpc('save_slack_image_v2', {
            'van_number': van_number,
            'image_data': image_data,
            'uploader_name': uploader_name
        }).execute()
        
        if result.data:
            logger.info(f"✅ Image saved successfully using v2 function: {result.data}")
            return result.data
        else:
            logger.error("❌ No data returned from v2 function")
            return {"success": False, "error": "No data returned"}
            
    except Exception as e:
        logger.error(f"❌ Database save failed: {e}")
        
        # Fallback to original function if v2 fails
        try:
            logger.info("Attempting fallback to original save_slack_image function")
            result = supabase.rpc('save_slack_image', {
                'van_number': van_number,
                'image_data': image_data,
                'uploader_name': uploader_name
            }).execute()
            
            if result.data:
                logger.info(f"✅ Image saved using fallback function: {result.data}")
                return result.data
            else:
                return {"success": False, "error": "Fallback also failed"}
                
        except Exception as fallback_error:
            logger.error(f"❌ Fallback function also failed: {fallback_error}")
            return {"success": False, "error": f"Both v2 and fallback failed: {str(e)}, {str(fallback_error)}"}

def download_image_from_slack(image_url: str, bot_token: str) -> str:
    """Download image from Slack and return as base64 string."""
    try:
        headers = {'Authorization': f'Bearer {bot_token}'}
        response = requests.get(image_url, headers=headers)
        response.raise_for_status()
        
        image_data = base64.b64encode(response.content).decode('utf-8')
        logger.info(f"✅ Image downloaded successfully, size: {len(response.content)} bytes")
        return image_data
        
    except Exception as e:
        logger.error(f"❌ Failed to download image: {e}")
        raise

@app.message("!van")
def handle_van_command(message, say):
    """Handle !van command for uploading damage images."""
    try:
        text = message.get('text', '').strip()
        
        # Extract van number from command
        parts = text.split()
        if len(parts) < 2:
            say("❌ Please provide a van number. Example: `!van 123`")
            return
            
        van_number = parts[1]
        user_name = message.get('user', 'unknown_user')
        
        # Check for attached files
        files = message.get('files', [])
        if not files:
            say(f"❌ Please attach an image when reporting damage for van {van_number}")
            return
            
        # Process first image
        file_info = files[0]
        if not file_info.get('mimetype', '').startswith('image/'):
            say("❌ Please attach an image file (JPEG, PNG, etc.)")
            return
            
        # Test storage configuration first
        storage_test = test_storage_configuration()
        if storage_test.get('status') != 'READY':
            logger.warning(f"Storage configuration issue: {storage_test}")
            say(f"⚠️ Storage configuration warning: {storage_test.get('status', 'UNKNOWN')}\nProceeding with database-only storage...")
            
        try:
            # Download and process image
            image_url = file_info['url_private']
            image_data = download_image_from_slack(image_url, os.getenv('SLACK_BOT_TOKEN'))
            
            # Save to database
            result = save_image_to_database(van_number, image_data, user_name)
            
            if result.get('success'):
                # Success response
                response_msg = f"✅ **Damage Report Saved**\n"
                response_msg += f"📋 Van: {van_number}\n"
                response_msg += f"👤 Reporter: <@{user_name}>\n"
                response_msg += f"🆔 Image ID: {result.get('image_id', 'N/A')}\n"
                response_msg += f"📁 File Path: {result.get('file_path', 'N/A')}\n"
                
                if 'version' in result:
                    response_msg += f"🔧 Method: {result['version']}\n"
                    
                if 'bucket_verified' in result:
                    bucket_status = "✅" if result['bucket_verified'] else "⚠️"
                    response_msg += f"🗄️ Bucket: {bucket_status}\n"
                    
                response_msg += f"⏰ Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                
                say(response_msg)
                
            else:
                # Error response
                error_msg = result.get('error', 'Unknown error')
                say(f"❌ **Failed to save damage report**\n📋 Van: {van_number}\n❗ Error: {error_msg}")
                
                # Check if it's a bucket issue
                if 'bucket' in error_msg.lower():
                    say("💡 **Troubleshooting Tip:** This appears to be a storage bucket issue. Please run the diagnostic SQL script to fix the bucket configuration.")
                    
        except Exception as e:
            logger.error(f"❌ Error processing image: {e}")
            say(f"❌ Error processing image for van {van_number}: {str(e)}")
            
    except Exception as e:
        logger.error(f"❌ Error in van command handler: {e}")
        say(f"❌ Something went wrong: {str(e)}")

@app.message("!storage-test")
def handle_storage_test(message, say):
    """Test storage configuration and report status."""
    try:
        result = test_storage_configuration()
        
        status = result.get('status', 'UNKNOWN')
        status_emoji = {
            'READY': '✅',
            'BUCKET_OK_POLICIES_MISSING': '⚠️',
            'BUCKET_MISSING': '❌',
            'ERROR': '🚨'
        }.get(status, '❓')
        
        response = f"{status_emoji} **Storage Configuration Test**\n"
        response += f"📊 Status: {status}\n"
        response += f"🗄️ Bucket Exists: {'✅' if result.get('bucket_exists') else '❌'}\n"
        response += f"🛡️ Policies Count: {result.get('policies_count', 0)}\n"
        response += f"🔑 Schema Access: {'✅' if result.get('schema_access') else '❌'}\n"
        response += f"⏰ Test Time: {result.get('test_timestamp', 'N/A')}\n"
        
        if status != 'READY':
            response += f"\n💡 **Action Required:** Run `diagnose_storage_bucket_issue.sql` to fix configuration"
            
        say(response)
        
    except Exception as e:
        logger.error(f"❌ Storage test failed: {e}")
        say(f"❌ Storage test failed: {str(e)}")

@app.message("!help")
def handle_help(message, say):
    """Show help information."""
    help_text = """
🤖 **Van Damage Tracker Bot Commands**

📸 **Report Damage:**
`!van [van_number]` + attach image
Example: `!van 123` (with image attached)

🔧 **Test Storage:**
`!storage-test` - Check storage configuration

❓ **Help:**
`!help` - Show this help message

🚀 **Features:**
• Enhanced bucket configuration detection
• Automatic fallback for storage issues  
• Better error reporting and diagnostics
• Database-first approach for reliability

⚠️ **Troubleshooting:**
If you get storage bucket errors, ask admin to run:
`diagnose_storage_bucket_issue.sql`
"""
    say(help_text)

def main():
    """Start the Slack bot."""
    try:
        # Test storage configuration on startup
        print("🔄 Testing storage configuration...")
        storage_test = test_storage_configuration()
        status = storage_test.get('status', 'UNKNOWN')
        
        if status == 'READY':
            print("✅ Storage configuration is ready")
        else:
            print(f"⚠️ Storage configuration issue detected: {status}")
            print("Bot will still work with database-only storage")
            
        print("🔄 Starting bot...")
        handler = SocketModeHandler(app, os.getenv('SLACK_APP_TOKEN'))
        handler.start()
        
    except KeyboardInterrupt:
        print("\n🛑 Bot stopped by user")
    except Exception as e:
        logger.error(f"❌ Bot startup failed: {e}")
        print(f"❌ Bot startup failed: {e}")

if __name__ == "__main__":
    main() 
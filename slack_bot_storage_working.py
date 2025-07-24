#!/usr/bin/env python3

import os
import logging
import base64
import hashlib
import mimetypes
import requests
from datetime import datetime
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from supabase import create_client, Client

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Slack app
app = App(token=os.environ.get("SLACK_BOT_TOKEN"))

# Initialize Supabase client (use service role for storage operations)
supabase: Client = create_client(
    os.environ.get("SUPABASE_URL"),
    os.environ.get("SUPABASE_SERVICE_ROLE_KEY")  # Use service role for full permissions
)

def extract_van_number(text: str) -> str:
    """Extract van number from message text."""
    import re
    
    # Look for patterns like "van 123", "van123", "#123", etc.
    patterns = [
        r'van\s*#?(\d+)',
        r'#(\d+)',
        r'vehicle\s*#?(\d+)',
        r'unit\s*#?(\d+)'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text.lower())
        if match:
            return match.group(1)
    
    return None

def save_image_via_database_function(image_data: bytes, van_number: str, uploader_name: str = "slack_bot") -> dict:
    """Save image using the working database function instead of direct storage upload."""
    try:
        # Convert image to base64
        image_base64 = base64.b64encode(image_data).decode('utf-8')
        
        logger.info(f"📤 Saving image for van {van_number} via database function...")
        
        # Use the working save_slack_image function
        result = supabase.rpc('save_slack_image', {
            'van_number': van_number,
            'image_data': image_base64,
            'uploader_name': uploader_name
        }).execute()
        
        if result.data and result.data.get('success'):
            logger.info("✅ Image saved successfully via database function!")
            return {
                "success": True,
                "method": "database_function",
                "van_id": result.data.get('van_id'),
                "image_id": result.data.get('image_id'),
                "file_path": result.data.get('file_path'),
                "url": result.data.get('storage_result', {}).get('url'),
                "size": len(image_data)
            }
        else:
            error_msg = result.data.get('error', 'Unknown error') if result.data else 'No data returned'
            logger.error(f"❌ Database function failed: {error_msg}")
            return {"success": False, "error": error_msg}
            
    except Exception as e:
        logger.error(f"❌ Error in database function: {e}")
        return {"success": False, "error": str(e)}

def get_or_create_van(van_number: str) -> tuple:
    """Get existing van or create new one."""
    try:
        # Try to find existing van
        van_result = supabase.table('vans').select('*').eq('van_number', van_number).execute()
        
        if van_result.data and len(van_result.data) > 0:
            logger.info(f"✅ Found existing van: {van_number}")
            return van_result.data[0]['id'], False
        
        # Create new van
        new_van = supabase.table('vans').insert({
            'van_number': van_number,
            'type': 'Transit',
            'status': 'Active',
            'created_at': datetime.now().isoformat()
        }).execute()
        
        if new_van.data:
            logger.info(f"✅ Created new van: {van_number}")
            return new_van.data[0]['id'], True
        else:
            logger.error("❌ Failed to create new van")
            return None, False
            
    except Exception as e:
        logger.error(f"❌ Error with van operations: {e}")
        return None, False

def download_slack_image(url: str, token: str) -> bytes:
    """Download image from Slack."""
    try:
        logger.info(f"📥 Downloading image from Slack...")
        headers = {"Authorization": f"Bearer {token}"}
        response = requests.get(url, headers=headers, timeout=30)
        
        if response.status_code == 200:
            logger.info(f"✅ Downloaded image ({len(response.content)} bytes)")
            return response.content
        else:
            logger.error(f"❌ Download failed: {response.status_code}")
            return None
            
    except Exception as e:
        logger.error(f"❌ Error downloading image: {e}")
        return None

@app.event("message")
def handle_message_events(body, say, client):
    """Handle message events with file uploads."""
    try:
        event = body.get("event", {})
        
        # Skip bot messages
        if event.get("bot_id"):
            return
        
        message_text = event.get("text", "")
        files = event.get("files", [])
        
        # Extract van number
        van_number = extract_van_number(message_text)
        if not van_number:
            logger.info("No van number found in message")
            return
        
        logger.info(f"🚐 Processing message for van #{van_number}")
        
        # Process images
        if files:
            for file_info in files:
                if file_info.get('mimetype', '').startswith('image/'):
                    logger.info(f"📷 Processing image: {file_info.get('name', 'unknown')}")
                    
                    # Download image
                    file_url = file_info.get("url_private_download") or file_info.get("url_private")
                    if not file_url:
                        logger.error("❌ No download URL found")
                        continue
                    
                    image_data = download_slack_image(file_url, os.environ.get('SLACK_BOT_TOKEN'))
                    if not image_data:
                        continue
                    
                    # Save image using working database function
                    save_result = save_image_via_database_function(image_data, van_number, "slack_bot_working")
                    
                    if save_result.get("success"):
                        # Send success message
                        say(
                            f"✅ Image processed for Van #{van_number}!\n"
                            f"📁 Saved via: {save_result.get('method', 'database_function')}\n"
                            f"📊 Size: {save_result.get('size', 0):,} bytes\n"
                            f"🆔 Image ID: {save_result.get('image_id', 'N/A')}"
                        )
                        logger.info(f"✅ Successfully processed image for van {van_number}")
                    else:
                        error_msg = save_result.get('error', 'Unknown error')
                        say(f"❌ Failed to process image for Van #{van_number}: {error_msg}")
                        logger.error(f"❌ Failed to process image: {error_msg}")
        
        else:
            # No files, just acknowledge the van number
            say(f"👍 I see you mentioned Van #{van_number}. Upload an image to process it!")
            
    except Exception as e:
        logger.error(f"❌ Error in message handler: {e}")

@app.message("test storage")
def handle_test_storage(message, say):
    """Test storage functionality."""
    try:
        # Create a small test image
        test_image_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        test_image_data = base64.b64decode(test_image_b64)
        
        # Test with van 999
        result = save_image_via_database_function(test_image_data, "999", "test_user")
        
        if result.get("success"):
            say(
                f"✅ Storage test successful!\n"
                f"📁 Method: {result.get('method')}\n"
                f"📊 Van ID: {result.get('van_id')}\n"
                f"🆔 Image ID: {result.get('image_id')}"
            )
        else:
            say(f"❌ Storage test failed: {result.get('error', 'Unknown error')}")
            
    except Exception as e:
        say(f"❌ Storage test error: {str(e)}")

@app.message("help")
def handle_help(message, say):
    """Show help information."""
    say(
        "🤖 **Van Damage Tracker Bot**\n\n"
        "**How to use:**\n"
        "• Mention a van number (e.g., 'van 123', '#456') and upload an image\n"
        "• I'll automatically save it to the van-images storage bucket\n\n"
        "**Commands:**\n"
        "• `test storage` - Test storage functionality\n"
        "• `help` - Show this help message\n\n"
        "**Features:**\n"
        "• ✅ Works around Python client storage issues\n"
        "• ✅ Uses working database function\n"
        "• ✅ Handles IPv4/IPv6 connectivity issues\n"
        "• ✅ Automatic van creation if needed"
    )

def validate_environment():
    """Validate required environment variables."""
    required_vars = [
        "SLACK_BOT_TOKEN",
        "SLACK_APP_TOKEN", 
        "SUPABASE_URL",
        "SUPABASE_SERVICE_ROLE_KEY"
    ]
    
    missing_vars = []
    for var in required_vars:
        if not os.environ.get(var):
            missing_vars.append(var)
    
    if missing_vars:
        logger.error(f"❌ Missing environment variables: {', '.join(missing_vars)}")
        return False
    
    logger.info("✅ All environment variables present")
    return True

if __name__ == "__main__":
    print("🚀 SLACK BOT - VAN DAMAGE TRACKER (STORAGE WORKING VERSION)")
    print("=" * 60)
    
    # Validate environment
    if not validate_environment():
        print("❌ Environment validation failed. Check your .env file.")
        exit(1)
    
    print("✅ Environment validated")
    print("✅ Using working database function for storage")
    print("✅ Bypassing Python client storage upload issues")
    print("🔄 Starting bot...")
    
    try:
        # Start the bot
        handler = SocketModeHandler(app, os.environ.get("SLACK_APP_TOKEN"))
        handler.start()
        
    except KeyboardInterrupt:
        print("\n👋 Bot stopped by user")
    except Exception as e:
        print(f"❌ Bot error: {e}")
        logger.error(f"Bot startup error: {e}") 
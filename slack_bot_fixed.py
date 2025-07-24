#!/usr/bin/env python3
"""
Van Damage Tracker - Slack Bot (Fixed Response Handling)
Fixed the bug where successful responses were being treated as errors.
"""

import os
import logging
import base64
import re
from datetime import datetime
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from supabase import create_client, Client
import requests

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def extract_van_number(text: str) -> str:
    """Extract van number from message text."""
    if not text:
        return None
    
    # Look for patterns like: van 123, #456, van#789, etc.
    patterns = [
        r'van\s*#?(\d+)',
        r'#(\d+)',
        r'(\d{3,})'  # 3+ digit numbers
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text.lower())
        if match:
            return match.group(1)
    
    return None

def save_image_via_database_function(image_data: bytes, van_number: str, uploader_name: str = "slack_bot") -> dict:
    """Save image using the working database function with proper response handling."""
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
        
        logger.info(f"🔍 Database function response: {result.data}")
        
        # Handle response properly
        if result.data:
            # The function returns the result directly, not wrapped in another object
            response_data = result.data
            
            # Check if the response indicates success
            if response_data.get('success') == True:
                logger.info("✅ Image saved successfully via database function!")
                return {
                    "success": True,
                    "method": "database_function",
                    "van_id": response_data.get('van_id'),
                    "image_id": response_data.get('image_id'),
                    "file_path": response_data.get('file_path'),
                    "url": response_data.get('storage_result', {}).get('url') if isinstance(response_data.get('storage_result'), dict) else None,
                    "size": len(image_data),
                    "raw_response": response_data  # Include for debugging
                }
            else:
                error_msg = response_data.get('error', 'Database function returned success=false')
                logger.error(f"❌ Database function returned error: {error_msg}")
                return {"success": False, "error": error_msg, "raw_response": response_data}
        else:
            logger.error("❌ No data returned from database function")
            return {"success": False, "error": "No data returned from database function"}
            
    except Exception as e:
        logger.error(f"❌ Exception in database function call: {e}")
        return {"success": False, "error": str(e)}

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

# Initialize Supabase client
supabase_url = os.environ.get('SUPABASE_URL')
supabase_key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')
supabase: Client = create_client(supabase_url, supabase_key)

# Initialize Slack app
app = App(
    token=os.environ.get('SLACK_BOT_TOKEN'),
    signing_secret=os.environ.get('SLACK_SIGNING_SECRET')
)

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
                    save_result = save_image_via_database_function(image_data, van_number, "slack_bot_fixed")
                    
                    if save_result.get("success"):
                        # Send success message
                        success_msg = f"✅ **Damage Report Saved for Van #{van_number}**\n"
                        success_msg += f"📁 Method: {save_result.get('method', 'database_function')}\n"
                        success_msg += f"📊 Size: {save_result.get('size', 0):,} bytes\n"
                        success_msg += f"🆔 Image ID: {save_result.get('image_id', 'N/A')}\n"
                        success_msg += f"📂 File Path: {save_result.get('file_path', 'N/A')}\n"
                        success_msg += f"⏰ Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                        
                        say(success_msg)
                        logger.info(f"✅ Successfully processed image for van {van_number}")
                    else:
                        error_msg = save_result.get('error', 'Unknown error')
                        say(f"❌ **Failed to save damage report for Van #{van_number}**\n❗ Error: {error_msg}")
                        logger.error(f"❌ Failed to process image: {error_msg}")
        else:
            # No files, just acknowledge the van number
            say(f"👍 I see you mentioned Van #{van_number}. Upload an image to report damage!")
            
    except Exception as e:
        logger.error(f"❌ Error in message handler: {e}")
        say(f"❌ Something went wrong: {str(e)}")

@app.message("test storage")
def handle_test_storage(message, say):
    """Test storage functionality."""
    try:
        # Create a small test image (1x1 pixel PNG)
        test_image_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        test_image_data = base64.b64decode(test_image_b64)
        
        # Test with van 999
        result = save_image_via_database_function(test_image_data, "999", "test_user")
        
        if result.get("success"):
            say(
                f"✅ **Storage test successful!**\n"
                f"📁 Method: {result.get('method')}\n"
                f"📊 Van ID: {result.get('van_id')}\n"
                f"🆔 Image ID: {result.get('image_id')}\n"
                f"📂 File Path: {result.get('file_path')}"
            )
        else:
            say(f"❌ **Storage test failed:** {result.get('error', 'Unknown error')}")
            
    except Exception as e:
        say(f"❌ Storage test error: {str(e)}")

@app.message("help")
def handle_help(message, say):
    """Show help information."""
    say(
        "🤖 **Van Damage Tracker Bot (Fixed Version)**\n\n"
        "**How to use:**\n"
        "• Mention a van number (e.g., 'van 123', '#456') and upload an image\n"
        "• I'll automatically save it to the database with proper error handling\n\n"
        "**Commands:**\n"
        "• `test storage` - Test storage functionality\n"
        "• `help` - Show this help message\n\n"
        "**Features:**\n"
        "• ✅ Fixed response handling bug\n"
        "• ✅ Better error messages\n"
        "• ✅ Uses working database function\n"
        "• ✅ Automatic van creation if needed\n"
        "• ✅ Proper success/failure detection"
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
    print("🚀 SLACK BOT - VAN DAMAGE TRACKER (FIXED VERSION)")
    print("=" * 55)
    
    # Validate environment
    if not validate_environment():
        print("❌ Environment validation failed. Check your .env file.")
        exit(1)
    
    print("✅ Environment validated")
    print("✅ Fixed response handling bug")
    print("✅ Using working database function for storage")
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
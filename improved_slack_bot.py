import os
import re
import logging
import requests
import mimetypes
from datetime import datetime
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from supabase import create_client, Client
from dotenv import load_dotenv

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Initialize Slack app
app = App(token=os.environ.get("SLACK_BOT_TOKEN"))

# Initialize Supabase client
supabase: Client = create_client(
    os.environ.get("SUPABASE_URL"),
    os.environ.get("SUPABASE_KEY")
)

def extract_text_from_event(event):
    """Extract text from Slack event with multiple methods"""
    text_parts = []
    
    # Method 1: Direct text
    if event.get("text"):
        text_parts.append(event["text"])
        logger.info(f"📄 Found direct text: '{event['text']}'")
    
    # Method 2: Blocks
    if event.get("blocks"):
        for block in event["blocks"]:
            if block.get("type") == "rich_text":
                for element in block.get("elements", []):
                    for item in element.get("elements", []):
                        if item.get("type") == "text" and item.get("text"):
                            text_parts.append(item["text"])
                            logger.info(f"🧱 Found block text: '{item['text']}'")
    
    final_text = " ".join(text_parts)
    logger.info(f"🔍 Extracted text from event: '{final_text}'")
    return final_text

def extract_van_number(text: str) -> str:
    """Extract van number from text using multiple patterns"""
    if not text:
        return None
    
    text = text.lower().strip()
    logger.info(f"🔍 Analyzing text for van number: '{text}'")
    
    patterns = [
        r'van\s*#?(\d+)',
        r'truck\s*#?(\d+)',
        r'vehicle\s*#?(\d+)', 
        r'#(\d+)',
        r'van\s*(\d+)',
        r'number\s*(\d+)',
        r'(\d+)'  # Just numbers as fallback
    ]
    
    for pattern in patterns:
        matches = re.findall(pattern, text)
        if matches:
            van_number = matches[0]
            logger.info(f"✅ Found van number using pattern '{pattern}': {van_number}")
            return van_number
    
    logger.info("❌ No van number found in text")
    return None

def find_van_number_in_recent_messages(client, channel_id: str, limit: int = 10) -> str:
    """Look for van number in recent channel messages"""
    try:
        logger.info(f"🔍 Looking for van number in recent messages for channel {channel_id}")
        
        # Get recent messages from the channel
        response = client.conversations_history(
            channel=channel_id,
            limit=limit
        )
        
        if not response['ok']:
            logger.error(f"❌ Failed to get channel history: {response.get('error')}")
            return None
        
        # Look through messages for van numbers
        for message in response['messages']:
            text = message.get('text', '')
            if text:
                van_number = extract_van_number(text)
                if van_number:
                    logger.info(f"✅ Found van number {van_number} in recent message: '{text[:50]}...'")
                    return van_number
        
        logger.info("❌ No van number found in recent messages")
        return None
        
    except Exception as e:
        logger.error(f"❌ Error searching recent messages: {e}")
        return None

def get_or_create_van(van_number: str) -> tuple:
    """Get existing van or create new one"""
    try:
        logger.info(f"🔍 Looking for van #{van_number}")
        
        # Try to find existing van
        response = supabase.table("vans").select("*").eq("van_number", van_number).execute()
        
        if response.data and len(response.data) > 0:
            van = response.data[0]
            logger.info(f"✅ Found existing van: {van['id']}")
            return van['id'], False
        
        # Create new van
        logger.info(f"🆕 Creating new van #{van_number}")
        new_van = {
            "van_number": van_number,
            "type": "Transit",
            "status": "Active", 
            "created_at": datetime.now().isoformat(),
            "last_updated": datetime.now().isoformat()
        }
        
        create_response = supabase.table("vans").insert(new_van).execute()
        
        if create_response.data and len(create_response.data) > 0:
            van_id = create_response.data[0]['id']
            logger.info(f"✅ Created new van: {van_id}")
            return van_id, True
        else:
            logger.error("❌ Failed to create van")
            return None, False
            
    except Exception as e:
        logger.error(f"❌ Error in get_or_create_van: {e}")
        return None, False

def upload_to_supabase_storage(image_data: bytes, van_number: str, filename: str) -> str:
    """Upload image to Supabase Storage and return public URL"""
    try:
        logger.info(f"📤 Uploading image to Supabase Storage: {filename}")
        bucket_name = "van-images"
        file_path = f"van_{van_number}/{filename}"
        
        # Get content type
        content_type = mimetypes.guess_type(filename)[0] or 'image/jpeg'
        
        # Upload the file
        logger.info(f"📤 Uploading to path: {file_path}")
        result = supabase.storage.from_(bucket_name).upload(
            file_path,
            image_data,
            {"content-type": content_type}
        )
        
        logger.info(f"📤 Upload result: {result}")
        
        # Get public URL
        public_url = supabase.storage.from_(bucket_name).get_public_url(file_path)
        logger.info(f"✅ Successfully uploaded image: {public_url}")
        return public_url
        
    except Exception as e:
        logger.error(f"❌ Error uploading to Supabase Storage: {str(e)}")
        # Try alternative upload method
        try:
            logger.info("🔄 Trying alternative upload method...")
            # Remove the file first if it exists
            try:
                supabase.storage.from_(bucket_name).remove([file_path])
            except:
                pass
            
            # Try upload again
            result = supabase.storage.from_(bucket_name).upload(
                file_path,
                image_data
            )
            
            if result:
                public_url = supabase.storage.from_(bucket_name).get_public_url(file_path)
                logger.info(f"✅ Alternative upload successful: {public_url}")
                return public_url
            
        except Exception as e2:
            logger.error(f"❌ Alternative upload also failed: {str(e2)}")
        
        return None

def save_van_image_record(van_id: str, image_url: str, van_number: str, filename: str) -> bool:
    """Save van image record to database"""
    try:
        logger.info(f"💾 Saving image record for van {van_id}")
        
        # Create van_images record
        record_data = {
            "van_id": van_id,
            "image_url": image_url,
            "uploaded_by": "slack_bot",
            "damage_level": 0,  # No damage assessment for now
            "description": f"Uploaded via Slack bot - {filename}",
            "created_at": datetime.now().isoformat(),
            "location": f"van_{van_number}",
            "status": "active"
        }
        
        response = supabase.table("van_images").insert(record_data).execute()
        
        if response.data:
            image_id = response.data[0].get('id', 'unknown')
            logger.info(f"✅ Successfully saved image record: {image_id}")
            return True
        else:
            logger.error("❌ Failed to save image record")
            return False
        
    except Exception as e:
        logger.error(f"❌ Error saving image record: {e}")
        return False

def update_van_info(van_id: str, image_url: str) -> bool:
    """Update van with latest image information"""
    try:
        logger.info("🔄 Updating van info...")
        
        # Prepare update data
        update_data = {
            "last_updated": datetime.now().isoformat(),
            "url": image_url,  # Store latest image URL
            "notes": f"Latest image uploaded via Slack bot at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        }
        
        response = supabase.table("vans").update(update_data).eq("id", van_id).execute()
        
        if response.data:
            logger.info("✅ Successfully updated van information")
            return True
        else:
            logger.error("❌ Failed to update van")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error updating van: {e}")
        return False

def download_image_from_slack(file_url: str, token: str) -> bytes:
    """Download image from Slack URL"""
    try:
        logger.info(f"📥 Downloading image from Slack: {file_url}")
        
        headers = {"Authorization": f"Bearer {token}"}
        response = requests.get(file_url, headers=headers, timeout=30)
        
        if response.status_code == 200:
            logger.info(f"✅ Successfully downloaded image ({len(response.content)} bytes)")
            return response.content
        else:
            logger.error(f"❌ Download failed: {response.status_code}")
            return None
            
    except Exception as e:
        logger.error(f"❌ Error downloading image: {e}")
        return None

def process_image_upload(client, channel_id: str, file_info: dict, van_number: str = None, say=None):
    """Process a single image upload"""
    try:
        # If no van number provided, look for it in recent messages
        if not van_number:
            van_number = find_van_number_in_recent_messages(client, channel_id)
        
        if not van_number:
            error_msg = "❌ No van number found. Please include van number in your message (e.g., 'van 123')"
            logger.error(error_msg)
            if say:
                say(error_msg)
            return False
        
        logger.info(f"📷 Processing image: {file_info.get('name', 'unknown')} for van #{van_number}")
        
        # Get or create van
        van_id, is_new = get_or_create_van(van_number)
        if not van_id:
            error_msg = f"❌ Failed to get/create van #{van_number}"
            logger.error(error_msg)
            if say:
                say(error_msg)
            return False
        
        # Download image from Slack
        file_url = file_info.get("url_private_download") or file_info.get("url_private")
        if not file_url:
            logger.error("❌ No download URL found")
            return False
        
        image_data = download_image_from_slack(file_url, os.environ.get('SLACK_BOT_TOKEN'))
        if not image_data:
            return False
        
        # Generate filename with timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        original_name = file_info.get('name', 'image.jpg')
        filename = f"slack_image_{timestamp}_{original_name}"
        
        # Upload to Supabase Storage
        public_url = upload_to_supabase_storage(image_data, van_number, filename)
        
        if public_url:
            # Save image record to database
            record_saved = save_van_image_record(van_id, public_url, van_number, filename)
            
            if record_saved:
                # Update van info
                update_van_info(van_id, public_url)
                
                success_msg = (f"✅ Successfully processed image for Van #{van_number}!\n"
                             f"📁 Stored in folder: van_{van_number}\n"
                             f"💾 Database record created\n"
                             f"🔗 {public_url}")
                logger.info(success_msg)
                if say:
                    say(success_msg)
                return True
            else:
                error_msg = f"❌ Failed to save database record for Van #{van_number}"
                logger.error(error_msg)
                if say:
                    say(error_msg)
        else:
            error_msg = f"❌ Failed to upload image for Van #{van_number}"
            logger.error(error_msg)
            if say:
                say(error_msg)
        
        return False
        
    except Exception as e:
        error_msg = f"❌ Error processing image: {str(e)}"
        logger.error(error_msg)
        if say:
            say(error_msg)
        return False

@app.event("message")
def handle_message_events(body, say, client):
    """Handle incoming message events"""
    try:
        event = body["event"]
        
        # Skip bot messages
        if event.get("bot_id") or event.get("subtype") == "bot_message":
            return
        
        logger.info("=" * 50)
        logger.info("📨 PROCESSING MESSAGE EVENT")
        logger.info("=" * 50)
        logger.info(f"Event: {event}")
        
        channel_id = event.get("channel")
        
        # Extract text and look for van numbers
        text = extract_text_from_event(event)
        van_number = extract_van_number(text)
        
        # Process any files in the message
        files = event.get("files", [])
        if files:
            logger.info(f"📷 Found {len(files)} files in message")
            processed_images = 0
            
            for file_info in files:
                # Only process image files
                if file_info.get('mimetype', '').startswith('image/'):
                    success = process_image_upload(client, channel_id, file_info, van_number, say)
                    if success:
                        processed_images += 1
            
            if processed_images == 0 and len([f for f in files if f.get('mimetype', '').startswith('image/')]) > 0:
                say("❌ Failed to process any images. Make sure to include a van number in your message.")
        
        elif van_number:
            # Just a message with van number, no files
            say(f"🚐 Van #{van_number} noted. Upload an image to store it in the database!")
        
    except Exception as e:
        logger.error(f"❌ Error in message handler: {e}")
        import traceback
        traceback.print_exc()

@app.event("file_shared")
def handle_file_shared_events(body, client, say):
    """Handle file shared events separately"""
    try:
        logger.info("=" * 50)
        logger.info("📁 PROCESSING FILE SHARED EVENT")
        logger.info("=" * 50)
        
        event = body["event"]
        file_id = event.get("file_id")
        channel_id = event.get("channel_id")
        
        if not file_id or not channel_id:
            logger.error("❌ Missing file_id or channel_id in file_shared event")
            return
        
        # Get file info
        file_response = client.files_info(file=file_id)
        if not file_response['ok']:
            logger.error(f"❌ Failed to get file info: {file_response.get('error')}")
            return
        
        file_info = file_response['file']
        
        # Only process image files
        if not file_info.get('mimetype', '').startswith('image/'):
            logger.info("📄 File is not an image, skipping")
            return
        
        # Look for van number in recent messages
        van_number = find_van_number_in_recent_messages(client, channel_id)
        
        # Process the image
        success = process_image_upload(client, channel_id, file_info, van_number, say)
        
        if not success and not van_number:
            say("❌ Please include a van number in your message when uploading images (e.g., 'van 123')")
        
    except Exception as e:
        logger.error(f"❌ Error in file_shared handler: {e}")
        import traceback
        traceback.print_exc()

@app.message("van")
def handle_van_messages(message, say):
    """Handle direct van-related messages"""
    say("🚐 Van Bot is ready! Upload an image with van number (e.g., 'van 123') to store it in the database.\n"
        "📁 Images will be organized by van number in the storage bucket.")

def validate_environment():
    """Validate all required environment variables"""
    logger.info("🔍 Validating environment variables...")
    
    required_vars = ["SLACK_BOT_TOKEN", "SLACK_APP_TOKEN", "SUPABASE_URL", "SUPABASE_KEY"]
    missing_vars = []
    
    for var in required_vars:
        if not os.environ.get(var):
            missing_vars.append(var)
        else:
            logger.info(f"  - {var}: ✅")
    
    if missing_vars:
        logger.error(f"❌ Missing environment variables: {missing_vars}")
        return False
    
    # Test Supabase connection
    try:
        logger.info("🔍 Testing Supabase database connection...")
        response = supabase.table("vans").select("id").limit(1).execute()
        logger.info("✅ Supabase database connection successful")
    except Exception as e:
        logger.error(f"❌ Supabase database connection failed: {e}")
        return False
    
    # Test storage access
    try:
        logger.info("🔍 Testing Supabase storage access...")
        # Try to list files in van-images bucket
        files = supabase.storage.from_("van-images").list()
        logger.info("✅ Supabase storage connection successful")
    except Exception as e:
        logger.error(f"❌ Supabase storage connection failed: {e}")
        return False
    
    logger.info("✅ Environment validation complete")
    return True

if __name__ == "__main__":
    try:
        logger.info("🚀 Starting IMPROVED Slack Bot with Supabase Storage...")
        logger.info("📁 Enhanced: File upload handling with recent message scanning")
        logger.info("🔍 Feature: Automatic van number detection from channel history")
        
        # Validate environment
        if not validate_environment():
            logger.error("❌ Environment validation failed, exiting")
            exit(1)
        
        # Start the app
        handler = SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"])
        handler.start()
        
    except Exception as e:
        logger.error(f"❌ Failed to start bot: {e}")
        exit(1) 
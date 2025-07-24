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
    ]
    
    for pattern in patterns:
        matches = re.findall(pattern, text)
        if matches:
            van_number = matches[0]
            logger.info(f"✅ Found van number using pattern '{pattern}': {van_number}")
            return van_number
    
    logger.info("❌ No van number found in text")
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

@app.event("message")
def handle_message_events(body, say, client):
    """Handle all message events"""
    try:
        event = body["event"]
        
        # Skip bot messages
        if event.get("bot_id") or event.get("subtype") == "bot_message":
            return
        
        logger.info("=" * 50)
        logger.info("📨 PROCESSING MESSAGE EVENT")
        logger.info("=" * 50)
        
        # Extract text and look for van numbers
        text = extract_text_from_event(event)
        van_number = extract_van_number(text)
        
        if not van_number:
            logger.info("❌ No van number found, skipping")
            return
        
        logger.info(f"🚐 Detected van number: {van_number}")
        
        # Process any files in the message
        files = event.get("files", [])
        if not files:
            logger.info("📷 No files found in message")
            return
        
        # Get or create van
        van_id, is_new = get_or_create_van(van_number)
        if not van_id:
            logger.error("❌ Failed to get/create van")
            say(f"❌ Failed to process van #{van_number}")
            return
        
        processed_images = 0
        
        for file_info in files:
            # Only process image files
            if not file_info.get('mimetype', '').startswith('image/'):
                continue
                
            logger.info(f"📷 Processing image: {file_info.get('name', 'unknown')}")
            
            # Download image from Slack
            file_url = file_info.get("url_private_download") or file_info.get("url_private")
            if not file_url:
                logger.error("❌ No download URL found")
                continue
            
            image_data = download_image_from_slack(file_url, os.environ.get('SLACK_BOT_TOKEN'))
            if not image_data:
                continue
            
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
                    processed_images += 1
                    
                    logger.info(f"✅ Successfully processed image for Van #{van_number}")
                else:
                    logger.error(f"❌ Failed to save record for Van #{van_number}")
            else:
                logger.error(f"❌ Failed to upload image for Van #{van_number}")
        
        # Send confirmation message
        if processed_images > 0:
            say(f"✅ Successfully processed {processed_images} image(s) for Van #{van_number}!\n"
                f"📁 Images organized in folder: van_{van_number}\n"
                f"💾 Stored in Supabase storage bucket\n"
                f"🔗 Database records created")
        else:
            say(f"❌ Failed to process images for Van #{van_number}")
        
    except Exception as e:
        logger.error(f"❌ Error in message handler: {e}")
        import traceback
        traceback.print_exc()

@app.event("file_shared")
def handle_file_shared_events(body, logger):
    """Handle file shared events - delegate to message handler"""
    logger.info("📁 File shared event received (handled by message event)")

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
        logger.info("🚀 Starting Slack Bot with Supabase Storage...")
        logger.info("📁 Focus: Proper image upload to storage bucket")
        
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
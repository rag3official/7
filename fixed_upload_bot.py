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

def detect_image_type(image_data: bytes, filename: str) -> str:
    """Detect image content type from data and filename"""
    # First, try to detect from file signature
    if image_data.startswith(b'\x89PNG'):
        return 'image/png'
    elif image_data.startswith(b'\xff\xd8\xff'):
        return 'image/jpeg'
    elif image_data.startswith(b'GIF87a') or image_data.startswith(b'GIF89a'):
        return 'image/gif'
    elif image_data.startswith(b'RIFF') and b'WEBP' in image_data[:12]:
        return 'image/webp'
    
    # Fallback to filename extension
    if filename.lower().endswith(('.png', '.PNG')):
        return 'image/png'
    elif filename.lower().endswith(('.jpg', '.jpeg', '.JPG', '.JPEG')):
        return 'image/jpeg'
    elif filename.lower().endswith(('.gif', '.GIF')):
        return 'image/gif'
    elif filename.lower().endswith(('.webp', '.WEBP')):
        return 'image/webp'
    
    # Default fallback
    return 'image/png'

def upload_to_supabase_storage(image_data: bytes, van_number: str, filename: str) -> str:
    """Upload image to Supabase Storage with ultra-simple approach"""
    try:
        logger.info(f"📤 Uploading image: {filename} ({len(image_data)} bytes)")
        bucket_name = "van-images"
        
        # Use the simplest possible filename to avoid any issues
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        # Determine extension from original filename
        if '.' in filename:
            ext = filename.split('.')[-1].lower()
            if ext not in ['jpg', 'jpeg', 'png', 'gif', 'webp']:
                ext = 'png'  # Default fallback
        else:
            ext = 'png'
        
        simple_filename = f"image_{timestamp}.{ext}"
        file_path = f"van_{van_number}/{simple_filename}"
        
        logger.info(f"📤 Using simplified path: {file_path}")
        
        # Try the most basic upload possible - no options, no headers
        try:
            logger.info("🔄 Attempting ultra-basic upload...")
            result = supabase.storage.from_(bucket_name).upload(file_path, image_data)
            logger.info(f"📤 Upload result: {result}")
            
            # Get public URL
            public_url = supabase.storage.from_(bucket_name).get_public_url(file_path)
            logger.info(f"✅ Ultra-basic upload successful: {public_url}")
            return public_url
            
        except Exception as basic_error:
            logger.error(f"❌ Ultra-basic upload failed: {str(basic_error)}")
            
            # Try removing any existing file and upload again
            try:
                logger.info("🗑️ Removing existing file and retrying...")
                supabase.storage.from_(bucket_name).remove([file_path])
                
                result = supabase.storage.from_(bucket_name).upload(file_path, image_data)
                public_url = supabase.storage.from_(bucket_name).get_public_url(file_path)
                logger.info(f"✅ Retry upload successful: {public_url}")
                return public_url
                
            except Exception as retry_error:
                logger.error(f"❌ Retry upload failed: {str(retry_error)}")
                
                # Final attempt with even simpler filename
                try:
                    logger.info("🔄 Final attempt with minimal filename...")
                    minimal_filename = f"img_{timestamp}.png"
                    minimal_path = f"van_{van_number}/{minimal_filename}"
                    
                    result = supabase.storage.from_(bucket_name).upload(minimal_path, image_data)
                    public_url = supabase.storage.from_(bucket_name).get_public_url(minimal_path)
                    logger.info(f"✅ Minimal upload successful: {public_url}")
                    return public_url
                    
                except Exception as final_error:
                    logger.error(f"❌ All upload attempts failed: {str(final_error)}")
                    return None
        
    except Exception as e:
        logger.error(f"❌ Error in upload function: {str(e)}")
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
        logger.info(f"📥 Downloading image from Slack")
        
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

@app.event("file_shared")
def handle_file_shared_events(body, client, say):
    """Handle file shared events with van number detection"""
    try:
        logger.info("=" * 50)
        logger.info("📁 PROCESSING FILE SHARED EVENT")
        logger.info("=" * 50)
        
        event = body["event"]
        file_id = event.get("file_id")
        channel_id = event.get("channel_id")
        
        if not file_id or not channel_id:
            logger.error("❌ Missing file_id or channel_id")
            return
        
        # Get recent messages to find van number
        logger.info(f"🔍 Looking for van number in recent messages for channel {channel_id}")
        van_number = None
        
        try:
            response = client.conversations_history(channel=channel_id, limit=10)
            if response["ok"]:
                for message in response["messages"]:
                    text = message.get("text", "")
                    if text:
                        van_match = extract_van_number(text)
                        if van_match:
                            van_number = van_match
                            logger.info(f"✅ Found van number {van_number} in recent message")
                            break
        except Exception as e:
            logger.error(f"❌ Error getting channel history: {e}")
        
        if not van_number:
            error_msg = "❌ No van number found in recent messages. Please include a van number (e.g., 'van 123') when uploading images."
            say(error_msg)
            logger.error(error_msg)
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
        
        logger.info(f"📷 Processing image for van #{van_number}")
        
        # Get or create van
        van_id, is_new = get_or_create_van(van_number)
        if not van_id:
            error_msg = f"❌ Failed to create van #{van_number}"
            say(error_msg)
            logger.error(error_msg)
            return
        
        # Download image from Slack
        file_url = file_info.get("url_private_download") or file_info.get("url_private")
        if not file_url:
            logger.error("❌ No download URL found")
            return
        
        image_data = download_image_from_slack(file_url, os.environ.get('SLACK_BOT_TOKEN'))
        if not image_data:
            error_msg = f"❌ Failed to download image for Van #{van_number}"
            say(error_msg)
            return
        
        # Debug: Check the first few bytes of the image
        logger.info(f"🔍 Image data first 20 bytes: {image_data[:20]}")
        logger.info(f"🔍 Image data type: {type(image_data)}")
        logger.info(f"🔍 Image data length: {len(image_data)}")
        
        # Generate filename with timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        original_name = file_info.get('name', 'image.png')
        # Clean filename to avoid issues
        clean_name = re.sub(r'[^a-zA-Z0-9._-]', '_', original_name)
        filename = f"slack_image_{timestamp}_{clean_name}"
        
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
                say(success_msg)
                logger.info(success_msg)
            else:
                error_msg = f"❌ Failed to save database record for Van #{van_number}"
                say(error_msg)
                logger.error(error_msg)
        else:
            error_msg = f"❌ Failed to upload image for Van #{van_number}"
            say(error_msg)
            logger.error(error_msg)
        
    except Exception as e:
        error_msg = f"❌ Error in file_shared handler: {str(e)}"
        logger.error(error_msg)
        say(error_msg)
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
        logger.info("🚀 Starting SIMPLE WORKING Slack Bot...")
        logger.info("📁 Focus: File upload with recent message van number detection")
        
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
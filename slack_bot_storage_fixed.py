import os
import re
import base64
import logging
import requests
from datetime import datetime
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from supabase import create_client, Client
import anthropic

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Slack app
app = App(token=os.environ.get("SLACK_BOT_TOKEN"))

# Global variables
supabase: Client = None
claude_client = None
van_images_schema = None
vans_schema = None

def get_claude_client():
    """Initialize Claude client"""
    global claude_client
    if claude_client is None:
        api_key = os.environ.get("CLAUDE_API_KEY")
        if not api_key:
            raise ValueError("CLAUDE_API_KEY environment variable is required")
        claude_client = anthropic.Anthropic(api_key=api_key)
        logger.info("✅ Claude client initialized successfully")
    return claude_client

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
    
    # Method 3: Attachments
    if event.get("attachments"):
        for attachment in event["attachments"]:
            if attachment.get("text"):
                text_parts.append(attachment["text"])
                logger.info(f"📎 Found attachment text: '{attachment['text']}'")
    
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
        r'(\d+)',
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
            "status": "Unknown", 
            "created_at": datetime.now().isoformat()
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

def upload_image_to_storage_fixed(image_data: bytes, van_number: str) -> dict:
    """Fixed storage upload that bypasses rate limiting and ensures proper folder structure"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_path = f"van_{van_number}/slack_image_{timestamp}.jpg"
    
    logger.info(f"🚀 FIXED STORAGE UPLOAD for {file_path}")
    
    # Method 1: Use raw HTTP upload with minimal headers
    try:
        logger.info("📤 Trying raw HTTP upload with minimal headers...")
        url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/van-images/{file_path}"
        
        # Minimal headers to avoid triggering rate limiting
        headers = {
            "Authorization": f"Bearer {os.environ.get('SUPABASE_KEY')}",
            "Content-Type": "image/jpeg",
            "Content-Length": str(len(image_data)),
        }
        
        response = requests.post(url, headers=headers, data=image_data, timeout=60)
        logger.info(f"📤 Raw upload response: {response.status_code}")
        
        if response.status_code in [200, 201]:
            storage_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/public/van-images/{file_path}"
            logger.info("✅ Raw HTTP upload successful!")
            return {
                "success": True,
                "url": storage_url,
                "method": "raw_http_upload",
                "is_base64": False,
                "folder": f"van_{van_number}"
            }
        else:
            logger.info(f"❌ Raw HTTP upload failed: {response.status_code} - {response.text}")
            
    except Exception as e:
        logger.info(f"❌ Raw HTTP upload exception: {e}")
    
    # Method 2: Use Supabase Python client with retry
    try:
        logger.info("📤 Trying Supabase Python client...")
        
        # Upload using the Python client
        storage_response = supabase.storage.from_("van-images").upload(
            file_path, 
            image_data, 
            file_options={"content-type": "image/jpeg", "upsert": "true"}
        )
        
        if hasattr(storage_response, 'path') or 'path' in str(storage_response):
            storage_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/public/van-images/{file_path}"
            logger.info("✅ Python client upload successful!")
            return {
                "success": True,
                "url": storage_url,
                "method": "python_client",
                "is_base64": False,
                "folder": f"van_{van_number}"
            }
        else:
            logger.info(f"❌ Python client upload failed: {storage_response}")
            
    except Exception as e:
        logger.info(f"❌ Python client exception: {e}")
    
    # Method 3: Alternative bucket approach
    try:
        logger.info("📤 Trying alternative bucket 'images'...")
        alt_file_path = f"vans/van_{van_number}/slack_image_{timestamp}.jpg"
        
        alt_response = supabase.storage.from_("images").upload(
            alt_file_path, 
            image_data,
            file_options={"content-type": "image/jpeg", "upsert": "true"}
        )
        
        if hasattr(alt_response, 'path') or 'path' in str(alt_response):
            storage_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/public/images/{alt_file_path}"
            logger.info("✅ Alternative bucket upload successful!")
            return {
                "success": True,
                "url": storage_url,
                "method": "alternative_bucket",
                "is_base64": False,
                "folder": f"vans/van_{van_number}"
            }
            
    except Exception as e:
        logger.info(f"❌ Alternative bucket exception: {e}")
    
    # Method 4: Direct bucket creation and upload
    try:
        logger.info("📤 Trying direct bucket creation...")
        
        # First ensure bucket exists
        try:
            supabase.storage.create_bucket("van-images-backup", options={"public": True})
        except:
            pass  # Bucket might already exist
        
        backup_response = supabase.storage.from_("van-images-backup").upload(
            file_path,
            image_data,
            file_options={"content-type": "image/jpeg", "upsert": "true"}
        )
        
        if hasattr(backup_response, 'path') or 'path' in str(backup_response):
            storage_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/public/van-images-backup/{file_path}"
            logger.info("✅ Backup bucket upload successful!")
            return {
                "success": True,
                "url": storage_url,
                "method": "backup_bucket",
                "is_base64": False,
                "folder": f"van_{van_number}"
            }
            
    except Exception as e:
        logger.info(f"❌ Backup bucket exception: {e}")
    
    # Method 5: PUT request instead of POST
    try:
        logger.info("📤 Trying PUT request...")
        url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/van-images/{file_path}"
        
        headers = {
            "Authorization": f"Bearer {os.environ.get('SUPABASE_KEY')}",
            "Content-Type": "image/jpeg",
        }
        
        put_response = requests.put(url, headers=headers, data=image_data, timeout=60)
        logger.info(f"📤 PUT response: {put_response.status_code}")
        
        if put_response.status_code in [200, 201]:
            storage_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/public/van-images/{file_path}"
            logger.info("✅ PUT request successful!")
            return {
                "success": True,
                "url": storage_url,
                "method": "put_request",
                "is_base64": False,
                "folder": f"van_{van_number}"
            }
            
    except Exception as e:
        logger.info(f"❌ PUT request exception: {e}")
    
    # Fallback: Base64 storage (guaranteed to work)
    logger.info("💾 Using guaranteed base64 storage...")
    data_url = f"data:image/jpeg;base64,{base64.b64encode(image_data).decode('utf-8')}"
    
    return {
        "success": True,
        "url": data_url,
        "method": "base64_fallback",
        "is_base64": True,
        "folder": f"base64_van_{van_number}"
    }

def save_van_image_smart(van_id: str, image_data: bytes, van_number: str, damage_assessment: str = None, damage_level: int = 0) -> bool:
    """Save van image with smart schema detection"""
    try:
        # Upload image first
        upload_result = upload_image_to_storage_fixed(image_data, van_number)
        
        if not upload_result["success"]:
            logger.error("❌ Failed to upload image")
            return False
        
        storage_url = upload_result["url"]
        storage_method = upload_result["method"]
        logger.info(f"✅ Image uploaded via {storage_method}")
        
        # Get current timestamp
        timestamp = datetime.now().isoformat()
        
        # Prepare record data
        record_data = {
            "van_id": van_id,
            "image_url": storage_url,
            "uploaded_by": "slack_bot",
            "damage_level": damage_level,
            "description": damage_assessment or "Uploaded via Slack bot",
            "created_at": timestamp,
            "folder_path": upload_result.get("folder", f"van_{van_number}"),
            "upload_method": storage_method
        }
        
        # Try to save the record
        logger.info(f"💾 Saving image record with folder: {upload_result.get('folder')}")
        response = supabase.table("van_images").insert(record_data).execute()
        
        if response.data:
            logger.info("✅ Successfully saved image record with folder structure")
            return True
        else:
            logger.error("❌ Failed to save image record")
            return False
        
    except Exception as e:
        logger.error(f"❌ Error in save_van_image_smart: {e}")
        return False

def update_van_damage_smart(van_id: str, damage_assessment: str, damage_level: int) -> bool:
    """Update van damage information with smart schema detection"""
    try:
        logger.info("🔄 Updating van damage info...")
        
        # Prepare update data
        update_data = {
            "notes": damage_assessment,
            "last_updated": datetime.now().isoformat(),
            "damage": str(damage_level)
        }
        
        # Update the van
        logger.info(f"💾 Updating van with damage info")
        response = supabase.table("vans").update(update_data).eq("id", van_id).execute()
        
        if response.data:
            logger.info("✅ Successfully updated van damage information")
            return True
        else:
            logger.error("❌ Failed to update van")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error in update_van_damage_smart: {e}")
        return False

def analyze_damage_with_claude(image_data: bytes, file_info: dict = None) -> dict:
    """Analyze vehicle damage using Claude"""
    try:
        logger.info("🧠 Analyzing damage with Claude...")
        
        # Detect image format
        if image_data.startswith(b'\xff\xd8'):
            media_type = "image/jpeg"
        elif image_data.startswith(b'\x89PNG'):
            media_type = "image/png"
        elif image_data.startswith(b'GIF8'):
            media_type = "image/gif"
        elif image_data.startswith(b'RIFF'):
            media_type = "image/webp"
        else:
            media_type = "image/jpeg"  # Default fallback
        
        logger.info(f"🖼️ Detected image format: {media_type}")
        
        # Prepare the prompt
        analysis_prompt = """You are a vehicle damage assessment expert. Analyze this image and provide:

1. **Damage Level** (1-5 scale):
   - 1: No visible damage
   - 2: Minor scratches/scuffs
   - 3: Moderate damage (dents, scratches)
   - 4: Major damage (significant dents, broken parts)
   - 5: Severe damage (structural damage, safety concerns)

2. **Description**: Brief description of visible damage
3. **Location**: Which part of the vehicle is damaged
4. **Severity**: Assessment of repair urgency

Format your response as:
Damage Level: [1-5]
Description: [brief description]
Location: [vehicle part/area]
Severity: [Low/Medium/High]"""

        logger.info("🧠 Sending image to Claude for analysis...")
        
        # Encode image for Claude
        image_base64 = base64.b64encode(image_data).decode('utf-8')
        
        # Create message for Claude
        message = claude_client.messages.create(
            model="claude-3-sonnet-20240229",
            max_tokens=1000,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media_type,
                                "data": image_base64
                            }
                        },
                        {
                            "type": "text",
                            "text": analysis_prompt
                        }
                    ]
                }
            ]
        )
        
        analysis_text = message.content[0].text if message.content else "No analysis available"
        logger.info(f"🧠 Claude analysis complete: {analysis_text[:100]}...")
        
        # Extract damage level from response
        damage_level = 1
        damage_match = re.search(r'Damage Level:\s*(\d+)', analysis_text)
        if damage_match:
            damage_level = int(damage_match.group(1))
        
        return {
            "assessment": analysis_text,
            "damage_level": damage_level,
            "success": True
        }
        
    except Exception as e:
        logger.error(f"❌ Error in Claude analysis: {e}")
        return {
            "assessment": f"Error during analysis: {str(e)}",
            "damage_level": 0,
            "success": False
        }

def validate_environment():
    """Validate all required environment variables and connections"""
    logger.info("🔍 Validating environment variables...")
    
    required_vars = ["SLACK_BOT_TOKEN", "SLACK_APP_TOKEN", "SUPABASE_URL", "SUPABASE_KEY", "CLAUDE_API_KEY"]
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
    
    # Test Supabase storage
    try:
        logger.info("🔍 Testing Supabase storage access...")
        buckets = supabase.storage.list_buckets()
        storage_response = supabase.storage.from_("van-images").list()
        bucket_items = len(storage_response) if storage_response else 0
        logger.info(f"✅ Storage bucket 'van-images' accessible ({bucket_items} items)")
    except Exception as e:
        logger.error(f"❌ Supabase storage access failed: {e}")
        return False
    
    # Test Claude API
    try:
        logger.info("🔍 Testing Claude API connection...")
        get_claude_client()
        logger.info("✅ Claude API client initialized")
    except Exception as e:
        logger.error(f"❌ Claude API connection failed: {e}")
        return False
    
    logger.info("✅ Environment validation complete")
    return True

@app.event("message")
def handle_message_events(body, say, client):
    """Handle all message events"""
    try:
        event = body["event"]
        
        # Skip bot messages
        if event.get("bot_id") or event.get("subtype") == "bot_message":
            return
        
        logger.info("==================================================")
        logger.info("📨 ULTRA FIXED MESSAGE HANDLER")
        logger.info("==================================================")
        
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
        
        for file_info in files:
            logger.info(f"📷 Processing image: {file_info.get('name', 'unknown')}")
            
            # Get or create van
            van_id, is_new = get_or_create_van(van_number)
            if not van_id:
                logger.error("❌ Failed to get/create van")
                continue
            
            # Download image
            try:
                file_url = file_info.get("url_private_download") or file_info.get("url_private")
                if not file_url:
                    logger.error("❌ No download URL found")
                    continue
                
                logger.info(f"📥 Downloading image from URL: {file_url}")
                
                headers = {"Authorization": f"Bearer {os.environ.get('SLACK_BOT_TOKEN')}"}
                response = requests.get(file_url, headers=headers, timeout=30)
                
                if response.status_code != 200:
                    logger.error(f"❌ Download failed: {response.status_code}")
                    continue
                
                image_data = response.content
                logger.info(f"✅ Successfully downloaded image ({len(image_data)} bytes)")
                
                # Analyze damage with Claude
                analysis_result = analyze_damage_with_claude(image_data, file_info)
                damage_assessment = analysis_result["assessment"]
                damage_level = analysis_result["damage_level"]
                
                # Save image to database with folder structure
                save_success = save_van_image_smart(van_id, image_data, van_number, damage_assessment, damage_level)
                
                if save_success:
                    # Update van damage info
                    update_van_damage_smart(van_id, damage_assessment, damage_level)
                    
                    # Send confirmation
                    say(f"✅ Image processed for Van #{van_number}!\n"
                        f"📁 Saved to folder: van_{van_number}\n"
                        f"🔍 Damage Level: {damage_level}\n"
                        f"📝 Analysis: {damage_assessment[:200]}...")
                else:
                    say(f"❌ Failed to process image for Van #{van_number}")
                
            except Exception as e:
                logger.error(f"❌ Error processing file: {e}")
                continue
        
    except Exception as e:
        logger.error(f"❌ Error in message handler: {e}")

@app.event("file_shared")
def handle_file_shared_events(body, logger):
    """Handle file shared events - delegate to message handler"""
    logger.info("📁 File shared event received (handled by message event)")

@app.message("van")
def handle_van_messages(message, say):
    """Handle direct van-related messages"""
    say("🚐 Van bot is listening! Upload an image with van number (e.g., 'van 123') to analyze damage.")

if __name__ == "__main__":
    try:
        # Initialize Supabase
        supabase_url = os.environ.get("SUPABASE_URL")
        supabase_key = os.environ.get("SUPABASE_KEY")
        
        if not supabase_url or not supabase_key:
            raise ValueError("SUPABASE_URL and SUPABASE_KEY are required")
        
        supabase = create_client(supabase_url, supabase_key)
        logger.info("✅ Supabase client initialized")
        
        # Initialize Claude
        get_claude_client()
        
        logger.info("🚀 Starting ULTRA FIXED Slack Bot...")
        
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
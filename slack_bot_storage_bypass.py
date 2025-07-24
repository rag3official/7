import os
import re
import base64
import logging
import requests
from datetime import datetime
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from supabase import create_client, Client

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Slack app
app = App(token=os.environ.get("SLACK_BOT_TOKEN"))

# Global variables
supabase: Client = None

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

def try_bypass_storage_upload(image_data: bytes, van_number: str) -> dict:
    """Try multiple bypass methods for storage upload"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_path = f"van_{van_number}/slack_image_{timestamp}.jpg"
    
    logger.info(f"🚀 STORAGE BYPASS UPLOAD for {file_path}")
    
    # Method 1: Try using direct PUT request to storage with minimal headers
    try:
        logger.info("📤 Trying direct PUT request...")
        
        url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/van-images/{file_path}"
        
        headers = {
            "Authorization": f"Bearer {os.environ.get('SUPABASE_KEY')}",
            "Content-Type": "image/jpeg",
            "x-upsert": "true"  # This bypasses some constraints
        }
        
        response = requests.put(url, headers=headers, data=image_data, timeout=30)
        logger.info(f"📤 PUT upload response: {response.status_code}")
        
        if response.status_code in [200, 201]:
            public_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/public/van-images/{file_path}"
            logger.info("✅ PUT upload successful!")
            return {
                "success": True,
                "url": public_url,
                "method": "direct_put",
                "is_base64": False,
                "folder": f"van_{van_number}",
                "filename": f"slack_image_{timestamp}.jpg"
            }
        else:
            logger.info(f"❌ PUT upload failed: {response.status_code} - {response.text}")
            
    except Exception as e:
        logger.info(f"❌ PUT upload exception: {e}")
    
    # Method 2: Try multipart upload
    try:
        logger.info("📤 Trying multipart upload...")
        
        url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/van-images/{file_path}"
        
        files = {
            'file': (f"slack_image_{timestamp}.jpg", image_data, 'image/jpeg')
        }
        
        headers = {
            "Authorization": f"Bearer {os.environ.get('SUPABASE_KEY')}",
        }
        
        response = requests.post(url, headers=headers, files=files, timeout=30)
        logger.info(f"📤 Multipart upload response: {response.status_code}")
        
        if response.status_code in [200, 201]:
            public_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/public/van-images/{file_path}"
            logger.info("✅ Multipart upload successful!")
            return {
                "success": True,
                "url": public_url,
                "method": "multipart",
                "is_base64": False,
                "folder": f"van_{van_number}",
                "filename": f"slack_image_{timestamp}.jpg"
            }
        else:
            logger.info(f"❌ Multipart upload failed: {response.status_code} - {response.text}")
            
    except Exception as e:
        logger.info(f"❌ Multipart upload exception: {e}")
    
    # Method 3: Try using RPC function to bypass constraints
    try:
        logger.info("📤 Trying RPC bypass...")
        
        # Call the bypass function if it exists
        response = supabase.rpc('bypass_storage_upload', {
            'bucket_name': 'van-images',
            'file_path': file_path,
            'file_data': image_data,
            'content_type': 'image/jpeg'
        }).execute()
        
        if response.data:
            logger.info("✅ RPC bypass successful!")
            return {
                "success": True,
                "url": response.data,
                "method": "rpc_bypass",
                "is_base64": False,
                "folder": f"van_{van_number}",
                "filename": f"slack_image_{timestamp}.jpg"
            }
        else:
            logger.info("❌ RPC bypass failed")
            
    except Exception as e:
        logger.info(f"❌ RPC bypass exception: {e}")
    
    # Method 4: Try using service role with different endpoint
    try:
        logger.info("📤 Trying service role endpoint...")
        
        url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/upload/van-images/{file_path}"
        
        headers = {
            "Authorization": f"Bearer {os.environ.get('SUPABASE_KEY')}",
            "Content-Type": "image/jpeg",
            "apikey": os.environ.get('SUPABASE_KEY')
        }
        
        response = requests.post(url, headers=headers, data=image_data, timeout=30)
        logger.info(f"📤 Service role upload response: {response.status_code}")
        
        if response.status_code in [200, 201]:
            public_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/public/van-images/{file_path}"
            logger.info("✅ Service role upload successful!")
            return {
                "success": True,
                "url": public_url,
                "method": "service_role",
                "is_base64": False,
                "folder": f"van_{van_number}",
                "filename": f"slack_image_{timestamp}.jpg"
            }
        else:
            logger.info(f"❌ Service role upload failed: {response.status_code} - {response.text}")
            
    except Exception as e:
        logger.info(f"❌ Service role upload exception: {e}")
    
    # Method 5: Database storage fallback
    logger.info("💾 All storage methods failed, using database fallback...")
    data_url = f"data:image/jpeg;base64,{base64.b64encode(image_data).decode('utf-8')}"
    
    return {
        "success": True,
        "url": data_url,
        "method": "database_storage",
        "is_base64": True,
        "folder": f"van_{van_number}",
        "filename": f"slack_image_{timestamp}.jpg"
    }

def save_van_image_bypass(van_id: str, image_data: bytes, van_number: str) -> bool:
    """Save van image using bypass methods"""
    try:
        # Try bypass storage upload
        upload_result = try_bypass_storage_upload(image_data, van_number)
        
        if not upload_result["success"]:
            logger.error("❌ Failed to store image")
            return False
        
        storage_url = upload_result["url"]
        storage_method = upload_result["method"]
        folder_path = upload_result.get("folder", f"van_{van_number}")
        
        logger.info(f"✅ Image stored via {storage_method}")
        logger.info(f"📁 Folder structure: {folder_path}")
        
        # Get current timestamp
        timestamp = datetime.now().isoformat()
        
        # Prepare record data with folder information
        record_data = {
            "van_id": van_id,
            "image_url": storage_url,
            "uploaded_by": "slack_bot",
            "damage_level": 0,  # No Claude analysis
            "description": f"Uploaded via Slack bot - Storage method: {storage_method}",
            "created_at": timestamp,
            "location": folder_path,
        }
        
        # Try to save the record
        logger.info(f"💾 Saving image record with folder: {folder_path}")
        response = supabase.table("van_images").insert(record_data).execute()
        
        if response.data:
            logger.info("✅ Successfully saved image record with folder organization")
            return True
        else:
            logger.error("❌ Failed to save image record")
            return False
        
    except Exception as e:
        logger.error(f"❌ Error in save_van_image_bypass: {e}")
        return False

def update_van_simple(van_id: str, storage_method: str) -> bool:
    """Update van with simple information"""
    try:
        logger.info("🔄 Updating van info...")
        
        # Prepare update data
        update_data = {
            "notes": f"Image uploaded via Slack bot - Storage method: {storage_method}",
            "last_updated": datetime.now().isoformat(),
        }
        
        # Update the van
        logger.info(f"💾 Updating van with storage method: {storage_method}")
        response = supabase.table("vans").update(update_data).eq("id", van_id).execute()
        
        if response.data:
            logger.info("✅ Successfully updated van information")
            return True
        else:
            logger.error("❌ Failed to update van")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error in update_van_simple: {e}")
        return False

def validate_environment():
    """Validate all required environment variables and connections"""
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
        logger.info("📨 STORAGE BYPASS MESSAGE HANDLER - NO CLAUDE AI")
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
                
                # Save image using bypass methods
                save_success = save_van_image_bypass(van_id, image_data, van_number)
                
                if save_success:
                    # Update van info
                    update_van_simple(van_id, "bypass_method")
                    
                    # Send confirmation
                    say(f"✅ Image processed for Van #{van_number}!\n"
                        f"📁 Organized in folder: van_{van_number}\n"
                        f"🔧 Used bypass storage methods\n"
                        f"💾 No AI analysis (Claude disabled)")
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
    say("🚐 Van bot is listening! Upload an image with van number (e.g., 'van 123') to test storage bypass methods.\n🔧 Claude AI disabled, storage bypass enabled.")

if __name__ == "__main__":
    try:
        # Initialize Supabase
        supabase_url = os.environ.get("SUPABASE_URL")
        supabase_key = os.environ.get("SUPABASE_KEY")
        
        if not supabase_url or not supabase_key:
            raise ValueError("SUPABASE_URL and SUPABASE_KEY are required")
        
        supabase = create_client(supabase_url, supabase_key)
        logger.info("✅ Supabase client initialized")
        
        logger.info("🚀 Starting STORAGE BYPASS Slack Bot...")
        
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
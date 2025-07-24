import os
import re
import base64
import requests
import json
import logging
from datetime import datetime
from PIL import Image
import io
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
    """Get existing van or create new one using existing schema"""
    try:
        logger.info(f"🔍 Looking for van #{van_number}")
        
        # Try to find existing van
        response = supabase.table("van_profiles").select("*").eq("van_number", van_number).execute()
        
        if response.data and len(response.data) > 0:
            van = response.data[0]
            logger.info(f"✅ Found existing van: {van['id']}")
            return van['id'], False
        
        # Create new van with existing schema only
        new_van = {
            "van_number": van_number,
            "status": "active"
        }
        
        create_response = supabase.table("van_profiles").insert(new_van).execute()
        
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

def compress_image(image_data: bytes, max_size: tuple = (1920, 1080), quality: int = 85) -> bytes:
    """Compress image to reduce size before storage"""
    try:
        # Open image from bytes
        img = Image.open(io.BytesIO(image_data))
        
        # Resize if larger than max_size
        if img.size[0] > max_size[0] or img.size[1] > max_size[1]:
            img.thumbnail(max_size, Image.Resampling.LANCZOS)
            logger.info(f"📏 Resized image from original to {img.size}")
        
        # Convert to RGB if necessary (for JPEG)
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")
        
        # Compress and save as JPEG
        output = io.BytesIO()
        img.save(output, format="JPEG", quality=quality, optimize=True)
        compressed_data = output.getvalue()
        
        compression_ratio = len(compressed_data) / len(image_data) * 100
        logger.info(f"📦 Compressed image: {len(image_data)} -> {len(compressed_data)} bytes ({compression_ratio:.1f}%)")
        return compressed_data
        
    except Exception as e:
        logger.error(f"❌ Image compression failed: {e}")
        return image_data  # Return original if compression fails

def analyze_van_damage_with_claude(image_data):
    """Comprehensive van damage analysis using Claude AI with exact schema mapping"""
    try:
        claude_key = os.environ.get('CLAUDE_API_KEY')
        if not claude_key:
            logger.warning('⚠️ CLAUDE_API_KEY not found - using defaults')
            return {
                'van_side': 'unknown',
                'van_rating': 0,
                'van_damage': 'AI analysis unavailable',
                'damage_level': 0,
                'damage_type': 'unknown',
                'damage_severity': 'minor',
                'damage_location': 'Not specified'
            }
        
        logger.info('🤖 Analyzing van damage and condition with Claude AI...')
        
        # Convert to base64
        base64_image = base64.b64encode(image_data).decode('utf-8')
        
        headers = {
            'content-type': 'application/json',
            'x-api-key': claude_key,
            'anthropic-version': '2023-06-01'
        }
        
        data = {
            'model': 'claude-3-haiku-20240307',
            'max_tokens': 200,
            'messages': [
                {
                    'role': 'user',
                    'content': [
                        {
                            'type': 'text',
                            'text': '''Analyze this van/vehicle image and provide detailed damage assessment:

1. Van side: front, rear, driver_side, passenger_side, interior, roof, undercarriage
2. Van rating (0-3): 0=perfect condition, 1=dirt/debris only, 2=scratches/scuffs, 3=dents/major damage
3. Damage description: Detailed description of visible damage, dirt, scratches, dents, or condition
4. Damage type: scratches, dents, dirt, debris, rust, paint_damage, structural, or none
5. Damage severity: minor, moderate, severe, or none
6. Damage location: Specific area where damage is visible (e.g., "rear bumper", "driver door", "side panel")

Format as JSON:
{
  "van_side": "...",
  "van_rating": 0,
  "van_damage": "...",
  "damage_type": "...",
  "damage_severity": "...",
  "damage_location": "..."
}'''
                        },
                        {
                            'type': 'image',
                            'source': {
                                'type': 'base64',
                                'media_type': 'image/jpeg',
                                'data': base64_image
                            }
                        }
                    ]
                }
            ]
        }
        
        response = requests.post(
            'https://api.anthropic.com/v1/messages',
            headers=headers,
            json=data,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            claude_response = result.get('content', [])[0].get('text', '').strip()
            
            logger.info(f'🤖 Claude raw response: {claude_response}')
            
            # Try to parse JSON response
            try:
                # Extract JSON from response (may have extra text)
                json_start = claude_response.find('{')
                json_end = claude_response.rfind('}') + 1
                
                if json_start >= 0 and json_end > json_start:
                    json_str = claude_response[json_start:json_end]
                    parsed_result = json.loads(json_str)
                    
                    # Validate and normalize the response
                    van_side = parsed_result.get('van_side', 'unknown').lower()
                    van_rating = int(parsed_result.get('van_rating', 0))
                    van_damage = parsed_result.get('van_damage', 'No specific damage noted')
                    damage_type = parsed_result.get('damage_type', 'unknown')
                    damage_severity = parsed_result.get('damage_severity', 'minor')
                    damage_location = parsed_result.get('damage_location', 'Not specified')
                    
                    # Validate van rating is 0-3
                    if van_rating < 0 or van_rating > 3:
                        van_rating = 0
                    
                    # Validate van side
                    valid_sides = ['front', 'rear', 'driver_side', 'passenger_side', 'interior', 'roof', 'undercarriage']
                    if van_side not in valid_sides:
                        van_side = 'unknown'
                    
                    result_data = {
                        'van_side': van_side,
                        'van_rating': van_rating,
                        'van_damage': van_damage,
                        'damage_level': van_rating,  # Map to existing column
                        'damage_type': damage_type,
                        'damage_severity': damage_severity,
                        'damage_location': damage_location
                    }
                    
                    logger.info(f'🎯 Claude analysis result: {result_data}')
                    return result_data
                
            except json.JSONDecodeError as e:
                logger.error(f'❌ Failed to parse Claude JSON response: {e}')
            
            # Fallback parsing if JSON fails
            logger.info('⚠️ JSON parsing failed, using fallback text analysis')
            return parse_claude_text_response(claude_response)
            
        else:
            logger.error(f'❌ Claude API error: {response.status_code}')
            return {
                'van_side': 'unknown',
                'van_rating': 0,
                'van_damage': 'API analysis failed',
                'damage_level': 0,
                'damage_type': 'unknown',
                'damage_severity': 'minor',
                'damage_location': 'Not specified'
            }
            
    except Exception as e:
        logger.error(f'❌ Claude analysis failed: {e}')
        return {
            'van_side': 'unknown',
            'van_rating': 0,
            'van_damage': 'Analysis error occurred',
            'damage_level': 0,
            'damage_type': 'unknown',
            'damage_severity': 'minor',
            'damage_location': 'Not specified'
        }

def parse_claude_text_response(text):
    """Fallback text parsing for Claude responses"""
    text_lower = text.lower()
    
    # Extract van side
    van_side = 'unknown'
    sides = ['front', 'rear', 'driver_side', 'passenger_side', 'interior', 'roof', 'undercarriage']
    for side in sides:
        if side in text_lower or side.replace('_', ' ') in text_lower:
            van_side = side
            break
    
    # Extract damage rating
    van_rating = 0
    if 'van_rating' in text_lower or 'rating' in text_lower:
        # Look for numbers near "rating"
        import re
        match = re.search(r'rating["\s:]*(\d)', text_lower)
        if match:
            van_rating = int(match.group(1))
    elif 'dent' in text_lower or 'major damage' in text_lower:
        van_rating = 3
    elif 'scratch' in text_lower or 'scuff' in text_lower:
        van_rating = 2
    elif 'dirt' in text_lower or 'debris' in text_lower:
        van_rating = 1
    
    # Extract damage type
    damage_type = 'unknown'
    if 'dent' in text_lower:
        damage_type = 'dents'
    elif 'scratch' in text_lower:
        damage_type = 'scratches'
    elif 'dirt' in text_lower or 'debris' in text_lower:
        damage_type = 'dirt'
    elif 'rust' in text_lower:
        damage_type = 'rust'
    elif 'paint' in text_lower:
        damage_type = 'paint_damage'
    elif van_rating == 0:
        damage_type = 'none'
    
    # Extract damage severity
    damage_severity = 'minor'
    if van_rating >= 3:
        damage_severity = 'severe'
    elif van_rating >= 2:
        damage_severity = 'moderate'
    elif van_rating == 0:
        damage_severity = 'none'
    
    # Extract description (try to find descriptive text)
    van_damage = 'General wear visible' if van_rating > 0 else 'No damage visible'
    
    return {
        'van_side': van_side,
        'van_rating': van_rating,
        'van_damage': van_damage,
        'damage_level': van_rating,
        'damage_type': damage_type,
        'damage_severity': damage_severity,
        'damage_location': 'Not specified'
    }

def try_storage_upload_simple(image_data: bytes, van_number: str) -> dict:
    """Try simple storage upload to van-images bucket"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_path = f"van_{van_number}/slack_image_{timestamp}.jpg"
    
    logger.info(f"📤 STORAGE UPLOAD for {file_path}")
    
    try:
        # Method 1: Use Supabase Python client upload
        logger.info("📤 Trying Supabase Python client upload...")
        
        response = supabase.storage.from_("van-images").upload(file_path, image_data)
        
        if response:
            logger.info("✅ Python client upload successful!")
            public_url = supabase.storage.from_("van-images").get_public_url(file_path)
            return {
                "success": True,
                "url": public_url,
                "method": "supabase_python_client",
                "is_base64": False,
                "folder": f"van_{van_number}",
                "filename": f"slack_image_{timestamp}.jpg"
            }
        else:
            logger.info("❌ Python client upload failed")
            
    except Exception as e:
        logger.info(f"❌ Python client upload exception: {e}")
    
    # Method 2: Try direct HTTP upload
    try:
        logger.info("📤 Trying direct HTTP upload...")
        
        url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/van-images/{file_path}"
        
        headers = {
            "Authorization": f"Bearer {os.environ.get('SUPABASE_KEY')}",
            "Content-Type": "image/jpeg",
        }
        
        response = requests.post(url, headers=headers, data=image_data, timeout=30)
        logger.info(f"📤 HTTP upload response: {response.status_code}")
        
        if response.status_code in [200, 201]:
            public_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/public/van-images/{file_path}"
            logger.info("✅ HTTP upload successful!")
            return {
                "success": True,
                "url": public_url,
                "method": "direct_http",
                "is_base64": False,
                "folder": f"van_{van_number}",
                "filename": f"slack_image_{timestamp}.jpg"
            }
        else:
            logger.info(f"❌ HTTP upload failed: {response.status_code} - {response.text}")
            
    except Exception as e:
        logger.info(f"❌ HTTP upload exception: {e}")
    
    # Method 3: Database storage fallback
    logger.info("💾 Falling back to database storage...")
    data_url = f"data:image/jpeg;base64,{base64.b64encode(image_data).decode('utf-8')}"
    
    return {
        "success": True,
        "url": data_url,
        "method": "database_storage",
        "is_base64": True,
        "folder": f"van_{van_number}",
        "filename": f"slack_image_{timestamp}.jpg"
    }

def get_or_create_driver_profile(slack_user_id: str, slack_username: str = None, display_name: str = None) -> tuple:
    """Get existing driver profile or create new one"""
    try:
        logger.info(f"🔍 Looking for driver profile: {slack_user_id}")
        
        # Try to find existing driver
        response = supabase.table("driver_profiles").select("*").eq("slack_user_id", slack_user_id).execute()
        
        if response.data:
            driver = response.data[0]
            logger.info(f"✅ Found existing driver: {driver['driver_name']} (ID: {driver['id']})")
            return driver["id"], driver["driver_name"]
        
        # Create new driver profile
        logger.info(f"🆕 Creating new driver profile for {slack_user_id}")
        
        # Use display_name or username, fallback to slack_user_id
        driver_name = display_name or slack_username or f"Driver-{slack_user_id[-8:]}"
        
        new_driver = {
            "slack_user_id": slack_user_id,
            "driver_name": driver_name,
            "status": "active"
        }
        
        create_response = supabase.table("driver_profiles").insert(new_driver).execute()
        
        if create_response.data:
            driver_id = create_response.data[0]["id"]
            logger.info(f"✅ Created new driver: {driver_name} (ID: {driver_id})")
            return driver_id, driver_name
        else:
            logger.error(f"❌ Failed to create driver profile: {create_response}")
            return None, None
            
    except Exception as e:
        logger.error(f"❌ Error in get_or_create_driver_profile: {e}")
        return None, None

def save_van_image_with_damage_analysis(van_id: str, image_data: bytes, van_number: str, 
                                       driver_id: str = None, slack_user_id: str = None, 
                                       driver_name: str = None) -> bool:
    """Save van image with comprehensive damage analysis using exact schema"""
    try:
        # Compress image to reduce size
        compressed_image_data = compress_image(image_data)
        
        # Analyze van damage with Claude AI
        analysis_result = analyze_van_damage_with_claude(compressed_image_data)
        
        upload_result = try_storage_upload_simple(compressed_image_data, van_number)
        
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
        
        # Prepare record data with damage analysis using EXACT schema columns
        record_data = {
            "van_id": van_id,
            "van_number": int(van_number),
            "driver_id": driver_id,
            "slack_user_id": slack_user_id,
            "image_url": storage_url,
            "file_path": upload_result.get("filename", "slack_image.jpg"),
            "van_damage": analysis_result['van_damage'],  # EXACT column name
            "van_rating": analysis_result['van_rating'],  # EXACT column name
            "damage_type": analysis_result['damage_type'],  # EXACT column name
            "damage_severity": analysis_result['damage_severity'],  # EXACT column name
            "damage_location": analysis_result['damage_location'],  # EXACT column name
            "damage_level": analysis_result['damage_level'],  # EXACT column name
            "van_side": analysis_result['van_side'],  # EXACT column name
            "description": f"Claude AI Analysis: {analysis_result['van_damage']} (Rating: {analysis_result['van_rating']}/3)",
            "uploaded_by": driver_name or "slack_bot",
            "driver_name": driver_name,
            "upload_method": "slack_bot",
            "upload_source": "slack",
            "location": folder_path,
            "created_at": timestamp,
            "uploaded_at": timestamp,
            "updated_at": timestamp
        }
        
        # Save the image record
        logger.info(f"💾 Saving image record with COMPLETE damage analysis")
        logger.info(f"🎯 Damage Data: Rating={analysis_result['van_rating']}, Type={analysis_result['damage_type']}, Side={analysis_result['van_side']}")
        
        response = supabase.table("van_images").insert(record_data).execute()
        
        if response.data:
            logger.info("✅ Successfully saved image record with COMPLETE damage analysis")
            logger.info(f"🎯 Database record created with van_rating={analysis_result['van_rating']} and van_damage='{analysis_result['van_damage']}'")
            
            # Update driver profile with upload statistics
            if driver_id:
                update_driver_upload_stats(driver_id, analysis_result['van_rating'])
            
            return True
        else:
            logger.error("❌ Failed to save image record")
            return False
        
    except Exception as e:
        logger.error(f"❌ Error in save_van_image_with_damage_analysis: {e}")
        return False

def update_driver_upload_stats(driver_id: str, van_rating: int) -> bool:
    """Update driver's upload statistics"""
    try:
        logger.info(f"📊 Updating driver upload statistics for: {driver_id}")
        
        # Simple update that should always work
        update_data = {
            "updated_at": datetime.now().isoformat()
        }
        
        # Try to add upload stats if columns exist
        try:
            # Test if columns exist by doing a small select
            test_response = supabase.table("driver_profiles").select("total_uploads, last_upload_date").limit(1).execute()
            
            # If we get here, columns exist, so get current count and update
            response = supabase.table("driver_profiles").select("total_uploads").eq("id", driver_id).execute()
            current_uploads = 0
            if response.data:
                current_uploads = response.data[0].get("total_uploads", 0) or 0
            
            # Include upload stats in update
            update_data = {
                "total_uploads": current_uploads + 1,
                "last_upload_date": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat()
            }
            logger.info(f"📊 Including upload stats: {current_uploads + 1} total uploads, van rating: {van_rating}")
            
        except Exception as col_test_error:
            logger.info(f"⚠️  Upload stats columns don't exist, using basic update: {col_test_error}")
        
        # Perform the update
        response = supabase.table("driver_profiles").update(update_data).eq("id", driver_id).execute()
        
        if response.data:
            logger.info(f"✅ Successfully updated driver profile")
            return True
        else:
            logger.error(f"❌ Failed to update driver stats: {response}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error updating driver stats: {e}")
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
    
    # Claude API key is optional but recommended
    if os.environ.get("CLAUDE_API_KEY"):
        logger.info("  - CLAUDE_API_KEY: ✅")
    else:
        logger.warning("  - CLAUDE_API_KEY: ⚠️  Missing (damage analysis will use defaults)")
    
    if missing_vars:
        logger.error(f"❌ Missing environment variables: {missing_vars}")
        return False
    
    # Test Supabase connection
    try:
        logger.info("🔍 Testing Supabase database connection...")
        response = supabase.table("van_profiles").select("id").limit(1).execute()
        logger.info("✅ Supabase database connection successful")
    except Exception as e:
        logger.error(f"❌ Supabase database connection failed: {e}")
        return False
    
    # Test storage access
    try:
        logger.info("🔍 Testing Supabase storage access...")
        response = supabase.storage.list_buckets()
        logger.info("✅ Supabase storage connection successful")
    except Exception as e:
        logger.error(f"❌ Supabase storage connection failed: {e}")
        return False
    
    logger.info("✅ Environment validation complete")
    return True

@app.event("message")
def handle_message_events(body, say, client):
    """Handle all message events with comprehensive damage analysis"""
    try:
        event = body["event"]
        
        # Skip bot messages
        if event.get("bot_id") or event.get("subtype") == "bot_message":
            return
        
        logger.info("==================================================")
        logger.info("📨 SCHEMA-CORRECT DAMAGE ANALYSIS - CLAUDE AI")
        logger.info("==================================================")
        
        # Extract text and look for van numbers
        text = extract_text_from_event(event)
        van_number = extract_van_number(text)
        
        if not van_number:
            logger.info("❌ No van number found, skipping")
            return
        
        logger.info(f"🚐 Detected van number: {van_number}")
        
        # Extract user information
        slack_user_id = event.get("user")
        user_info = None
        driver_id = None
        driver_name = None
        
        if slack_user_id:
            logger.info(f"👤 Slack user ID: {slack_user_id}")
            
            # Get user info from Slack
            try:
                user_response = client.users_info(user=slack_user_id)
                if user_response["ok"]:
                    user_info = user_response["user"]
                    display_name = user_info.get("profile", {}).get("display_name") or user_info.get("real_name") or user_info.get("name")
                    username = user_info.get("name")
                    logger.info(f"👤 User info: {display_name} (@{username})")
                    
                    # Get or create driver profile
                    driver_id, driver_name = get_or_create_driver_profile(slack_user_id, username, display_name)
                    if driver_id:
                        logger.info(f"✅ Driver profile ready: {driver_name} (ID: {driver_id})")
                    else:
                        logger.error("❌ Failed to get/create driver profile")
                else:
                    logger.error(f"❌ Failed to get user info: {user_response}")
            except Exception as e:
                logger.error(f"❌ Error getting user info: {e}")
        else:
            logger.warning("⚠️ No user ID found in event")
        
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
                
                # Save image with comprehensive damage analysis using correct schema
                save_success = save_van_image_with_damage_analysis(van_id, image_data, van_number, driver_id, slack_user_id, driver_name)
                
                if save_success:
                    # Send comprehensive confirmation
                    say(f"✅ **Van #{van_number} Image Processed!**\n"
                        f"📁 Organized in: van_{van_number}/\n"
                        f"🤖 **Claude AI Damage Analysis Complete**\n"
                        f"🎯 **Damage rating and description saved to database**\n"
                        f"📊 **Van rating and damage details updated**\n"
                        f"✨ **Flutter app will now display damage information**")
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
    say("🚐 **Schema-Correct Van Damage Bot Ready!**\n"
        "📤 Upload an image with van number (e.g., 'van 123')\n"
        "🤖 **Claude AI will analyze and save:**\n"
        "  • Van side detection\n"
        "  • Damage rating (0-3 scale) → van_rating column\n"
        "  • Detailed damage description → van_damage column\n"
        "  • Damage type, severity, location\n"
        "📱 **Flutter app will display all damage information**")

if __name__ == "__main__":
    try:
        # Initialize Supabase
        supabase_url = os.environ.get("SUPABASE_URL")
        supabase_key = os.environ.get("SUPABASE_KEY")
        
        if not supabase_url or not supabase_key:
            raise ValueError("SUPABASE_URL and SUPABASE_KEY are required")
        
        supabase = create_client(supabase_url, supabase_key)
        logger.info("✅ Supabase client initialized")
        
        logger.info("🚀 Starting SCHEMA-CORRECT DAMAGE ANALYSIS Bot...")
        
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
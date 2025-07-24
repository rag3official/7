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
    """Get existing van or create new one"""
    try:
        logger.info(f"🔍 Looking for van #{van_number}")
        
        # Try to find existing van
        response = supabase.table("van_profiles").select("*").eq("van_number", van_number).execute()
        
        if response.data and len(response.data) > 0:
            van = response.data[0]
            logger.info(f"✅ Found existing van: {van['id']}")
            return van['id'], False
        
        # Create new van
        new_van = {
            "van_number": van_number,
            "status": "active",
            "damage_level": 0,
            "damage_description": "No damage reported",
            "overall_condition": "excellent"
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
    """Comprehensive van damage analysis using Claude AI"""
    try:
        claude_key = os.environ.get('CLAUDE_API_KEY')
        if not claude_key:
            logger.warning('⚠️ CLAUDE_API_KEY not found - using defaults')
            return {
                'van_side': 'unknown',
                'damage_level': 0,
                'damage_description': 'AI analysis unavailable',
                'condition_rating': 'unknown'
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
            'max_tokens': 150,
            'messages': [
                {
                    'role': 'user',
                    'content': [
                        {
                            'type': 'text',
                            'text': '''Analyze this van/vehicle image and provide:
1. Van side (front, rear, driver_side, passenger_side, interior, roof, undercarriage)
2. Damage level (0=no damage, 1=dirt/debris, 2=scratches/scuffs, 3=dents/major damage)
3. Damage description (brief description of any visible damage, dirt, scratches, or dents)
4. Overall condition (excellent, good, fair, poor)

Format your response as JSON:
{
  "van_side": "...",
  "damage_level": 0,
  "damage_description": "...",
  "condition_rating": "..."
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
                    damage_level = int(parsed_result.get('damage_level', 0))
                    damage_description = parsed_result.get('damage_description', 'No specific damage noted')
                    condition_rating = parsed_result.get('condition_rating', 'unknown').lower()
                    
                    # Validate damage level is 0-3
                    if damage_level < 0 or damage_level > 3:
                        damage_level = 0
                    
                    # Validate van side
                    valid_sides = ['front', 'rear', 'driver_side', 'passenger_side', 'interior', 'roof', 'undercarriage']
                    if van_side not in valid_sides:
                        van_side = 'unknown'
                    
                    # Validate condition rating
                    valid_conditions = ['excellent', 'good', 'fair', 'poor']
                    if condition_rating not in valid_conditions:
                        condition_rating = 'unknown'
                    
                    result_data = {
                        'van_side': van_side,
                        'damage_level': damage_level,
                        'damage_description': damage_description,
                        'condition_rating': condition_rating
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
                'damage_level': 0,
                'damage_description': 'API analysis failed',
                'condition_rating': 'unknown'
            }
            
    except Exception as e:
        logger.error(f'❌ Claude analysis failed: {e}')
        return {
            'van_side': 'unknown',
            'damage_level': 0,
            'damage_description': 'Analysis error occurred',
            'condition_rating': 'unknown'
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
    
    # Extract damage level
    damage_level = 0
    if 'damage_level' in text_lower:
        # Look for numbers near "damage_level"
        import re
        match = re.search(r'damage_level["\s:]*(\d)', text_lower)
        if match:
            damage_level = int(match.group(1))
    elif 'dent' in text_lower or 'major damage' in text_lower:
        damage_level = 3
    elif 'scratch' in text_lower or 'scuff' in text_lower:
        damage_level = 2
    elif 'dirt' in text_lower or 'debris' in text_lower:
        damage_level = 1
    
    # Extract condition
    condition_rating = 'unknown'
    conditions = ['excellent', 'good', 'fair', 'poor']
    for condition in conditions:
        if condition in text_lower:
            condition_rating = condition
            break
    
    # Extract description (try to find descriptive text)
    damage_description = 'General wear visible' if damage_level > 0 else 'No damage visible'
    
    return {
        'van_side': van_side,
        'damage_level': damage_level,
        'damage_description': damage_description,
        'condition_rating': condition_rating
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
            "status": "active",
            "damage_reports_count": 0,
            "avg_damage_level": 0.0
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
    """Save van image with comprehensive damage analysis"""
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
        
        # Prepare record data with damage analysis
        record_data = {
            "van_id": van_id,
            "van_number": int(van_number),
            "image_url": storage_url,
            "driver_id": driver_id,
            "slack_user_id": slack_user_id,
            "uploaded_by": driver_name or "slack_bot",
            "damage_level": analysis_result['damage_level'],
            "van_side": analysis_result['van_side'],
            "description": analysis_result['damage_description'],
            "condition_rating": analysis_result['condition_rating'],
            "created_at": timestamp,
            "location": folder_path,
            "file_path": upload_result.get("filename", "slack_image.jpg"),
        }
        
        # Save the image record
        logger.info(f"💾 Saving image record with damage analysis")
        response = supabase.table("van_images").insert(record_data).execute()
        
        if response.data:
            logger.info("✅ Successfully saved image record with damage analysis")
            
            # Update van profile with damage information
            update_van_damage_profile(van_id, analysis_result)
            
            # Update driver profile with damage statistics
            if driver_id:
                update_driver_damage_stats(driver_id, analysis_result['damage_level'])
            
            return True
        else:
            logger.error("❌ Failed to save image record")
            return False
        
    except Exception as e:
        logger.error(f"❌ Error in save_van_image_with_damage_analysis: {e}")
        return False

def update_van_damage_profile(van_id: str, analysis_result: dict) -> bool:
    """Update van profile with latest damage information"""
    try:
        logger.info("🔄 Updating van damage profile...")
        
        # Get current van data to calculate cumulative damage
        current_van = supabase.table("van_profiles").select("damage_level, notes").eq("id", van_id).execute()
        
        current_damage_level = 0
        if current_van.data:
            current_damage_level = current_van.data[0].get("damage_level", 0) or 0
        
        # Use the higher damage level between current and new
        new_damage_level = max(current_damage_level, analysis_result['damage_level'])
        
        # Determine overall condition based on damage level
        condition_map = {
            0: "excellent",
            1: "good", 
            2: "fair",
            3: "poor"
        }
        overall_condition = condition_map.get(new_damage_level, "unknown")
        
        # Prepare update data
        update_data = {
            "damage_level": new_damage_level,
            "damage_description": analysis_result['damage_description'],
            "overall_condition": overall_condition,
            "notes": f"Latest damage assessment: {analysis_result['damage_description']} (Level {new_damage_level})",
            "updated_at": datetime.now().isoformat()
        }
        
        # Update the van
        logger.info(f"💾 Updating van with damage level {new_damage_level}")
        response = supabase.table("van_profiles").update(update_data).eq("id", van_id).execute()
        
        if response.data:
            logger.info(f"✅ Successfully updated van damage profile - Level {new_damage_level}")
            return True
        else:
            logger.error("❌ Failed to update van damage profile")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error in update_van_damage_profile: {e}")
        return False

def update_driver_damage_stats(driver_id: str, damage_level: int) -> bool:
    """Update driver's damage statistics"""
    try:
        logger.info(f"📊 Updating driver damage statistics for: {driver_id}")
        
        # Get current driver stats
        response = supabase.table("driver_profiles").select("damage_reports_count, avg_damage_level, total_uploads").eq("id", driver_id).execute()
        
        current_reports = 0
        current_avg = 0.0
        current_uploads = 0
        
        if response.data:
            current_reports = response.data[0].get("damage_reports_count", 0) or 0
            current_avg = float(response.data[0].get("avg_damage_level", 0.0) or 0.0)
            current_uploads = response.data[0].get("total_uploads", 0) or 0
        
        # Calculate new statistics
        new_reports = current_reports + 1
        new_uploads = current_uploads + 1
        new_avg = ((current_avg * current_reports) + damage_level) / new_reports
        
        # Prepare update data
        update_data = {
            "damage_reports_count": new_reports,
            "avg_damage_level": round(new_avg, 2),
            "total_uploads": new_uploads,
            "last_upload_date": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        
        # Update the driver
        response = supabase.table("driver_profiles").update(update_data).eq("id", driver_id).execute()
        
        if response.data:
            logger.info(f"✅ Updated driver stats - Reports: {new_reports}, Avg Damage: {new_avg:.2f}")
            return True
        else:
            logger.error("❌ Failed to update driver damage stats")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error updating driver damage stats: {e}")
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
        logger.info("📨 DAMAGE ANALYSIS MESSAGE HANDLER - CLAUDE AI")
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
                
                # Save image with comprehensive damage analysis
                save_success = save_van_image_with_damage_analysis(van_id, image_data, van_number, driver_id, slack_user_id, driver_name)
                
                if save_success:
                    # Send comprehensive confirmation
                    say(f"✅ **Van #{van_number} Image Processed!**\n"
                        f"📁 Organized in: van_{van_number}/\n"
                        f"🤖 **Claude AI Damage Analysis Complete**\n"
                        f"🎯 **Full damage assessment saved to database**\n"
                        f"📊 **Van & Driver profiles updated**")
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
    say("🚐 **Enhanced Van Damage Bot Ready!**\n"
        "📤 Upload an image with van number (e.g., 'van 123')\n"
        "🤖 **Claude AI will analyze:**\n"
        "  • Van side detection\n"
        "  • Damage level (0-3 scale)\n"
        "  • Detailed damage description\n"
        "  • Overall condition rating\n"
        "📊 **Updates all profiles automatically**")

if __name__ == "__main__":
    try:
        # Initialize Supabase
        supabase_url = os.environ.get("SUPABASE_URL")
        supabase_key = os.environ.get("SUPABASE_KEY")
        
        if not supabase_url or not supabase_key:
            raise ValueError("SUPABASE_URL and SUPABASE_KEY are required")
        
        supabase = create_client(supabase_url, supabase_key)
        logger.info("✅ Supabase client initialized")
        
        logger.info("🚀 Starting ENHANCED DAMAGE ANALYSIS Slack Bot...")
        
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
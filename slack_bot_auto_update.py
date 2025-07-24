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

def get_current_slack_user_info(client, slack_user_id: str) -> dict:
    """Get current user information from Slack API"""
    try:
        user_response = client.users_info(user=slack_user_id)
        if user_response["ok"]:
            user_info = user_response["user"]
            profile = user_info.get("profile", {})
            
            # Priority order for driver name:
            # 1. display_name (preferred by user)
            # 2. real_name (official name)
            # 3. name (username)
            current_display_name = profile.get("display_name") or user_info.get("real_name") or user_info.get("name")
            current_username = user_info.get("name")
            current_email = profile.get("email")
            
            return {
                "display_name": current_display_name,
                "username": current_username,
                "email": current_email,
                "slack_real_name": user_info.get("real_name"),
                "slack_display_name": profile.get("display_name"),
                "slack_username": user_info.get("name")
            }
        else:
            logger.error(f"❌ Failed to get user info: {user_response}")
            return None
    except Exception as e:
        logger.error(f"❌ Error getting Slack user info: {e}")
        return None

def check_and_update_driver_name(driver_data: dict, current_slack_info: dict) -> bool:
    """Check if driver name needs updating and update if changed"""
    try:
        driver_id = driver_data["id"]
        current_driver_name = driver_data.get("driver_name", "")
        current_slack_name = current_slack_info.get("display_name", "")
        
        # Check if names are different (case-insensitive comparison)
        if current_driver_name.lower().strip() != current_slack_name.lower().strip():
            logger.info(f"🔄 Name change detected for driver {driver_id}")
            logger.info(f"   Old name: '{current_driver_name}'")
            logger.info(f"   New name: '{current_slack_name}'")
            
            # Update driver profile with new name and additional Slack info
            update_data = {
                "driver_name": current_slack_name,
                "slack_real_name": current_slack_info.get("slack_real_name"),
                "slack_display_name": current_slack_info.get("slack_display_name"),
                "slack_username": current_slack_info.get("slack_username"),
                "updated_at": datetime.now().isoformat()
            }
            
            # Only update email if we have one and it's different
            if current_slack_info.get("email"):
                current_email = driver_data.get("email", "")
                new_email = current_slack_info.get("email", "")
                if current_email != new_email:
                    update_data["email"] = new_email
                    logger.info(f"   Email also updated: '{current_email}' → '{new_email}'")
            
            response = supabase.table("driver_profiles").update(update_data).eq("id", driver_id).execute()
            
            if response.data:
                logger.info(f"✅ Successfully updated driver name: '{current_driver_name}' → '{current_slack_name}'")
                
                # Also update any van_images records with the old driver_name
                update_images_response = supabase.table("van_images").update({
                    "driver_name": current_slack_name,
                    "updated_at": datetime.now().isoformat()
                }).eq("driver_id", driver_id).execute()
                
                if update_images_response.data:
                    logger.info(f"✅ Updated {len(update_images_response.data)} van image records with new driver name")
                
                return True
            else:
                logger.error(f"❌ Failed to update driver name in database")
                return False
        else:
            logger.info(f"✅ Driver name unchanged: '{current_driver_name}'")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error checking/updating driver name: {e}")
        return False

def get_or_create_driver_profile(slack_user_id: str, client, force_update: bool = False) -> tuple:
    """Get existing driver profile or create new one, with auto-update for name changes"""
    try:
        logger.info(f"🔍 Looking for driver profile: {slack_user_id}")
        
        # Get current Slack user information
        current_slack_info = get_current_slack_user_info(client, slack_user_id)
        if not current_slack_info:
            logger.error("❌ Failed to get current Slack user info")
            return None, None
        
        # Try to find existing driver
        response = supabase.table("driver_profiles").select("*").eq("slack_user_id", slack_user_id).execute()
        
        if response.data:
            driver = response.data[0]
            logger.info(f"✅ Found existing driver: {driver['driver_name']} (ID: {driver['id']})")
            
            # Check for name changes and update if necessary
            name_updated = check_and_update_driver_name(driver, current_slack_info)
            
            # Return updated name if changed
            final_driver_name = current_slack_info["display_name"] if name_updated else driver["driver_name"]
            return driver["id"], final_driver_name
        
        # Create new driver profile
        logger.info(f"🆕 Creating new driver profile for {slack_user_id}")
        
        # Use display_name from current Slack info
        driver_name = current_slack_info["display_name"] or f"Driver-{slack_user_id[-8:]}"
        
        new_driver = {
            "slack_user_id": slack_user_id,
            "driver_name": driver_name,
            "email": current_slack_info.get("email"),
            "slack_real_name": current_slack_info.get("slack_real_name"),
            "slack_display_name": current_slack_info.get("slack_display_name"),
            "slack_username": current_slack_info.get("slack_username"),
            "status": "active",
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
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
            "status": "active",
            "make": "Enterprise",
            "model": "Rental Van - No Damage Reported"
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
    """Comprehensive van damage analysis using Claude AI with improved van side detection"""
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
                            'text': '''Analyze this van/vehicle image and provide detailed damage assessment.

CRITICAL: Choose EXACTLY ONE van side from the perspective of someone standing outside the vehicle:
- "front" = headlights, grille, front bumper visible
- "rear" = taillights, rear bumper, back doors visible  
- "driver_side" = left side (where driver sits), driver door visible
- "passenger_side" = right side (opposite driver), passenger door visible
- "interior" = inside cabin view
- "roof" = top/overhead view
- "undercarriage" = bottom/underneath view

Assessment needed:
1. Van side: Pick EXACTLY ONE from the list above
2. Van rating (0-3): 0=perfect, 1=dirt/debris, 2=scratches/scuffs, 3=dents/major damage
3. Damage description: Detailed description of visible damage
4. Damage type: scratches, dents, dirt, debris, rust, paint_damage, structural, or none
5. Damage severity: minor, moderate, severe, or none
6. Damage location: Specific area (e.g., "rear bumper", "driver door")

Respond in JSON format:
{
  "van_side": "driver_side",
  "van_rating": 2,
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
                    van_side = parsed_result.get('van_side', 'unknown').lower().strip()
                    van_rating = int(parsed_result.get('van_rating', 0))
                    van_damage = parsed_result.get('van_damage', 'No specific damage noted')
                    damage_type = parsed_result.get('damage_type', 'unknown')
                    damage_severity = parsed_result.get('damage_severity', 'minor')
                    damage_location = parsed_result.get('damage_location', 'Not specified')
                    
                    # Validate van rating is 0-3
                    if van_rating < 0 or van_rating > 3:
                        van_rating = 0
                    
                    # IMPROVED van side validation with fallback logic
                    valid_sides = ['front', 'rear', 'driver_side', 'passenger_side', 'interior', 'roof', 'undercarriage']
                    
                    # Handle comma-separated responses or multi-word responses
                    if van_side not in valid_sides:
                        logger.warning(f'⚠️ Invalid van_side: "{van_side}", attempting to fix...')
                        
                        # Try to extract a valid side from the response
                        for side in valid_sides:
                            if side in van_side or side.replace('_', ' ') in van_side:
                                van_side = side
                                logger.info(f'🔧 Fixed van_side to: {van_side}')
                                break
                        
                        # If still invalid, use image analysis logic as fallback
                        if van_side not in valid_sides:
                            logger.warning(f'⚠️ Could not fix van_side, using fallback analysis')
                            van_side = analyze_van_side_from_image_content(van_damage, damage_location)
                    
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

def analyze_van_side_from_image_content(damage_description, damage_location):
    """Fallback logic to determine van side from damage description"""
    text = f"{damage_description} {damage_location}".lower()
    
    # Look for side indicators in the damage description
    if 'driver' in text and 'door' in text:
        return 'driver_side'
    elif 'passenger' in text and 'door' in text:
        return 'passenger_side'
    elif 'side panel' in text or 'side door' in text:
        # Default to driver_side for generic side mentions
        return 'driver_side'
    elif 'front' in text or 'headlight' in text or 'grille' in text:
        return 'front'
    elif 'rear' in text or 'back' in text or 'taillight' in text:
        return 'rear'
    elif 'roof' in text or 'top' in text:
        return 'roof'
    elif 'undercarriage' in text or 'underneath' in text or 'wheel well' in text:
        return 'undercarriage'
    elif 'interior' in text or 'inside' in text or 'cabin' in text:
        return 'interior'
    
    return 'driver_side'  # Default to driver_side as most common

def parse_claude_text_response(text):
    """Fallback text parsing for Claude responses with improved van side detection"""
    text_lower = text.lower()
    
    # Extract van side with improved logic
    van_side = 'unknown'
    sides = ['front', 'rear', 'driver_side', 'passenger_side', 'interior', 'roof', 'undercarriage']
    
    # First try exact matches
    for side in sides:
        if f'"{side}"' in text_lower or f"'{side}'" in text_lower:
            van_side = side
            break
    
    # If no exact match, try partial matches
    if van_side == 'unknown':
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
        logger.info(f"🎯 Damage Data: Rating={analysis_result['van_rating']}, Side={analysis_result['van_side']}, Type={analysis_result['damage_type']}")
        
        response = supabase.table("van_images").insert(record_data).execute()
        
        if response.data:
            logger.info("✅ Successfully saved image record with COMPLETE damage analysis")
            logger.info(f"🎯 Database record created with van_rating={analysis_result['van_rating']} and van_side='{analysis_result['van_side']}'")
            
            # Update van profile with damage rating info
            update_van_profile_with_damage(van_id, van_number, analysis_result)
            
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

def update_van_profile_with_damage(van_id: str, van_number: str, analysis_result: dict) -> bool:
    """Update van profile with damage rating information in the model field"""
    try:
        logger.info(f"🔄 Updating van #{van_number} profile with damage rating...")
        
        # Get current van data to calculate max damage
        current_van = supabase.table("van_profiles").select("*").eq("id", van_id).execute()
        
        if not current_van.data:
            logger.error("❌ Van not found for profile update")
            return False
        
        # Get all images for this van to calculate max damage rating
        images_response = supabase.table("van_images").select("van_rating, damage_type").eq("van_id", van_id).execute()
        
        max_rating = analysis_result['van_rating']
        damage_types = set([analysis_result['damage_type']])
        
        if images_response.data:
            for img in images_response.data:
                rating = img.get('van_rating') or 0
                max_rating = max(max_rating, rating)
                if img.get('damage_type'):
                    damage_types.add(img['damage_type'])
        
        # Create damage description for model field
        rating_text = {
            0: "No Damage",
            1: "Minor (Dirt/Debris)",
            2: "Moderate (Scratches)",
            3: "Major (Dents/Damage)"
        }
        
        damage_info = rating_text.get(max_rating, "Unknown")
        damage_types_str = ", ".join([dt for dt in damage_types if dt != 'unknown'])
        
        # Update van profile using model field to store damage info
        update_data = {
            "model": f"Rental Van - {damage_info} (Level {max_rating}/3)",
            "make": "Enterprise",  # Keep consistent branding
            "updated_at": datetime.now().isoformat()
        }
        
        if damage_types_str:
            update_data["model"] = f"Rental Van - {damage_info} - {damage_types_str}"
        
        logger.info(f"💾 Updating van profile model field to: {update_data['model']}")
        
        # Perform the update
        response = supabase.table("van_profiles").update(update_data).eq("id", van_id).execute()
        
        if response.data:
            logger.info(f"✅ Successfully updated van #{van_number} profile with damage rating")
            return True
        else:
            logger.error("❌ Failed to update van profile")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error in update_van_profile_with_damage: {e}")
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
    """Handle all message events with comprehensive damage analysis and auto-update names"""
    try:
        event = body["event"]
        
        # Skip bot messages
        if event.get("bot_id") or event.get("subtype") == "bot_message":
            return
        
        logger.info("==================================================")
        logger.info("📨 VAN PROFILE RATING BOT - CLAUDE AI + AUTO-UPDATE")
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
        driver_id = None
        driver_name = None
        
        if slack_user_id:
            logger.info(f"👤 Slack user ID: {slack_user_id}")
            
            # Get or create driver profile WITH auto-update functionality
            driver_id, driver_name = get_or_create_driver_profile(slack_user_id, client)
            if driver_id:
                logger.info(f"✅ Driver profile ready: {driver_name} (ID: {driver_id})")
            else:
                logger.error("❌ Failed to get/create driver profile")
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
                        f"🎯 **Van side and damage rating saved**\n"
                        f"📊 **Van profile updated with damage info**\n"
                        f"👤 **Driver profile auto-updated: {driver_name}**\n"
                        f"✨ **Flutter app will show damage rating in van profile!**")
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
    say("🚐 **Van Profile Rating Bot Ready! (Auto-Update Enabled)**\n"
        "📤 Upload an image with van number (e.g., 'van 123')\n"
        "🤖 **Claude AI will analyze and save:**\n"
        "  • Van side detection (fixed!)\n"
        "  • Damage rating (0-3 scale)\n"
        "  • Detailed damage description\n"
        "  • Van profile updated with rating\n"
        "👤 **Auto-Update Features:**\n"
        "  • Driver names sync with Slack changes\n"
        "  • Email updates automatically\n"
        "  • All records stay current\n"
        "📱 **Flutter app will display damage rating in van profile!**")

if __name__ == "__main__":
    try:
        # Initialize Supabase
        supabase_url = os.environ.get("SUPABASE_URL")
        supabase_key = os.environ.get("SUPABASE_KEY")
        
        if not supabase_url or not supabase_key:
            raise ValueError("SUPABASE_URL and SUPABASE_KEY are required")
        
        supabase = create_client(supabase_url, supabase_key)
        logger.info("✅ Supabase client initialized")
        
        logger.info("🚀 Starting VAN PROFILE RATING Bot with AUTO-UPDATE...")
        
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
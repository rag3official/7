#!/usr/bin/env python3

import os
import logging
import re
import json
import requests
import uuid
import base64
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

# Initialize Supabase client
supabase: Client = create_client(
    os.environ.get("SUPABASE_URL"),
    os.environ.get("SUPABASE_KEY")
)

# Initialize Anthropic client with proper error handling
def get_claude_client():
    """Initialize Claude client with proper error handling"""
    try:
        if not os.environ.get("CLAUDE_API_KEY"):
            logger.error("❌ CLAUDE_API_KEY not found in environment")
            return None
        
        client = anthropic.Anthropic(api_key=os.environ.get("CLAUDE_API_KEY"))
        logger.info("✅ Claude client initialized successfully")
        return client
    except Exception as e:
        logger.error(f"❌ Error initializing Claude client: {e}")
        return None

anthropic_client = get_claude_client()

def extract_text_from_event(event):
    """Extract text from various Slack event structures"""
    text_parts = []
    
    # Method 1: Direct text field
    if event.get('text'):
        text_parts.append(event['text'])
        logger.info(f"📄 Found direct text: '{event['text']}'")
    
    # Method 2: From blocks structure
    if event.get('blocks'):
        for block in event['blocks']:
            if block.get('type') == 'rich_text' and block.get('elements'):
                for element in block['elements']:
                    if element.get('type') == 'rich_text_section' and element.get('elements'):
                        for text_element in element['elements']:
                            if text_element.get('type') == 'text' and text_element.get('text'):
                                text_parts.append(text_element['text'])
                                logger.info(f"🧱 Found block text: '{text_element['text']}'")
    
    # Method 3: From message in event
    if event.get('message') and event['message'].get('text'):
        text_parts.append(event['message']['text'])
        logger.info(f"💬 Found message text: '{event['message']['text']}'")
    
    combined_text = ' '.join(text_parts).strip()
    logger.info(f"🔍 Extracted text from event: '{combined_text}'")
    return combined_text

def extract_van_number(text: str) -> str:
    """Extract van number from text using multiple patterns"""
    if not text:
        return None
    
    logger.info(f"🔍 Analyzing text for van number: '{text}'")
    
    patterns = [
        r'van\s*#?(\d+)',
        r'vehicle\s*#?(\d+)',
        r'truck\s*#?(\d+)',
        r'#(\d+)',
        r'(\d+)'
    ]
    
    for pattern in patterns:
        matches = re.finditer(pattern, text.lower())
        for match in matches:
            van_num = match.group(1)
            if van_num and len(van_num) >= 1:
                logger.info(f"✅ Found van number using pattern '{pattern}': {van_num}")
                return van_num
    
    logger.info("❌ No van number found in text")
    return None

def get_or_create_van(van_number: str) -> tuple:
    """Get existing van or create new one. Returns (van_id, was_created)"""
    try:
        logger.info(f"🔍 Looking for van #{van_number}")
        
        # Try to get existing van
        response = supabase.table("vans").select("*").eq("van_number", van_number).execute()
        
        if response.data and len(response.data) > 0:
            van_id = response.data[0]['id']
            logger.info(f"✅ Found existing van: {van_id}")
            return van_id, False
        else:
            # Create new van
            new_van = {
                "van_number": van_number,
                "status": "active",
                "created_at": datetime.utcnow().isoformat(),
                "updated_at": datetime.utcnow().isoformat()
            }
            
            response = supabase.table("vans").insert(new_van).execute()
            if response.data and len(response.data) > 0:
                van_id = response.data[0]['id']
                logger.info(f"✅ Created new van: {van_id}")
                return van_id, True
            else:
                logger.error("❌ Failed to create new van")
                return None, False
                
    except Exception as e:
        logger.error(f"❌ Error in get_or_create_van: {e}")
        return None, False

def check_database_schema():
    """Check the actual database schema to understand column names"""
    try:
        logger.info("🔍 Checking database schema...")
        
        # Check van_images table structure
        response = supabase.table("van_images").select("*").limit(1).execute()
        logger.info("📊 van_images table accessible")
        
        # Try different possible column names
        test_queries = [
            ("file_url", "SELECT file_url FROM van_images LIMIT 1"),
            ("image_url", "SELECT image_url FROM van_images LIMIT 1"), 
            ("url", "SELECT url FROM van_images LIMIT 1"),
            ("file_path", "SELECT file_path FROM van_images LIMIT 1"),
            ("uploaded_at", "SELECT uploaded_at FROM van_images LIMIT 1"),
            ("updated_at", "SELECT updated_at FROM van_images LIMIT 1"),
            ("created_at", "SELECT created_at FROM van_images LIMIT 1")
        ]
        
        available_columns = []
        for col_name, query in test_queries:
            try:
                supabase.rpc("raw_sql", {"query": query}).execute()
                available_columns.append(col_name)
                logger.info(f"✅ Column '{col_name}' exists")
            except:
                logger.info(f"❌ Column '{col_name}' does not exist")
        
        return available_columns
        
    except Exception as e:
        logger.error(f"❌ Error checking schema: {e}")
        return []

def save_van_image_universal(van_id: str, image_data: bytes, van_number: str, damage_assessment: str = None, damage_level: int = 0) -> bool:
    """Save van image using universal column detection"""
    try:
        # Convert image to base64 data URL
        image_base64 = base64.b64encode(image_data).decode('utf-8')
        data_url = f"data:image/jpeg;base64,{image_base64}"
        
        timestamp = datetime.utcnow().isoformat()
        
        # Try different possible column combinations
        column_variations = [
            # Variation 1: Standard columns
            {
                "van_id": van_id,
                "image_url": data_url,
                "uploaded_by": "slack_bot",
                "damage_level": damage_level,
                "notes": damage_assessment or "Uploaded via Slack bot",
                "created_at": timestamp,
                "updated_at": timestamp
            },
            # Variation 2: file_url instead of image_url
            {
                "van_id": van_id,
                "file_url": data_url,
                "uploaded_by": "slack_bot", 
                "damage_level": damage_level,
                "notes": damage_assessment or "Uploaded via Slack bot",
                "created_at": timestamp,
                "updated_at": timestamp
            },
            # Variation 3: url instead of file_url/image_url
            {
                "van_id": van_id,
                "url": data_url,
                "uploaded_by": "slack_bot",
                "damage_level": damage_level, 
                "notes": damage_assessment or "Uploaded via Slack bot",
                "created_at": timestamp,
                "updated_at": timestamp
            },
            # Variation 4: Minimal columns only
            {
                "van_id": van_id,
                "url": data_url,
                "created_at": timestamp
            },
            # Variation 5: Even more minimal
            {
                "van_id": van_id,
                "image_url": data_url
            },
            # Variation 6: Just van_id and file_path
            {
                "van_id": van_id,
                "file_path": f"van_{van_number}/slack_upload_{timestamp}.jpg"
            }
        ]
        
        for i, record_data in enumerate(column_variations, 1):
            try:
                logger.info(f"💾 Trying column variation {i}: {list(record_data.keys())}")
                response = supabase.table("van_images").insert(record_data).execute()
                
                if response.data:
                    logger.info(f"✅ Successfully saved image record with variation {i}")
                    return True
                else:
                    logger.info(f"❌ Variation {i} failed - no data returned")
                    
            except Exception as e:
                logger.info(f"❌ Variation {i} failed: {e}")
                continue
        
        logger.error("❌ All column variations failed")
        return False
        
    except Exception as e:
        logger.error(f"❌ Error in save_van_image_universal: {e}")
        return False

def upload_image_to_storage_safe(image_data: bytes, van_number: str) -> dict:
    """Safe storage upload that handles all errors gracefully"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_path = f"van_{van_number}/slack_image_{timestamp}.jpg"
    
    logger.info(f"🚀 SAFE STORAGE UPLOAD for {file_path}")
    
    # Convert to base64 as immediate fallback
    image_base64 = base64.b64encode(image_data).decode('utf-8')
    data_url = f"data:image/jpeg;base64,{image_base64}"
    
    # Method 1: Try direct API call with minimal headers
    try:
        logger.info("📤 Trying direct API upload...")
        url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/van-images/{file_path}"
        
        headers = {
            "Authorization": f"Bearer {os.environ.get('SUPABASE_KEY')}",
            "Content-Type": "image/jpeg",
            "x-upsert": "true"  # String, not boolean
        }
        
        response = requests.post(url, headers=headers, data=image_data, timeout=30)
        logger.info(f"📤 Direct API response: {response.status_code}")
        
        if response.status_code in [200, 201]:
            storage_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/public/van-images/{file_path}"
            logger.info("✅ Direct API upload successful!")
            return {
                "success": True,
                "url": storage_url,
                "method": "direct_api",
                "is_base64": False
            }
        else:
            logger.info(f"❌ Direct API failed: {response.status_code} - {response.text[:200]}")
    except Exception as e:
        logger.info(f"❌ Direct API exception: {e}")
    
    # Method 2: Always fallback to base64 storage
    logger.info("💾 Using base64 fallback (guaranteed success)")
    return {
        "success": True,
        "url": data_url,
        "method": "base64_fallback",
        "is_base64": True
    }

def update_van_damage(van_id: str, damage_assessment: str, damage_level: int) -> bool:
    """Update van with damage information"""
    try:
        update_data = {
            "last_damage_assessment": damage_assessment,
            "damage_level": damage_level,
            "updated_at": datetime.utcnow().isoformat()
        }
        
        response = supabase.table("vans").update(update_data).eq("id", van_id).execute()
        if response.data:
            logger.info("✅ Updated van damage information")
            return True
        else:
            logger.error("❌ Failed to update van damage")
            return False
    except Exception as e:
        logger.error(f"❌ Error updating van damage: {e}")
        return False

def analyze_damage_with_claude(image_data: bytes) -> dict:
    """Analyze damage using Claude with proper error handling"""
    if not anthropic_client:
        return {
            "assessment": "Claude API not available - manual review required",
            "damage_level": 1,
            "confidence": 0
        }
    
    try:
        logger.info("🧠 Analyzing damage with Claude...")
        
        # Convert image to base64
        image_base64 = base64.b64encode(image_data).decode('utf-8')
        
        logger.info("🧠 Sending image to Claude for analysis...")
        
        message = anthropic_client.messages.create(
            model="claude-3-sonnet-20241022",  # Updated model
            max_tokens=1000,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": image_base64
                            }
                        },
                        {
                            "type": "text",
                            "text": """Analyze this vehicle image for damage. Provide:

1. Damage Level (1-5 scale):
   - 1: No visible damage
   - 2: Minor scratches/scuffs
   - 3: Moderate damage (dents, significant scratches)
   - 4: Major damage (body damage, broken parts)
   - 5: Severe damage (major structural damage)

2. Brief description of damage observed
3. Recommended action

Format your response as:
Damage Level: [1-5] ([severity description])
Description: [what you see]
Recommendation: [suggested action]"""
                        }
                    ]
                }
            ]
        )
        
        assessment = message.content[0].text
        logger.info(f"🧠 Claude analysis complete: {assessment[:100]}...")
        
        # Extract damage level from response
        damage_level = 1
        level_match = re.search(r'Damage Level:\s*(\d+)', assessment)
        if level_match:
            damage_level = int(level_match.group(1))
        
        return {
            "assessment": assessment,
            "damage_level": damage_level,
            "confidence": 0.8
        }
        
    except Exception as e:
        logger.error(f"❌ Error analyzing with Claude: {e}")
        return {
            "assessment": f"Analysis failed: {str(e)} - Manual review required",
            "damage_level": 1,
            "confidence": 0
        }

@app.event("message")
def handle_message_events(body, say, client):
    """Comprehensive message handler with improved detection"""
    try:
        event = body.get("event", {})
        
        logger.info("==================================================")
        logger.info("📨 DATABASE SCHEMA FIXED MESSAGE HANDLER")
        logger.info("==================================================")
        
        # Extract text from all possible sources
        text = extract_text_from_event(event)
        
        if not text:
            logger.info("❌ No text found in event")
            return
        
        # Extract van number
        van_number = extract_van_number(text)
        if not van_number:
            logger.info("❌ No van number found in text")
            return
        
        logger.info(f"🚐 Detected van number: {van_number}")
        
        # Check for files in the event
        files = event.get('files', [])
        if not files:
            logger.info("📷 No files found in message")
            say(f"📋 Van #{van_number} noted, but no image attached for analysis.")
            return
        
        # Process each image
        for file_info in files:
            if file_info.get('mimetype', '').startswith('image/'):
                filename = file_info.get('name', 'unknown.jpg')
                logger.info(f"📷 Processing image: {filename}")
                
                # Get or create van
                van_id, was_created = get_or_create_van(van_number)
                if not van_id:
                    say(f"❌ Error processing van #{van_number}")
                    continue
                
                # Download image
                try:
                    file_url = file_info.get('url_private_download')
                    logger.info(f"📥 Downloading image from URL: {file_url}")
                    
                    headers = {"Authorization": f"Bearer {os.environ.get('SLACK_BOT_TOKEN')}"}
                    response = requests.get(file_url, headers=headers, timeout=30)
                    
                    if response.status_code == 200:
                        image_data = response.content
                        logger.info(f"✅ Successfully downloaded image ({len(image_data)} bytes)")
                        
                        # Upload to storage (with guaranteed fallback)
                        upload_result = upload_image_to_storage_safe(image_data, van_number)
                        
                        # Analyze with Claude
                        logger.info("🧠 Analyzing damage with Claude...")
                        damage_analysis = analyze_damage_with_claude(image_data)
                        
                        # Save to database with schema detection
                        logger.info("💾 Saving to database with universal schema...")
                        db_saved = save_van_image_universal(
                            van_id, 
                            image_data, 
                            van_number,
                            damage_analysis['assessment'],
                            damage_analysis['damage_level']
                        )
                        
                        # Update van damage info
                        update_van_damage(
                            van_id, 
                            damage_analysis['assessment'],
                            damage_analysis['damage_level']
                        )
                        
                        # Response to user
                        storage_status = "✅ Uploaded to storage" if not upload_result.get('is_base64') else "💾 Stored as data"
                        db_status = "✅ Database updated" if db_saved else "❌ Database error"
                        
                        say(f"""📸 **Van #{van_number} Image Processed**

🔹 **Storage**: {storage_status}
🔹 **Database**: {db_status}
🔹 **AI Analysis**: {damage_analysis['assessment'][:200]}...

{'🆕 New van created!' if was_created else '📝 Existing van updated.'}""")
                        
                    else:
                        logger.error(f"❌ Failed to download image: {response.status_code}")
                        say(f"❌ Could not download image for van #{van_number}")
                        
                except Exception as e:
                    logger.error(f"❌ Error processing image: {e}")
                    say(f"❌ Error processing image for van #{van_number}: {str(e)}")

    except Exception as e:
        logger.error(f"❌ Error in message handler: {e}")

@app.event("file_shared")
def handle_file_shared_events(body, logger):
    """Handle file shared events"""
    logger.info("📁 File shared event received (handled by message event)")

@app.message("van")
def handle_van_messages(message, say):
    """Handle messages containing 'van'"""
    logger.info("🚐 Van message detected")

if __name__ == "__main__":
    logger.info("🚀 Starting DATABASE SCHEMA FIXED Slack Bot...")
    
    # Environment check
    logger.info("📊 Environment check:")
    env_vars = ["SLACK_BOT_TOKEN", "SLACK_APP_TOKEN", "SUPABASE_URL", "SUPABASE_KEY", "CLAUDE_API_KEY"]
    for var in env_vars:
        status = "✅" if os.environ.get(var) else "❌"
        logger.info(f"  - {var}: {status}")
    
    # Check database schema
    check_database_schema()
    
    handler = SocketModeHandler(app, os.environ.get("SLACK_APP_TOKEN"))
    handler.start() 
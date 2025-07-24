#!/usr/bin/env python3

import os
import logging
import re
import json
import requests
import uuid
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
    os.environ.get("SUPABASE_SERVICE_KEY")
)

# Initialize Anthropic client
anthropic_client = anthropic.Anthropic(
    api_key=os.environ.get("ANTHROPIC_API_KEY")
)

def extract_text_from_event(event):
    """Extract text from Slack event with multiple fallback methods."""
    texts = []
    
    # Method 1: Direct text field
    if event.get('text'):
        texts.append(event['text'])
    
    # Method 2: Extract from blocks
    if event.get('blocks'):
        for block in event['blocks']:
            if block.get('type') == 'rich_text' and block.get('elements'):
                for element in block['elements']:
                    if element.get('type') == 'rich_text_section' and element.get('elements'):
                        for text_element in element['elements']:
                            if text_element.get('type') == 'text' and text_element.get('text'):
                                texts.append(text_element['text'])
    
    # Method 3: Check for file sharing with text
    if event.get('subtype') == 'file_share' and event.get('files'):
        # For file shares, also check direct text
        if event.get('text'):
            texts.append(event['text'])
    
    # Combine all found texts
    combined_text = ' '.join(texts).strip()
    logger.info(f"🔍 Extracted text from event: '{combined_text}'")
    return combined_text

def extract_van_number(text: str) -> str:
    """Extract van number from message text with improved detection."""
    if not text:
        return None
        
    # Clean and normalize text
    text = text.strip()
    logger.info(f"🔍 Analyzing text for van number: '{text}'")
    
    # Pattern 1: "van" followed by number (with optional space/# symbol)
    patterns = [
        r'van\s*#?(\d+)',
        r'vehicle\s*#?(\d+)', 
        r'truck\s*#?(\d+)',
        r'#(\d+)',
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            number = match.group(1)
            logger.info(f"✅ Found van number using pattern '{pattern}': {number}")
            return number
    
    # Pattern 2: Standalone number (if it's reasonable van number range)
    # Look for standalone numbers that could be van numbers
    standalone_match = re.search(r'^\s*(\d{1,4})\s*$', text)
    if standalone_match:
        number = standalone_match.group(1)
        van_num = int(number)
        # Accept numbers 1-9999 as potential van numbers
        if 1 <= van_num <= 9999:
            logger.info(f"✅ Found standalone van number: {number}")
            return number
    
    # Pattern 3: Number at start or end of short message
    if len(text.split()) <= 3:  # Short message
        number_match = re.search(r'(\d{1,4})', text)
        if number_match:
            number = number_match.group(1)
            van_num = int(number)
            if 1 <= van_num <= 9999:
                logger.info(f"✅ Found van number in short message: {number}")
                return number
    
    logger.warning(f"❌ No van number found in text: '{text}'")
    return None

def get_or_create_van(van_number: str) -> tuple:
    """Get existing van or create new one."""
    try:
        logger.info(f"🔍 Looking for van #{van_number}")
        
        # Check if van exists
        result = supabase.table('vans').select('*').eq('van_number', van_number).execute()
        
        if result.data:
            logger.info(f"✅ Found existing van: {result.data[0]['id']}")
            return "existing", result.data[0]
        
        # Create new van
        logger.info(f"🆕 Creating new van #{van_number}")
        new_van = {
            'van_number': van_number,
            'status': 'Active',
            'damage': 'No damage reported',
            'rating': 0,
            'created_at': datetime.now().isoformat(),
            'last_updated': datetime.now().isoformat()
        }
        
        result = supabase.table('vans').insert(new_van).execute()
        logger.info(f"✅ Created new van: {result.data[0]['id']}")
        return "created", result.data[0]
        
    except Exception as e:
        logger.error(f"❌ Error getting/creating van: {str(e)}")
        return "error", None

def upload_to_storage_direct_api(image_data: bytes, file_path: str) -> dict:
    """Upload directly to Supabase Storage using REST API."""
    try:
        supabase_url = os.environ.get("SUPABASE_URL")
        service_key = os.environ.get("SUPABASE_SERVICE_KEY")
        
        upload_url = f"{supabase_url}/storage/v1/object/van-images/{file_path}"
        
        headers = {
            'Authorization': f'Bearer {service_key}',
            'Content-Type': 'image/jpeg',
            'x-upsert': 'true'
        }
        
        logger.info(f"📤 Uploading to: {upload_url}")
        logger.info(f"📤 Image size: {len(image_data)} bytes")
        
        response = requests.post(upload_url, data=image_data, headers=headers)
        
        logger.info(f"📤 Upload response status: {response.status_code}")
        logger.info(f"📤 Upload response headers: {dict(response.headers)}")
        
        if response.status_code in [200, 201]:
            logger.info("✅ Successfully uploaded to storage via direct API!")
            return {
                'success': True, 
                'public_url': f"{supabase_url}/storage/v1/object/public/van-images/{file_path}",
                'method': 'direct_api'
            }
        else:
            logger.error(f"❌ Direct API upload failed: {response.status_code} - {response.text}")
            return {'success': False, 'error': f'HTTP {response.status_code}: {response.text}'}
            
    except Exception as e:
        logger.error(f"❌ Exception in direct API upload: {str(e)}")
        return {'success': False, 'error': str(e)}

def upload_to_storage_multipart(image_data: bytes, file_path: str) -> dict:
    """Upload using multipart form data."""
    try:
        supabase_url = os.environ.get("SUPABASE_URL")
        service_key = os.environ.get("SUPABASE_SERVICE_KEY")
        
        upload_url = f"{supabase_url}/storage/v1/object/van-images/{file_path}"
        
        headers = {
            'Authorization': f'Bearer {service_key}',
            'x-upsert': 'true'
        }
        
        files = {
            'file': ('image.jpg', image_data, 'image/jpeg')
        }
        
        logger.info(f"📤 Multipart upload to: {upload_url}")
        
        response = requests.post(upload_url, files=files, headers=headers)
        
        logger.info(f"📤 Multipart response status: {response.status_code}")
        
        if response.status_code in [200, 201]:
            logger.info("✅ Successfully uploaded via multipart!")
            return {
                'success': True, 
                'public_url': f"{supabase_url}/storage/v1/object/public/van-images/{file_path}",
                'method': 'multipart'
            }
        else:
            logger.error(f"❌ Multipart upload failed: {response.status_code} - {response.text}")
            return {'success': False, 'error': f'HTTP {response.status_code}: {response.text}'}
            
    except Exception as e:
        logger.error(f"❌ Exception in multipart upload: {str(e)}")
        return {'success': False, 'error': str(e)}

def upload_image_to_storage(image_data: bytes, van_number: str) -> dict:
    """Upload image to Supabase Storage with multiple methods."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"slack_image_{timestamp}.jpg"
    file_path = f"van_{van_number}/{filename}"
    
    logger.info(f"📤 Starting upload process for {file_path}")
    
    # Method 1: Direct API upload
    logger.info("📤 Trying direct API upload...")
    result = upload_to_storage_direct_api(image_data, file_path)
    if result['success']:
        return result
    
    # Method 2: Multipart upload
    logger.info("📤 Trying multipart upload...")
    result = upload_to_storage_multipart(image_data, file_path)
    if result['success']:
        return result
    
    # If both methods fail, return the last error
    logger.error("❌ All upload methods failed")
    return result

def save_van_image(van_id: str, image_url: str, van_number: str, damage_assessment: str = None) -> bool:
    """Save image record to database."""
    try:
        image_record = {
            'van_id': van_id,
            'file_url': image_url,
            'uploaded_at': datetime.now().isoformat(),
            'uploaded_by': 'slack_bot',
            'damage_assessment': damage_assessment or 'Pending analysis',
            'damage_level': 1,  # Default low damage
            'notes': f'Uploaded from Slack for van #{van_number}'
        }
        
        result = supabase.table('van_images').insert(image_record).execute()
        logger.info(f"✅ Saved image record to database: {result.data[0]['id']}")
        return True
        
    except Exception as e:
        logger.error(f"❌ Error saving image to database: {str(e)}")
        return False

def update_van_damage(van_id: str, damage_assessment: str, damage_level: int) -> bool:
    """Update van damage information."""
    try:
        update_data = {
            'damage': damage_assessment,
            'rating': damage_level,
            'last_updated': datetime.now().isoformat()
        }
        
        result = supabase.table('vans').update(update_data).eq('id', van_id).execute()
        logger.info(f"✅ Updated van damage information")
        return True
        
    except Exception as e:
        logger.error(f"❌ Error updating van: {str(e)}")
        return False

def analyze_damage_with_claude(image_data: bytes) -> dict:
    """Analyze image for damage using Claude."""
    try:
        import base64
        
        # Convert image to base64
        image_b64 = base64.b64encode(image_data).decode('utf-8')
        
        message = anthropic_client.messages.create(
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
                                "media_type": "image/jpeg",
                                "data": image_b64
                            }
                        },
                        {
                            "type": "text",
                            "text": "Analyze this vehicle image for damage. Rate damage level 1-5 (1=no damage, 5=severe damage). Provide a brief assessment."
                        }
                    ]
                }
            ]
        )
        
        response = message.content[0].text
        
        # Extract damage level from response
        damage_level = 1  # Default
        if "level 5" in response.lower() or "severe" in response.lower():
            damage_level = 5
        elif "level 4" in response.lower() or "major" in response.lower():
            damage_level = 4
        elif "level 3" in response.lower() or "moderate" in response.lower():
            damage_level = 3
        elif "level 2" in response.lower() or "minor" in response.lower():
            damage_level = 2
        
        return {
            'assessment': response,
            'damage_level': damage_level
        }
        
    except Exception as e:
        logger.error(f"❌ Error analyzing with Claude: {str(e)}")
        return {
            'assessment': 'Analysis failed - manual review required',
            'damage_level': 1
        }

@app.event("message")
def handle_message_events(body, say, client):
    """Handle incoming message events."""
    try:
        logger.info("="*50)
        logger.info("📨 MESSAGE EVENT RECEIVED")
        logger.info("="*50)
        logger.info(f"Event body: {json.dumps(body, indent=2)}")
        
        event = body['event']
        
        # Skip messages from bots
        if 'bot_id' in event:
            logger.info("🤖 Skipping bot message")
            return
            
        # Extract text using improved method
        message_text = extract_text_from_event(event)
        
        # Extract van number with improved detection
        van_number = extract_van_number(message_text)
        if not van_number:
            logger.warning("❌ No van number found in message")
            return
            
        logger.info(f"🚐 Detected van number: {van_number}")
        
        # Check for file attachments
        files = event.get('files', [])
        if not files:
            logger.info("📷 No files attached to message")
            say(f"Van #{van_number} noted. Please attach an image for damage assessment.")
            return
        
        # Process each image file
        for file_info in files:
            if not file_info.get('mimetype', '').startswith('image/'):
                logger.info(f"⚠️ Skipping non-image file: {file_info.get('name')}")
                continue
                
            logger.info(f"📷 Processing image: {file_info.get('name')}")
            
            # Get or create van record
            van_status, van_data = get_or_create_van(van_number)
            if van_status == "error":
                say(f"❌ Error accessing van #{van_number} database record.")
                continue
                
            van_id = van_data['id']
            
            # Download image from Slack
            download_url = file_info.get('url_private_download') or file_info.get('url_private')
            if not download_url:
                logger.error("❌ No download URL found in file info")
                continue
                
            try:
                logger.info(f"📥 Downloading image from URL: {download_url}")
                headers = {'Authorization': f'Bearer {os.environ.get("SLACK_BOT_TOKEN")}'}
                response = requests.get(download_url, headers=headers)
                response.raise_for_status()
                
                image_data = response.content
                logger.info(f"✅ Successfully downloaded image ({len(image_data)} bytes)")
                
                # Upload to Supabase Storage
                logger.info("📤 Uploading image to Supabase Storage...")
                upload_result = upload_image_to_storage(image_data, van_number)
                
                # Analyze damage with Claude
                logger.info("🧠 Analyzing damage with Claude...")
                damage_analysis = analyze_damage_with_claude(image_data)
                
                # Save to database regardless of storage success
                if upload_result['success']:
                    image_url = upload_result['public_url']
                    storage_status = f"✅ Storage: Success ({upload_result['method']})"
                else:
                    image_url = f"placeholder_url_van_{van_number}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
                    storage_status = f"❌ Storage: Failed - {upload_result.get('error', 'Unknown error')}"
                
                # Save image record
                db_success = save_van_image(van_id, image_url, van_number, damage_analysis['assessment'])
                db_status = "✅ Database: Success" if db_success else "❌ Database: Failed"
                
                # Update van damage info
                update_van_damage(van_id, damage_analysis['assessment'], damage_analysis['damage_level'])
                
                # Send comprehensive response
                response_message = f"""🚐 **Van #{van_number} Image Processed**

{storage_status}
{db_status}

🧠 **Damage Analysis:**
Level: {damage_analysis['damage_level']}/5
Assessment: {damage_analysis['assessment'][:200]}{'...' if len(damage_analysis['assessment']) > 200 else ''}

{'✅ All systems operational!' if upload_result['success'] and db_success else '⚠️ Some issues occurred - check logs'}"""
                
                say(response_message)
                
            except Exception as e:
                logger.error(f"❌ Error processing image: {str(e)}")
                say(f"❌ Error processing image for van #{van_number}: {str(e)}")
                
    except Exception as e:
        logger.error(f"❌ Error in message handler: {str(e)}")

@app.event("file_shared")
def handle_file_shared_events(body, logger):
    """Handle file_shared events."""
    logger.info("📁 File shared event received")
    # File sharing is handled in message events
    pass

@app.message("van")
def handle_van_messages(message, say):
    """Handle messages containing 'van' for testing."""
    logger.info("🚐 Van message detected for testing")
    # Main processing is in handle_message_events

# Start the app
if __name__ == "__main__":
    logger.info("🚀 Starting Slack Bot...")
    handler = SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"])
    handler.start() 
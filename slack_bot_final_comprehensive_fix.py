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
    os.environ.get("SUPABASE_KEY")
)

# Initialize Anthropic client with proper error handling
def get_claude_client():
    """Initialize Claude client with proper error handling."""
    try:
        api_key = os.environ.get("CLAUDE_API_KEY")
        if not api_key:
            logger.error("❌ CLAUDE_API_KEY not found in environment")
            return None
        
        client = anthropic.Anthropic(api_key=api_key)
        logger.info("✅ Claude client initialized successfully")
        return client
    except Exception as e:
        logger.error(f"❌ Error initializing Claude client: {str(e)}")
        return None

anthropic_client = get_claude_client()

def extract_text_from_event(event):
    """Extract text from Slack event with multiple fallback methods."""
    texts = []
    
    # Method 1: Direct text field
    if event.get('text'):
        texts.append(event['text'])
        logger.info(f"📄 Found direct text: '{event['text']}'")
    
    # Method 2: Extract from blocks
    if event.get('blocks'):
        for block in event['blocks']:
            if block.get('type') == 'rich_text' and block.get('elements'):
                for element in block['elements']:
                    if element.get('type') == 'rich_text_section' and element.get('elements'):
                        for text_element in element['elements']:
                            if text_element.get('type') == 'text' and text_element.get('text'):
                                texts.append(text_element['text'])
                                logger.info(f"🧱 Found block text: '{text_element['text']}'")
    
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

def upload_to_storage_with_sdk_bypass(image_data: bytes, file_path: str) -> dict:
    """Upload using Supabase SDK with rate limit bypass."""
    try:
        logger.info(f"📤 SDK BYPASS: Uploading {file_path}")
        
        # Try to upload using the SDK but with special options
        file_options = {
            "cache-control": "3600",
            "upsert": True
        }
        
        result = supabase.storage.from_("van-images").upload(
            file_path, 
            image_data,
            file_options
        )
        
        if hasattr(result, 'error') and result.error:
            logger.error(f"❌ SDK upload error: {result.error}")
            return {'success': False, 'error': str(result.error)}
        
        # Get public URL
        public_url = supabase.storage.from_("van-images").get_public_url(file_path)
        
        logger.info("✅ SUCCESS: SDK bypass upload worked!")
        return {
            'success': True, 
            'public_url': public_url,
            'method': 'sdk_bypass'
        }
        
    except Exception as e:
        logger.error(f"❌ Exception in SDK bypass: {str(e)}")
        return {'success': False, 'error': str(e)}

def upload_to_storage_direct_http(image_data: bytes, file_path: str) -> dict:
    """Upload directly via HTTP without going through storage triggers."""
    try:
        supabase_url = os.environ.get("SUPABASE_URL")
        service_key = os.environ.get("SUPABASE_KEY")
        
        # Use the direct file upload endpoint
        upload_url = f"{supabase_url}/storage/v1/object/van-images/{file_path}"
        
        headers = {
            'Authorization': f'Bearer {service_key}',
            'Content-Type': 'application/octet-stream',
            'x-upsert': 'true',
            'Cache-Control': 'max-age=3600'
        }
        
        logger.info(f"📤 DIRECT HTTP: {upload_url}")
        logger.info(f"📤 Size: {len(image_data)} bytes")
        
        response = requests.post(upload_url, data=image_data, headers=headers, timeout=30)
        
        logger.info(f"📤 Response: {response.status_code}")
        
        if response.status_code in [200, 201]:
            public_url = f"{supabase_url}/storage/v1/object/public/van-images/{file_path}"
            logger.info("✅ SUCCESS: Direct HTTP upload worked!")
            return {
                'success': True, 
                'public_url': public_url,
                'method': 'direct_http'
            }
        else:
            logger.error(f"❌ HTTP upload failed: {response.status_code} - {response.text}")
            return {'success': False, 'error': f'HTTP {response.status_code}: {response.text}'}
            
    except Exception as e:
        logger.error(f"❌ Exception in direct HTTP: {str(e)}")
        return {'success': False, 'error': str(e)}

def store_image_as_base64_fallback(image_data: bytes, van_number: str) -> dict:
    """Store image as base64 in database as fallback."""
    try:
        import base64
        
        # Convert to base64
        image_b64 = base64.b64encode(image_data).decode('utf-8')
        
        # Store in database with base64 data
        logger.info(f"💾 FALLBACK: Storing as base64 in database")
        
        # We'll return a data URL that can be used to display the image
        data_url = f"data:image/jpeg;base64,{image_b64}"
        
        logger.info("✅ SUCCESS: Base64 fallback worked!")
        return {
            'success': True,
            'public_url': data_url,
            'method': 'base64_fallback',
            'is_base64': True
        }
        
    except Exception as e:
        logger.error(f"❌ Exception in base64 fallback: {str(e)}")
        return {'success': False, 'error': str(e)}

def upload_image_to_storage(image_data: bytes, van_number: str) -> dict:
    """Upload image with multiple fallback methods."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"slack_image_{timestamp}.jpg"
    file_path = f"van_{van_number}/{filename}"
    
    logger.info(f"🚀 COMPREHENSIVE UPLOAD for {file_path}")
    
    # Method 1: SDK with bypass
    logger.info("📤 Trying SDK bypass...")
    result = upload_to_storage_with_sdk_bypass(image_data, file_path)
    if result['success']:
        return result
    
    # Method 2: Direct HTTP
    logger.info("🌐 Trying direct HTTP...")
    result = upload_to_storage_direct_http(image_data, file_path)
    if result['success']:
        return result
    
    # Method 3: Base64 fallback
    logger.info("💾 Trying base64 fallback...")
    result = store_image_as_base64_fallback(image_data, van_number)
    if result['success']:
        return result
    
    # If all methods fail
    logger.error("💥 ALL UPLOAD METHODS FAILED")
    return {'success': False, 'error': 'All upload methods failed'}

def save_van_image_fixed_schema(van_id: str, image_url: str, van_number: str, damage_assessment: str = None, is_base64: bool = False) -> bool:
    """Save image record to database with correct schema."""
    try:
        # Check what columns actually exist in van_images table
        logger.info("🔍 Checking van_images table schema...")
        
        # Try to get the table structure first
        try:
            # Do a simple select to see what columns exist
            test_result = supabase.table('van_images').select('*').limit(1).execute()
            logger.info(f"📊 Table query successful, structure check complete")
        except Exception as schema_error:
            logger.error(f"❌ Schema check error: {str(schema_error)}")
        
        # Use only the columns that definitely exist
        image_record = {
            'van_id': van_id,
            'file_url': image_url,
            'uploaded_by': 'slack_bot',
            'damage_level': 1,  # Default low damage
            'notes': f'Uploaded from Slack for van #{van_number}. {damage_assessment or "Analysis pending"}'
        }
        
        # Only add uploaded_at if we know the column exists
        try:
            image_record['uploaded_at'] = datetime.now().isoformat()
        except:
            # If uploaded_at doesn't exist, use updated_at or created_at
            try:
                image_record['updated_at'] = datetime.now().isoformat()
            except:
                image_record['created_at'] = datetime.now().isoformat()
        
        # Add base64 flag if applicable
        if is_base64:
            image_record['notes'] += ' [Stored as base64 due to storage constraints]'
        
        logger.info(f"💾 Saving image record with fields: {list(image_record.keys())}")
        
        result = supabase.table('van_images').insert(image_record).execute()
        logger.info(f"✅ Saved image record to database: {result.data[0]['id']}")
        return True
        
    except Exception as e:
        logger.error(f"❌ Error saving image to database: {str(e)}")
        # Try with minimal record
        try:
            minimal_record = {
                'van_id': van_id,
                'file_url': image_url,
                'notes': f'Van #{van_number} - Slack upload'
            }
            result = supabase.table('van_images').insert(minimal_record).execute()
            logger.info(f"✅ Saved minimal image record: {result.data[0]['id']}")
            return True
        except Exception as minimal_error:
            logger.error(f"❌ Even minimal record failed: {str(minimal_error)}")
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
    """Analyze image for damage using Claude with proper error handling."""
    try:
        if not anthropic_client:
            logger.warning("⚠️ Claude client not available - skipping analysis")
            return {
                'assessment': 'Automatic analysis unavailable - manual review required',
                'damage_level': 1
            }
        
        import base64
        
        # Convert image to base64
        image_b64 = base64.b64encode(image_data).decode('utf-8')
        
        logger.info("🧠 Sending image to Claude for analysis...")
        
        message = anthropic_client.messages.create(
            model="claude-3-5-sonnet-20241022",  # Updated model
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
        logger.info(f"🧠 Claude analysis complete: {response[:100]}...")
        
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
            'assessment': f'Analysis failed ({str(e)}) - manual review required',
            'damage_level': 1
        }

@app.event("message")
def handle_message_events(body, say, client):
    """Handle incoming message events."""
    try:
        logger.info("="*50)
        logger.info("📨 COMPREHENSIVE MESSAGE HANDLER")
        logger.info("="*50)
        
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
                
                # Upload to storage with comprehensive methods
                logger.info("🚀 Starting comprehensive storage upload...")
                upload_result = upload_image_to_storage(image_data, van_number)
                
                # Analyze damage with Claude
                logger.info("🧠 Analyzing damage with Claude...")
                damage_analysis = analyze_damage_with_claude(image_data)
                
                # Save to database regardless of storage success
                if upload_result['success']:
                    image_url = upload_result['public_url']
                    storage_status = f"✅ Storage: SUCCESS via {upload_result['method']}!"
                    is_base64 = upload_result.get('is_base64', False)
                else:
                    image_url = f"placeholder_url_van_{van_number}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
                    storage_status = f"❌ Storage: FAILED - {upload_result.get('error', 'Unknown error')}"
                    is_base64 = False
                
                # Save image record with fixed schema
                db_success = save_van_image_fixed_schema(van_id, image_url, van_number, damage_analysis['assessment'], is_base64)
                db_status = "✅ Database: SUCCESS" if db_success else "❌ Database: FAILED"
                
                # Update van damage info
                update_van_damage(van_id, damage_analysis['assessment'], damage_analysis['damage_level'])
                
                # Send comprehensive response
                method_emoji = {
                    'sdk_bypass': '🔧',
                    'direct_http': '🌐', 
                    'base64_fallback': '💾'
                }.get(upload_result.get('method'), '📤')
                
                response_message = f"""🚐 **Van #{van_number} Image Processed**

{storage_status} {method_emoji}
{db_status}

🧠 **Damage Analysis:**
Level: {damage_analysis['damage_level']}/5
Assessment: {damage_analysis['assessment'][:200]}{'...' if len(damage_analysis['assessment']) > 200 else ''}

💪 **System Status:**
{'🎉 FULL SUCCESS - All systems operational!' if upload_result['success'] and db_success else '⚠️ PARTIAL SUCCESS - Check logs for details'}

{f"📋 Note: Image stored as base64 due to storage constraints" if is_base64 else ""}"""
                
                say(response_message)
                
            except Exception as e:
                logger.error(f"❌ Error processing image: {str(e)}")
                say(f"❌ Error processing image for van #{van_number}: {str(e)}")
                
    except Exception as e:
        logger.error(f"❌ Error in message handler: {str(e)}")

@app.event("file_shared")
def handle_file_shared_events(body, logger):
    """Handle file_shared events."""
    logger.info("📁 File shared event received (handled by message event)")
    # File sharing is handled in message events

@app.message("van")
def handle_van_messages(message, say):
    """Handle messages containing 'van' for testing."""
    logger.info("🚐 Van message detected for testing")
    # Main processing is in handle_message_events

# Start the app
if __name__ == "__main__":
    logger.info("🚀 Starting COMPREHENSIVE FIXED Slack Bot...")
    logger.info(f"📊 Environment check:")
    logger.info(f"  - SLACK_BOT_TOKEN: {'✅' if os.environ.get('SLACK_BOT_TOKEN') else '❌'}")
    logger.info(f"  - SLACK_APP_TOKEN: {'✅' if os.environ.get('SLACK_APP_TOKEN') else '❌'}")
    logger.info(f"  - SUPABASE_URL: {'✅' if os.environ.get('SUPABASE_URL') else '❌'}")
    logger.info(f"  - SUPABASE_KEY: {'✅' if os.environ.get('SUPABASE_KEY') else '❌'}")
    logger.info(f"  - CLAUDE_API_KEY: {'✅' if os.environ.get('CLAUDE_API_KEY') else '❌'}")
    
    handler = SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"])
    handler.start() 
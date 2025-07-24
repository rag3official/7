#!/usr/bin/env python3

import os
import re
import logging
import requests
import base64
from datetime import datetime
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from supabase import create_client, Client

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Slack app
app = App(token=os.environ.get("SLACK_BOT_TOKEN"))

# Initialize Supabase client
supabase_url = os.environ.get("SUPABASE_URL")
supabase_key = os.environ.get("SUPABASE_KEY")
supabase: Client = create_client(supabase_url, supabase_key)

def detect_content_type(data):
    """Detect content type from file data"""
    if data.startswith(b'\x89PNG'):
        return 'image/png'
    elif data.startswith(b'\xff\xd8\xff'):
        return 'image/jpeg'
    elif data.startswith(b'GIF87a') or data.startswith(b'GIF89a'):
        return 'image/gif'
    elif data.startswith(b'\x42\x4d'):
        return 'image/bmp'
    else:
        return 'image/jpeg'  # Default fallback

def extract_van_number(text):
    """Extract van number from text using multiple patterns"""
    if not text:
        return None
    
    patterns = [
        r'van\s*#?(\d+)',
        r'#(\d+)',
        r'(\d+)'
    ]
    
    text_lower = text.lower()
    for pattern in patterns:
        match = re.search(pattern, text_lower)
        if match:
            van_num = int(match.group(1))
            logger.info(f"✅ Found van number using pattern '{pattern}': {van_num}")
            return van_num
    
    logger.warning(f"❌ No van number found in text: '{text}'")
    return None

def get_or_create_driver_profile(slack_user_id, slack_client):
    """Get existing driver profile or create new one"""
    try:
        # Check if driver profile exists
        result = supabase.table('driver_profiles').select('*').eq('slack_user_id', slack_user_id).execute()
        
        if result.data:
            logger.info(f"✅ Found existing driver profile: {result.data[0]['driver_name']}")
            return result.data[0]
        
        # Get user info from Slack
        user_info = slack_client.users_info(user=slack_user_id)
        user_data = user_info.data['user']
        
        driver_name = user_data.get('real_name') or user_data.get('display_name') or user_data.get('name', f'Driver_{slack_user_id}')
        email = user_data.get('profile', {}).get('email')
        
        # Create new driver profile
        new_driver = {
            'slack_user_id': slack_user_id,
            'driver_name': driver_name,
            'email': email,
            'status': 'active'
        }
        
        result = supabase.table('driver_profiles').insert(new_driver).execute()
        logger.info(f"✅ Created new driver profile: {driver_name}")
        return result.data[0]
        
    except Exception as e:
        logger.error(f"❌ Error managing driver profile: {e}")
        return None

def get_or_create_van_profile(van_number):
    """Get existing van profile or create new one"""
    try:
        # Check if van exists
        result = supabase.table('van_profiles').select('*').eq('van_number', van_number).execute()
        
        if result.data:
            logger.info(f"✅ Found existing van profile: Van #{van_number}")
            return result.data[0]
        
        # Create new van profile
        new_van = {
            'van_number': van_number,
            'status': 'active'
        }
        
        result = supabase.table('van_profiles').insert(new_van).execute()
        logger.info(f"✅ Created new van profile: Van #{van_number}")
        return result.data[0]
        
    except Exception as e:
        logger.error(f"❌ Error managing van profile: {e}")
        return None

def parse_damage_and_rating_from_message(message_text):
    """Extract damage description and rating from message text"""
    damage_description = None
    rating = None
    
    if not message_text:
        return damage_description, rating
    
    # Look for damage keywords
    damage_keywords = ['damage', 'dent', 'scratch', 'broken', 'cracked', 'issue', 'problem']
    text_lower = message_text.lower()
    
    if any(keyword in text_lower for keyword in damage_keywords):
        # Extract damage description (simple approach)
        damage_description = message_text.strip()
    
    # Look for rating patterns like "rating: 2" or "condition: 3" or just "2/3"
    rating_patterns = [
        r'rating[:\s]+([0-3])',
        r'condition[:\s]+([0-3])',
        r'([0-3])/3',
        r'rate[:\s]+([0-3])'
    ]
    
    for pattern in rating_patterns:
        match = re.search(pattern, text_lower)
        if match:
            rating = int(match.group(1))
            logger.info(f"✅ Found rating: {rating}")
            break
    
    return damage_description, rating

def save_image_to_database(van_profile, driver_profile, image_url, file_path, file_size, content_type, damage_description=None, rating=None):
    """Save image record to database with full profile relationships"""
    try:
        image_record = {
            'van_id': van_profile['id'],
            'van_number': van_profile['van_number'],
            'driver_id': driver_profile['id'],
            'slack_user_id': driver_profile['slack_user_id'],
            'image_url': image_url,
            'file_path': file_path,
            'file_size': file_size,
            'content_type': content_type,
            'van_damage': damage_description,
            'van_rating': rating,
            'upload_method': 'slack_bot',
            'upload_source': 'slack_channel'
        }
        
        result = supabase.table('van_images').insert(image_record).execute()
        logger.info(f"✅ Saved image record to database: {result.data[0]['id']}")
        return result.data[0]
        
    except Exception as e:
        logger.error(f"❌ Error saving image to database: {e}")
        return None

async def process_file_upload(file_info, channel_id, slack_user_id, client):
    """Process file upload with full profile integration"""
    try:
        logger.info(f"📷 Processing image for user: {slack_user_id}")
        
        # Get or create driver profile
        driver_profile = get_or_create_driver_profile(slack_user_id, client)
        if not driver_profile:
            await client.chat_postMessage(channel=channel_id, text="❌ Failed to create/find driver profile")
            return
        
        # Get recent messages to find van number
        messages = client.conversations_history(channel=channel_id, limit=10)
        van_number = None
        message_text = ""
        
        for message in messages.data['messages']:
            text = message.get('text', '')
            if text:
                message_text = text
                van_number = extract_van_number(text)
                if van_number:
                    break
        
        if not van_number:
            await client.chat_postMessage(channel=channel_id, text="❌ No van number found in recent messages. Please specify van number (e.g., 'van 123')")
            return
        
        logger.info(f"✅ Found van number {van_number} for driver {driver_profile['driver_name']}")
        
        # Get or create van profile
        van_profile = get_or_create_van_profile(van_number)
        if not van_profile:
            await client.chat_postMessage(channel=channel_id, text=f"❌ Failed to create/find van profile for van #{van_number}")
            return
        
        # Parse damage and rating from message
        damage_description, rating = parse_damage_and_rating_from_message(message_text)
        
        # Download image from Slack
        file_url = file_info.get('url_private_download') or file_info.get('url_private')
        if not file_url:
            logger.error("❌ No download URL found in file info")
            return
        
        logger.info(f"📥 Downloading image from Slack: {file_url[:50]}...")
        
        headers = {'Authorization': f'Bearer {os.environ.get("SLACK_BOT_TOKEN")}'}
        response = requests.get(file_url, headers=headers)
        
        if response.status_code != 200:
            logger.error(f"❌ Failed to download image: {response.status_code}")
            return
        
        image_data = response.content
        logger.info(f"✅ Successfully downloaded image ({len(image_data)} bytes)")
        
        # Detect content type
        content_type = detect_content_type(image_data)
        logger.info(f"📤 Detected content type: {content_type}")
        
        # Generate file path and URL
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        extension = 'jpg' if 'jpeg' in content_type else content_type.split('/')[-1]
        file_path = f"van_{van_number}/image_{timestamp}.{extension}"
        
        # Use the simple metadata function that just saves to database
        base64_data = base64.b64encode(image_data).decode('utf-8')
        
        logger.info(f"🔄 Calling database function to save image metadata...")
        result = supabase.rpc('slack_bot_upload_bypass', {
            'bucket_name': 'van-images',
            'file_path': file_path,
            'file_data': base64_data,
            'content_type': content_type
        }).execute()
        
        if result.data and result.data.get('success'):
            logger.info(f"✅ Database function succeeded: {result.data}")
            
            # Construct image URL
            image_url = f"{supabase_url}/storage/v1/object/public/van-images/{file_path}"
            
            # Save full image record with profile relationships
            image_record = save_image_to_database(
                van_profile, 
                driver_profile, 
                image_url, 
                file_path, 
                len(image_data), 
                content_type,
                damage_description,
                rating
            )
            
            if image_record:
                # Create success message
                success_msg = f"✅ Image uploaded successfully!\n"
                success_msg += f"📋 **Van #{van_number}** - Driver: {driver_profile['driver_name']}\n"
                if damage_description:
                    success_msg += f"🔧 Damage: {damage_description}\n"
                if rating is not None:
                    success_msg += f"⭐ Rating: {rating}/3\n"
                success_msg += f"🔗 [View Image]({image_url})"
                
                await client.chat_postMessage(channel=channel_id, text=success_msg)
            else:
                await client.chat_postMessage(channel=channel_id, text="⚠️ Image uploaded but failed to save complete record")
        else:
            logger.error(f"❌ Database function failed: {result.data}")
            await client.chat_postMessage(channel=channel_id, text=f"❌ Failed to upload image for van {van_number}")
            
    except Exception as e:
        logger.error(f"❌ Upload failed: {e}")
        await client.chat_postMessage(channel=channel_id, text="❌ Upload failed due to an error")

@app.event("file_shared")
async def handle_file_shared(event, client):
    """Handle file_shared events"""
    logger.info("📁 Received file_shared event")
    
    try:
        file_id = event.get('file_id')
        channel_id = event.get('channel_id')
        user_id = event.get('user_id')
        
        if not all([file_id, channel_id, user_id]):
            logger.error("❌ Missing required event data")
            return
        
        # Get complete file info
        file_info_response = client.files_info(file=file_id)
        file_info = file_info_response.data['file']
        
        # Check if it's an image
        if not file_info.get('mimetype', '').startswith('image/'):
            logger.info("📄 File is not an image, skipping")
            return
        
        logger.info(f"✅ Retrieved complete file info: {file_info.get('name')} ({file_info.get('mimetype')})")
        
        await process_file_upload(file_info, channel_id, user_id, client)
        
    except Exception as e:
        logger.error(f"❌ Error handling file_shared event: {e}")

@app.event("message")
async def handle_message_with_files(message, client):
    """Handle messages with file attachments"""
    if message.get('subtype') == 'file_share' and 'files' in message:
        logger.info("📁 Received message with file_share subtype")
        
        try:
            file_info = message['files'][0]  # Get first file
            channel_id = message.get('channel')
            user_id = message.get('user')
            
            # Check if it's an image
            if not file_info.get('mimetype', '').startswith('image/'):
                logger.info("📄 File is not an image, skipping")
                return
            
            await process_file_upload(file_info, channel_id, user_id, client)
            
        except Exception as e:
            logger.error(f"❌ Error handling message with files: {e}")

if __name__ == "__main__":
    logger.info("🚀 Starting PROFILE AWARE Slack Bot...")
    logger.info("📁 Focus: Complete driver and van profile integration")
    
    # Check environment variables
    required_vars = ["SLACK_BOT_TOKEN", "SLACK_APP_TOKEN", "SUPABASE_URL", "SUPABASE_KEY"]
    missing_vars = [var for var in required_vars if not os.environ.get(var)]
    
    if missing_vars:
        logger.error(f"❌ Missing environment variables: {missing_vars}")
        exit(1)
    
    logger.info("✅ All environment variables found")
    logger.info("🚀 Starting Slack bot with Socket Mode...")
    
    handler = SocketModeHandler(app, os.environ.get("SLACK_APP_TOKEN"))
    handler.start() 
#!/usr/bin/env python3

import os
import re
import logging
import requests
import json
from datetime import datetime
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Slack app
app = App(token=os.environ.get("SLACK_BOT_TOKEN"))

# Supabase configuration
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

# Track processed files to prevent duplicates
processed_files = set()

def detect_content_type(image_data):
    """Detect content type from image data"""
    if image_data.startswith(b'\x89PNG'):
        return 'image/png'
    elif image_data.startswith(b'\xff\xd8\xff'):
        return 'image/jpeg'
    elif image_data.startswith(b'GIF8'):
        return 'image/gif'
    elif image_data.startswith(b'RIFF') and b'WEBP' in image_data[:12]:
        return 'image/webp'
    else:
        return 'image/jpeg'  # Default fallback

def find_van_number_in_recent_messages(channel_id):
    """Find van number in recent messages"""
    try:
        # Get recent messages from the channel
        result = app.client.conversations_history(
            channel=channel_id,
            limit=10
        )
        
        van_patterns = [
            r'van\s*#?(\d+)',
            r'#van\s*(\d+)', 
            r'vehicle\s*#?(\d+)',
            r'#(\d+)\s*van'
        ]
        
        for message in result['messages']:
            text = message.get('text', '').lower()
            logger.info(f"🔍 Analyzing text for van number: '{text}'")
            
            for pattern in van_patterns:
                match = re.search(pattern, text, re.IGNORECASE)
                if match:
                    van_number = match.group(1)
                    logger.info(f"✅ Found van number using pattern '{pattern}': {van_number}")
                    return van_number
        
        logger.info("❌ No van number found in recent messages")
        return None
        
    except Exception as e:
        logger.error(f"❌ Error finding van number: {e}")
        return None

def get_or_create_van(van_number):
    """Get existing van or create new one using correct schema"""
    try:
        # Check if van exists
        logger.info(f"🔍 Looking for van #{van_number}")
        
        headers = {
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}',
            'Content-Type': 'application/json'
        }
        
        response = requests.get(
            f"{SUPABASE_URL}/rest/v1/vans",
            headers=headers,
            params={'select': '*', 'van_number': f'eq.{van_number}'}
        )
        
        if response.status_code == 200:
            vans = response.json()
            if vans:
                logger.info(f"✅ Found existing van: {vans[0]['id']}")
                return vans[0]['id']
        
        # Create new van using correct schema
        logger.info(f"🆕 Creating new van #{van_number}")
        
        van_data = {
            'van_number': int(van_number),
            'type': 'Unknown',
            'status': 'active',
            'date': datetime.now().isoformat(),
            'notes': f'Auto-created for image upload',
            'driver': 'Unknown'
        }
        
        response = requests.post(
            f"{SUPABASE_URL}/rest/v1/vans",
            headers=headers,
            json=van_data
        )
        
        if response.status_code == 201:
            new_van = response.json()[0]
            logger.info(f"✅ Created new van: {new_van['id']}")
            return new_van['id']
        else:
            logger.error(f"❌ Failed to create van: {response.text}")
            return None
            
    except Exception as e:
        logger.error(f"❌ Error with van operations: {e}")
        return None

def upload_image_raw_http(image_data, file_path, content_type):
    """Upload image using raw HTTP requests"""
    try:
        # Use raw HTTP POST to Supabase Storage API
        url = f"{SUPABASE_URL}/storage/v1/object/van-images/{file_path}"
        
        headers = {
            'Authorization': f'Bearer {SUPABASE_KEY}',
            'Content-Type': content_type,
            'x-upsert': 'true'  # Allow overwriting
        }
        
        logger.info(f"📤 Raw HTTP upload to: {url}")
        logger.info(f"📤 Content-Type: {content_type}")
        logger.info(f"📤 Data size: {len(image_data)} bytes")
        
        response = requests.post(url, headers=headers, data=image_data)
        
        logger.info(f"📤 Response status: {response.status_code}")
        logger.info(f"📤 Response headers: {dict(response.headers)}")
        
        if response.status_code in [200, 201]:
            logger.info("✅ Raw HTTP upload successful!")
            return True
        else:
            logger.error(f"❌ Raw HTTP upload failed: {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Raw HTTP upload error: {e}")
        return False

def process_file_upload(file_id, channel_id, say):
    """Process file upload - shared function for both event types"""
    try:
        # Prevent duplicate processing
        if file_id in processed_files:
            logger.info(f"🔄 File {file_id} already processed, skipping")
            return
        
        processed_files.add(file_id)
        
        logger.info("=" * 50)
        logger.info("📁 PROCESSING FILE UPLOAD (RAW HTTP)")
        logger.info("=" * 50)
        
        # Find van number in recent messages
        van_number = find_van_number_in_recent_messages(channel_id)
        if not van_number:
            logger.info("❌ No van number found, skipping")
            return
        
        logger.info(f"✅ Found van number {van_number} in recent message")
        
        # Get or create van
        van_id = get_or_create_van(van_number)
        if not van_id:
            say(f":x: Failed to create/find van #{van_number}")
            return
        
        # Get file info
        logger.info(f"📷 Processing image for van #{van_number}")
        file_info = app.client.files_info(file=file_id)
        file_data = file_info['file']
        
        # Download file
        logger.info("📥 Downloading image from Slack")
        headers = {'Authorization': f'Bearer {os.environ.get("SLACK_BOT_TOKEN")}'}
        response = requests.get(file_data['url_private_download'], headers=headers)
        
        if response.status_code != 200:
            logger.error(f"❌ Failed to download file: {response.status_code}")
            return
            
        image_data = response.content
        logger.info(f"✅ Successfully downloaded image ({len(image_data)} bytes)")
        
        # Detect content type
        content_type = detect_content_type(image_data)
        logger.info(f"📤 Detected content type: {content_type}")
        
        # Create filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        extension = 'jpg' if content_type == 'image/jpeg' else content_type.split('/')[-1]
        filename = f"image_{timestamp}.{extension}"
        file_path = f"van_{van_number}/{filename}"
        
        logger.info(f"📤 Uploading to path: {file_path}")
        
        # Upload using raw HTTP
        success = upload_image_raw_http(image_data, file_path, content_type)
        
        if success:
            # Create database record
            headers = {
                'apikey': SUPABASE_KEY,
                'Authorization': f'Bearer {SUPABASE_KEY}',
                'Content-Type': 'application/json'
            }
            
            image_record = {
                'van_id': van_id,
                'file_name': filename,
                'file_path': file_path,
                'file_size': len(image_data),
                'content_type': content_type,
                'uploaded_at': datetime.now().isoformat()
            }
            
            db_response = requests.post(
                f"{SUPABASE_URL}/rest/v1/van_images",
                headers=headers,
                json=image_record
            )
            
            if db_response.status_code == 201:
                say(f":white_check_mark: Successfully uploaded image for Van #{van_number}!")
                logger.info(f"✅ Successfully processed image for Van #{van_number}")
            else:
                logger.error(f"❌ Database record creation failed: {db_response.text}")
                say(f":warning: Image uploaded but database record failed for Van #{van_number}")
        else:
            say(f":x: Failed to upload image for Van #{van_number}")
            
    except Exception as e:
        logger.error(f"❌ Error processing file: {e}")
        say(":x: Error processing file upload")

@app.event("file_shared")
def handle_file_shared(event, say):
    """Handle file_shared events"""
    file_id = event['file_id']
    channel_id = event['channel_id']
    logger.info(f"📁 Received file_shared event: {file_id}")
    process_file_upload(file_id, channel_id, say)

@app.event("message")
def handle_message_events(event, say):
    """Handle message events with file_share subtype"""
    if event.get('subtype') == 'file_share' and 'files' in event:
        logger.info(f"📁 Received message with file_share subtype")
        for file_info in event['files']:
            file_id = file_info['id']
            channel_id = event['channel']
            process_file_upload(file_id, channel_id, say)

if __name__ == "__main__":
    logger.info("🚀 Starting SCHEMA FIXED Slack Bot...")
    logger.info("📁 Focus: Correct database schema + duplicate prevention")
    
    # Validate environment
    required_vars = ['SLACK_BOT_TOKEN', 'SLACK_APP_TOKEN', 'SUPABASE_URL', 'SUPABASE_KEY']
    for var in required_vars:
        if not os.environ.get(var):
            logger.error(f"❌ Missing environment variable: {var}")
            exit(1)
        logger.info(f"  - {var}: ✅")
    
    logger.info("✅ Environment validation complete")
    
    # Start the app
    handler = SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"])
    handler.start() 
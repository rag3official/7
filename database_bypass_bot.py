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
    """Detect content type from file signature"""
    if data.startswith(b'\xff\xd8\xff'):
        return 'image/jpeg'
    elif data.startswith(b'\x89PNG'):
        return 'image/png'
    elif data.startswith(b'GIF8'):
        return 'image/gif'
    elif data.startswith(b'RIFF') and b'WEBP' in data[:12]:
        return 'image/webp'
    else:
        return 'image/jpeg'  # Default fallback

def find_van_number_in_text(text):
    """Extract van number from text using multiple patterns"""
    if not text:
        return None
    
    patterns = [
        r'van\s*#?(\d+)',
        r'#(\d+)',
        r'(\d+)'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text.lower())
        if match:
            van_number = int(match.group(1))
            logger.info(f"✅ Found van number using pattern '{pattern}': {van_number}")
            return van_number
    
    return None

def get_recent_messages(client, channel_id, limit=5):
    """Get recent messages from channel to find van number context"""
    try:
        response = client.conversations_history(
            channel=channel_id,
            limit=limit
        )
        
        messages = []
        for msg in response['messages']:
            if 'text' in msg:
                messages.append(msg['text'])
        
        return messages
    except Exception as e:
        logger.error(f"Error getting recent messages: {e}")
        return []

def find_or_create_van(van_number):
    """Find existing van or create new one"""
    try:
        # Look for existing van
        logger.info(f"🔍 Looking for van #{van_number}")
        result = supabase.table('vans').select('*').eq('van_number', van_number).execute()
        
        if result.data:
            logger.info(f"✅ Found existing van: {result.data[0]['id']}")
            return result.data[0]['id']
        
        # Create new van
        logger.info(f"🆕 Creating new van #{van_number}")
        new_van = {
            'van_number': van_number,
            'type': 'Transit',
            'status': 'Active',
            'date': datetime.now().isoformat(),
            'last_updated': datetime.now().isoformat(),
            'notes': f'Created automatically from Slack upload',
            'url': '',
            'driver': '',
            'damage': '',
            'rating': 5,
            'damage_description': '',
            'current_driver_id': None
        }
        
        result = supabase.table('vans').insert(new_van).execute()
        van_id = result.data[0]['id']
        logger.info(f"✅ Created new van: {van_id}")
        return van_id
        
    except Exception as e:
        logger.error(f"❌ Error with van operations: {e}")
        raise

def upload_via_database_function(file_data, file_path, content_type):
    """Upload file using database function to bypass storage constraints"""
    try:
        logger.info(f"🔄 DATABASE FUNCTION upload to: {file_path}")
        logger.info(f"📤 Content-Type: {content_type}")
        logger.info(f"📤 Data size: {len(file_data)} bytes")
        
        # Convert binary data to base64 for database function
        file_data_b64 = base64.b64encode(file_data).decode('utf-8')
        
        # Call the database function to handle upload
        result = supabase.rpc('slack_bot_upload_bypass', {
            'bucket_name': 'van-images',
            'file_path': file_path,
            'file_data': file_data_b64,
            'content_type': content_type
        }).execute()
        
        logger.info(f"📊 Database function result: {result.data}")
        
        if result.data and result.data.get('success'):
            logger.info("✅ Database function upload successful!")
            return True
        else:
            logger.error(f"❌ Database function failed: {result.data}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Database function exception: {e}")
        return False

def get_complete_file_info(client, file_id):
    """Fetch complete file information from Slack API"""
    try:
        logger.info(f"🔍 Fetching complete file info for ID: {file_id}")
        
        response = client.files_info(file=file_id)
        file_info = response['file']
        
        logger.info(f"✅ Retrieved complete file info: {file_info.get('name', 'Unknown')} ({file_info.get('mimetype', 'Unknown')})")
        return file_info
        
    except Exception as e:
        logger.error(f"❌ Error fetching file info: {e}")
        return None

def process_file_upload(client, file_info, channel_id):
    """Process file upload with van number detection"""
    try:
        # Check if it's an image
        mimetype = file_info.get('mimetype', '')
        logger.info(f"📄 File mimetype: {mimetype}")
        
        if not mimetype.startswith('image/'):
            logger.info("⏭️ Skipping non-image file")
            return
        
        # Get recent messages to find van number
        recent_messages = get_recent_messages(client, channel_id)
        combined_text = ' '.join(recent_messages)
        logger.info(f"🔍 Analyzing text for van number: '{combined_text[:100]}...'")
        
        van_number = find_van_number_in_text(combined_text)
        
        if not van_number:
            logger.info("⚠️ No van number found in recent messages")
            client.chat_postMessage(
                channel=channel_id,
                text="⚠️ Please include a van number (e.g., 'van 123') when uploading images"
            )
            return
        
        logger.info(f"✅ Found van number {van_number} in recent message")
        
        # Find or create van
        van_id = find_or_create_van(van_number)
        
        # Process the image
        logger.info(f"📷 Processing image for van #{van_number}")
        
        # Get download URL
        download_url = None
        for url_field in ['url_private_download', 'url_private', 'permalink', 'url']:
            if url_field in file_info and file_info[url_field]:
                download_url = file_info[url_field]
                logger.info(f"✅ Found file URL in field \"{url_field}\": {download_url[:50]}...")
                break
        
        if not download_url:
            logger.error("❌ No download URL found in file info")
            logger.info(f"🔗 File info keys: {list(file_info.keys())}")
            return
        
        # Download the image
        logger.info(f"📥 Downloading image from Slack: {download_url[:50]}...")
        headers = {'Authorization': f'Bearer {os.environ.get("SLACK_BOT_TOKEN")}'}
        response = requests.get(download_url, headers=headers)
        
        if response.status_code != 200:
            logger.error(f"❌ Failed to download image: {response.status_code}")
            return
        
        image_data = response.content
        logger.info(f"✅ Successfully downloaded image ({len(image_data)} bytes)")
        
        # Detect content type
        content_type = detect_content_type(image_data)
        logger.info(f"📤 Detected content type: {content_type}")
        
        # Generate file path
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        extension = content_type.split('/')[-1]
        file_path = f"van_{van_number}/image_{timestamp}.{extension}"
        logger.info(f"📤 Uploading to path: {file_path}")
        
        # Upload using database function
        upload_success = upload_via_database_function(image_data, file_path, content_type)
        
        if upload_success:
            # Send success message
            client.chat_postMessage(
                channel=channel_id,
                text=f"✅ Successfully uploaded image for van {van_number}!"
            )
            logger.info("💬 Sent success message to channel")
        else:
            # Send failure message
            client.chat_postMessage(
                channel=channel_id,
                text=f":x: Failed to upload image for van {van_number}"
            )
            logger.error("❌ Upload failed")
            
    except Exception as e:
        logger.error(f"❌ Error processing file upload: {e}")
        try:
            client.chat_postMessage(
                channel=channel_id,
                text=f":x: Error processing image upload: {str(e)}"
            )
        except:
            pass

@app.event("file_shared")
def handle_file_shared(event, client):
    """Handle file_shared events"""
    try:
        logger.info("📁 Received file_shared event")
        logger.info(f"📁 Event data: {event}")
        
        file_id = event.get('file_id')
        channel_id = event.get('channel_id')
        
        logger.info(f"📁 Processing file from file_shared event")
        logger.info(f"📁 File ID: {file_id}")
        logger.info(f"📁 Channel ID: {channel_id}")
        
        # Get complete file information
        file_info = get_complete_file_info(client, file_id)
        if not file_info:
            logger.error("❌ Could not retrieve file information")
            return
        
        process_file_upload(client, file_info, channel_id)
        
    except Exception as e:
        logger.error(f"❌ Error in file_shared handler: {e}")

@app.event("message")
def handle_message_events(event, client):
    """Handle message events that might contain file uploads"""
    try:
        if event.get('subtype') == 'file_share' and 'files' in event:
            logger.info("📁 Received file_share message event")
            
            channel_id = event.get('channel')
            files = event.get('files', [])
            
            for file_info in files:
                logger.info(f"📁 Processing file from message event: {file_info.get('name', 'Unknown')}")
                process_file_upload(client, file_info, channel_id)
                
    except Exception as e:
        logger.error(f"❌ Error in message handler: {e}")

if __name__ == "__main__":
    logger.info("🚀 Starting DATABASE BYPASS Slack Bot...")
    logger.info("📁 Focus: Use database functions to bypass storage constraints")
    
    # Check environment variables
    required_vars = ['SLACK_BOT_TOKEN', 'SLACK_APP_TOKEN', 'SUPABASE_URL', 'SUPABASE_KEY']
    missing_vars = [var for var in required_vars if not os.environ.get(var)]
    
    if missing_vars:
        logger.error(f"❌ Missing environment variables: {missing_vars}")
        exit(1)
    
    logger.info("✅ All environment variables found")
    
    # Start the app
    logger.info("🚀 Starting Slack bot with Socket Mode...")
    handler = SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"])
    handler.start() 
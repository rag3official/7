#!/usr/bin/env python3

import os
import json
import logging
import re
import requests
from datetime import datetime
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from supabase import create_client, Client

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

logger.info('🚀 Starting OWNER FIXED UPLOAD Slack Bot...')
logger.info('📁 Focus: Set owner/owner_id to satisfy database constraints')

# Environment validation
required_vars = ['SLACK_BOT_TOKEN', 'SLACK_APP_TOKEN', 'SUPABASE_URL', 'SUPABASE_KEY']
for var in required_vars:
    if not os.getenv(var):
        logger.error(f'❌ Missing environment variable: {var}')
        exit(1)

logger.info('✅ All environment variables found')

# Initialize Slack app
app = App(token=os.environ.get("SLACK_BOT_TOKEN"))

# Initialize Supabase client  
supabase: Client = create_client(os.environ.get("SUPABASE_URL"), os.environ.get("SUPABASE_KEY"))

# Storage bucket name
STORAGE_BUCKET = "van-images"

# Track processed files to avoid duplicates
processed_files = set()

def detect_content_type(data):
    """Detect content type from file data"""
    if data.startswith(b'\x89PNG'):
        return 'image/png'
    elif data.startswith(b'\xff\xd8\xff'):
        return 'image/jpeg'
    elif data.startswith(b'GIF8'):
        return 'image/gif'
    elif data.startswith(b'\x00\x00\x00\x20ftypheic') or data.startswith(b'\x00\x00\x00\x18ftypheic'):
        return 'image/heic'
    else:
        return 'application/octet-stream'

def find_van_number_in_text(text):
    """Extract van number from text using multiple patterns"""
    if not text:
        return None
    
    logger.info(f'🔍 Analyzing text for van number: {repr(text)}')
    
    # Multiple patterns to match van numbers
    patterns = [
        r'van\s*#?(\d+)',  # "van 123", "van #123", "van123"
        r'#(\d+)',         # "#123"
        r'(\d+)',          # Just numbers as fallback
    ]
    
    text_lower = text.lower()
    for pattern in patterns:
        matches = re.findall(pattern, text_lower, re.IGNORECASE)
        if matches:
            van_number = matches[0]
            logger.info(f'✅ Found van number using pattern {repr(pattern)}: {van_number}')
            return van_number
    
    logger.info('❌ No van number found in text')
    return None

def get_recent_messages(client, channel_id, limit=10):
    """Get recent messages from channel to find van number"""
    try:
        result = client.conversations_history(channel=channel_id, limit=limit)
        messages = result.get('messages', [])
        
        for message in messages:
            text = message.get('text', '')
            van_number = find_van_number_in_text(text)
            if van_number:
                logger.info(f'✅ Found van number {van_number} in recent message')
                return van_number
        
        logger.info('❌ No van number found in recent messages')
        return None
    except Exception as e:
        logger.error(f'❌ Error getting recent messages: {e}')
        return None

def get_or_create_van(van_number):
    """Get existing van or create new one"""
    try:
        logger.info(f'🔍 Looking for van #{van_number}')
        
        # Try to find existing van
        response = supabase.table('vans').select('*').eq('van_number', van_number).execute()
        
        if response.data:
            van = response.data[0]
            logger.info(f'✅ Found existing van: {van["id"]}')
            return van
        
        # Create new van with minimal required fields
        logger.info(f'🆕 Creating new van #{van_number}')
        new_van = {
            'van_number': van_number,
            'type': 'Unknown',
            'status': 'Active',
            'date': datetime.now().isoformat(),
            'notes': f'Auto-created from Slack upload'
        }
        
        response = supabase.table('vans').insert(new_van).execute()
        if response.data:
            van = response.data[0]
            logger.info(f'✅ Created new van: {van["id"]}')
            return van
        else:
            logger.error(f'❌ Failed to create van: {response}')
            return None
            
    except Exception as e:
        logger.error(f'❌ Error with van {van_number}: {e}')
        return None

def fetch_complete_file_info(client, file_id):
    """Fetch complete file information using Slack API"""
    try:
        logger.info(f'🔍 Fetching complete file info for ID: {file_id}')
        response = client.files_info(file=file_id)
        
        if response['ok']:
            file_info = response['file']
            logger.info(f'✅ Retrieved complete file info: {file_info.get("name", "unknown")} ({file_info.get("mimetype", "unknown")})')
            return file_info
        else:
            logger.error(f'❌ Failed to fetch file info: {response.get("error")}')
            return None
    except Exception as e:
        logger.error(f'❌ Error fetching file info: {e}')
        return None

def is_file_info_minimal(file_info):
    """Check if file info is minimal (only has ID)"""
    if not file_info:
        return True
    
    # If it only has 'id' or very few fields, it's minimal
    if len(file_info.keys()) <= 2:
        return True
    
    # Check for key fields that indicate complete info
    required_fields = ['mimetype', 'url_private', 'url_private_download']
    return not any(field in file_info for field in required_fields)

def upload_to_supabase_with_owner(file_data, file_path, content_type, slack_user_id):
    """Upload file to Supabase with owner information to satisfy constraints"""
    try:
        logger.info(f'🌐 OWNER-BASED upload to: {file_path}')
        logger.info(f'📤 Content-Type: {content_type}')
        logger.info(f'📤 Data size: {len(file_data)} bytes')
        logger.info(f'👤 Slack User ID: {slack_user_id}')
        
        # Use Slack user ID as owner to satisfy database constraints
        url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/{STORAGE_BUCKET}/{file_path}"
        
        headers = {
            'Authorization': f'Bearer {os.environ.get("SUPABASE_KEY")}',
            'Content-Type': content_type,
            'x-upsert': 'true',
            # Add owner information to satisfy database constraints
            'x-owner': slack_user_id,
            'x-owner-id': slack_user_id,
        }
        
        logger.info(f'🔗 Upload URL: {url}')
        logger.info(f'📋 Headers: {headers}')
        
        response = requests.post(url, data=file_data, headers=headers)
        
        logger.info(f'📊 Response status: {response.status_code}')
        logger.info(f'📊 Response headers: {dict(response.headers)}')
        
        if response.status_code in [200, 201]:
            logger.info('✅ Upload successful!')
            return True
        else:
            logger.error(f'❌ Upload failed: {response.status_code}')
            logger.error(f'❌ Response text: {response.text}')
            return False
            
    except Exception as e:
        logger.error(f'❌ Upload exception: {e}')
        return False

def create_van_image_record(van_id, file_path, original_filename):
    """Create record in van_images table"""
    try:
        image_record = {
            'van_id': van_id,
            'image_path': file_path,
            'filename': original_filename,
            'uploaded_at': datetime.now().isoformat(),
            'source': 'slack'
        }
        
        response = supabase.table('van_images').insert(image_record).execute()
        if response.data:
            logger.info(f'✅ Created image record: {response.data[0]["id"]}')
            return True
        else:
            logger.error(f'❌ Failed to create image record: {response}')
            return False
    except Exception as e:
        logger.error(f'❌ Error creating image record: {e}')
        return False

def send_slack_message(client, channel, message):
    """Send message to Slack channel"""
    try:
        client.chat_postMessage(channel=channel, text=message)
        logger.info(f'💬 Sent message to channel: {message}')
    except Exception as e:
        logger.error(f'❌ Failed to send message: {e}')

def process_file_upload(client, file_info, channel_id, event_source="unknown"):
    """Process file upload with owner-based constraints"""
    try:
        file_id = file_info.get('id')
        
        # Skip if already processed
        if file_id in processed_files:
            logger.info(f'⏭️ File {file_id} already processed, skipping')
            return
        
        # Check if file info is minimal and fetch complete info if needed
        if is_file_info_minimal(file_info):
            logger.info('🔄 File info is minimal, fetching complete details...')
            complete_file_info = fetch_complete_file_info(client, file_id)
            if complete_file_info:
                file_info = complete_file_info
            else:
                logger.error('❌ Could not fetch complete file info')
                return
        
        # Check if it's an image
        mimetype = file_info.get('mimetype', '')
        logger.info(f'📄 File mimetype: {mimetype}')
        
        if not mimetype.startswith('image/'):
            logger.info(f'⏭️ Skipping non-image file: {mimetype}')
            return
        
        # Mark as processed
        processed_files.add(file_id)
        
        # Find van number from recent messages
        van_number = get_recent_messages(client, channel_id)
        if not van_number:
            error_msg = f":x: Van number not found in recent messages."
            send_slack_message(client, channel_id, error_msg)
            logger.error(error_msg)
            return
        
        # Get or create van
        van = get_or_create_van(van_number)
        if not van:
            error_msg = f":x: Van {van_number} not found in database."
            send_slack_message(client, channel_id, error_msg)
            logger.error(error_msg)
            return
        
        logger.info(f'📷 Processing image for van #{van_number}')
        
        # Find download URL
        logger.info(f'🔗 File info keys: {list(file_info.keys())}')
        
        download_url = None
        for url_field in ['url_private_download', 'url_private']:
            if url_field in file_info and file_info[url_field]:
                download_url = file_info[url_field]
                logger.info(f'✅ Found file URL in field "{url_field}": {download_url[:50]}...')
                break
        
        if not download_url:
            error_msg = f":x: No download URL found for image"
            send_slack_message(client, channel_id, error_msg)
            logger.error(error_msg)
            return
        
        # Download image
        logger.info(f'📥 Downloading image from Slack: {download_url[:50]}...')
        headers = {'Authorization': f'Bearer {os.environ.get("SLACK_BOT_TOKEN")}'}
        response = requests.get(download_url, headers=headers)
        
        if response.status_code != 200:
            error_msg = f":x: Failed to download image: {response.status_code}"
            send_slack_message(client, channel_id, error_msg)
            logger.error(error_msg)
            return
        
        image_data = response.content
        logger.info(f'✅ Successfully downloaded image ({len(image_data)} bytes)')
        
        # Detect content type
        detected_content_type = detect_content_type(image_data)
        content_type = mimetype if mimetype.startswith('image/') else detected_content_type
        logger.info(f'📤 Detected content type: {content_type}')
        
        # Generate filename
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        extension = content_type.split('/')[-1] if '/' in content_type else 'jpg'
        filename = f'image_{timestamp}.{extension}'
        file_path = f'van_{van_number}/{filename}'
        
        logger.info(f'📤 Uploading to path: {file_path}')
        
        # Get Slack user ID for owner constraint
        slack_user_id = file_info.get('user', 'unknown')
        
        # Upload to Supabase with owner information
        if upload_to_supabase_with_owner(image_data, file_path, content_type, slack_user_id):
            # Create database record
            if create_van_image_record(van['id'], file_path, file_info.get('name', filename)):
                success_msg = f":white_check_mark: Successfully uploaded image for van {van_number}!"
                send_slack_message(client, channel_id, success_msg)
                logger.info('✅ Complete upload process successful!')
            else:
                error_msg = f":warning: Image uploaded but failed to create database record"
                send_slack_message(client, channel_id, error_msg)
        else:
            error_msg = f":x: Failed to upload image for van {van_number}"
            send_slack_message(client, channel_id, error_msg)
            logger.error('❌ Upload failed')
            
    except Exception as e:
        logger.error(f'❌ Error processing file upload: {e}')
        error_msg = f":x: Error processing image upload: {str(e)}"
        send_slack_message(client, channel_id, error_msg)

# Event handlers
@app.event("file_created")
def handle_file_created(event, client):
    """Handle file_created events"""
    try:
        logger.info('📁 Received file_created event')
        logger.info(f'📁 Event data: {json.dumps(event, indent=2)}...')
        
        file_info = event.get('file', {})
        # For file_created, we might need to find the channel from file's channels
        channels = file_info.get('channels', [])
        channel_id = channels[0] if channels else None
        
        if not channel_id:
            logger.info('⏭️ No channel found for file_created event')
            return
        
        logger.info(f'📁 Processing file from file_created event')
        logger.info(f'📁 File ID: {file_info.get("id")}')
        logger.info(f'📁 Channel ID: {channel_id}')
        
        process_file_upload(client, file_info, channel_id, "file_created")
        
    except Exception as e:
        logger.error(f'❌ Error in file_created handler: {e}')

@app.event("file_shared") 
def handle_file_shared(event, client):
    """Handle file_shared events"""
    try:
        logger.info('📁 Received file_shared event')
        logger.info(f'📁 Event data: {json.dumps(event, indent=2)}...')
        
        file_info = event.get('file', {})
        channel_id = event.get('channel_id')
        
        logger.info(f'📁 Processing file from file_shared event')
        logger.info(f'📁 File ID: {file_info.get("id")}')
        logger.info(f'📁 Channel ID: {channel_id}')
        
        process_file_upload(client, file_info, channel_id, "file_shared")
        
    except Exception as e:
        logger.error(f'❌ Error in file_shared handler: {e}')

@app.event("message")
def handle_message_with_files(event, client):
    """Handle message events that contain files"""
    try:
        # Only handle messages with file_share subtype
        if event.get('subtype') != 'file_share':
            return
            
        logger.info('📁 Received message with file_share subtype')
        logger.info('=' * 50)
        logger.info('📁 PROCESSING FILE UPLOAD (MESSAGE EVENT)')
        logger.info('=' * 50)
        logger.info(f'📁 Message data: {json.dumps(event, indent=2)}...')
        
        files = event.get('files', [])
        channel_id = event.get('channel')
        
        for file_info in files:
            logger.info(f'📁 Processing file from message event')
            logger.info(f'📁 File ID: {file_info.get("id")}')
            logger.info(f'📁 Channel ID: {channel_id}')
            
            process_file_upload(client, file_info, channel_id, "message")
        
    except Exception as e:
        logger.error(f'❌ Error in message handler: {e}')

if __name__ == "__main__":
    logger.info('🚀 Starting Slack bot with Socket Mode...')
    handler = SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"])
    handler.start() 
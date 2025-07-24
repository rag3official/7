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

logger.info('🚀 Starting ENHANCED FILE FETCH Slack Bot...')
logger.info('📁 Focus: Fetch complete file info when only ID is available')

# Environment validation
required_vars = ['SLACK_BOT_TOKEN', 'SLACK_APP_TOKEN', 'SUPABASE_URL', 'SUPABASE_KEY']
for var in required_vars:
    if not os.getenv(var):
        logger.error(f'❌ Missing environment variable: {var}')
        exit(1)
    logger.info(f'  - {var}: ✅')

logger.info('✅ Environment validation complete')

# Initialize Slack app
app = App(token=os.environ.get('SLACK_BOT_TOKEN'))

# Initialize Supabase client
SUPABASE_URL = os.environ.get('SUPABASE_URL')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY')
STORAGE_BUCKET = 'van-images'

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
logger.info('✅ Supabase client initialized')

# Track processed files to avoid duplicates
processed_files = set()

def get_complete_file_info(client, file_id):
    """Fetch complete file information from Slack API"""
    try:
        logger.info(f'🔍 Fetching complete file info for ID: {file_id}')
        response = client.files_info(file=file_id)
        
        if response['ok']:
            file_info = response['file']
            logger.info(f'✅ Retrieved complete file info: {file_info.get("name", "unknown")} ({file_info.get("mimetype", "unknown")})')
            return file_info
        else:
            logger.error(f'❌ Failed to fetch file info: {response.get("error", "unknown error")}')
            return None
            
    except Exception as e:
        logger.error(f'❌ Error fetching file info: {e}')
        return None

def detect_content_type(data):
    """Detect content type from file signature"""
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        return 'image/png', '.png'
    elif data.startswith(b'\xff\xd8\xff'):
        return 'image/jpeg', '.jpg'
    elif data.startswith(b'GIF87a') or data.startswith(b'GIF89a'):
        return 'image/gif', '.gif'
    elif data.startswith(b'RIFF') and b'WEBP' in data[:12]:
        return 'image/webp', '.webp'
    else:
        return 'application/octet-stream', '.bin'

def extract_van_number_from_messages(client, channel_id, limit=10):
    """Extract van number from recent messages in the channel"""
    try:
        response = client.conversations_history(channel=channel_id, limit=limit)
        
        van_patterns = [
            r'van\s*#?(\d+)',
            r'vehicle\s*#?(\d+)', 
            r'#(\d+)',
            r'(\d{3,4})'  # 3-4 digit numbers
        ]
        
        for message in response['messages']:
            text = message.get('text', '').lower()
            logger.info(f'🔍 Analyzing text for van number: \'{text}\'')
            
            for pattern in van_patterns:
                match = re.search(pattern, text, re.IGNORECASE)
                if match:
                    van_number = match.group(1)
                    logger.info(f'✅ Found van number using pattern \'{pattern}\': {van_number}')
                    return van_number
        
        logger.warning('⚠️ No van number found in recent messages')
        return None
        
    except Exception as e:
        logger.error(f'❌ Error fetching messages: {e}')
        return None

def get_or_create_van(van_number):
    """Get existing van or create new one"""
    try:
        logger.info(f'🔍 Looking for van #{van_number}')
        
        # Check if van exists
        result = supabase.table('vans').select('*').eq('van_number', van_number).execute()
        
        if result.data:
            logger.info(f'✅ Found existing van: {result.data[0]["id"]}')
            return result.data[0]['id']
        
        # Create new van
        logger.info(f'🆕 Creating new van #{van_number}')
        van_data = {
            'van_number': van_number,
            'type': 'Unknown',
            'status': 'Active',
            'created_at': datetime.now().isoformat()
        }
        
        result = supabase.table('vans').insert(van_data).execute()
        
        if result.data:
            van_id = result.data[0]['id']
            logger.info(f'✅ Created new van: {van_id}')
            return van_id
        else:
            logger.error(f'❌ Failed to create van: {result}')
            return None
            
    except Exception as e:
        logger.error(f'❌ Error with van operations: {e}')
        return None

def process_file_upload(client, file_info, channel_id=None, event_type="unknown"):
    """Process file upload with enhanced error handling"""
    try:
        file_id = file_info.get('id')
        
        # Avoid duplicate processing
        if file_id in processed_files:
            logger.info(f'⏭️ File {file_id} already processed, skipping')
            return
        
        processed_files.add(file_id)
        
        logger.info(f'📁 Processing file from {event_type} event')
        logger.info(f'📁 File ID: {file_id}')
        logger.info(f'📁 Channel ID: {channel_id}')
        
        # If file_info is minimal (only has ID), fetch complete info
        if len(file_info.keys()) <= 2:  # Only has 'id' and maybe one other field
            logger.info('🔄 File info is minimal, fetching complete details...')
            complete_file_info = get_complete_file_info(client, file_id)
            if complete_file_info:
                file_info = complete_file_info
            else:
                logger.error('❌ Failed to fetch complete file info')
                return
        
        # Check if it's an image
        mimetype = file_info.get('mimetype', '')
        logger.info(f'📄 File mimetype: {mimetype}')
        
        if not mimetype.startswith('image/'):
            logger.info(f'⏭️ Skipping non-image file: {mimetype}')
            return
        
        # Extract van number from channel messages
        van_number = None
        if channel_id:
            van_number = extract_van_number_from_messages(client, channel_id)
        
        if not van_number:
            logger.warning('⚠️ No van number found, cannot process image')
            return
        
        logger.info(f'✅ Found van number {van_number} in recent message')
        
        # Get or create van
        van_id = get_or_create_van(van_number)
        if not van_id:
            logger.error('❌ Failed to get/create van')
            return
        
        # Process image
        logger.info(f'📷 Processing image for van #{van_number}')
        
        # Find download URL
        download_url = None
        url_fields = ['url_private_download', 'url_private', 'permalink_public']
        
        logger.info(f'🔗 File info keys: {list(file_info.keys())}')
        
        for field in url_fields:
            if field in file_info and file_info[field]:
                download_url = file_info[field]
                logger.info(f'✅ Found file URL in field "{field}": {download_url[:50]}...')
                break
        
        if not download_url:
            logger.error('❌ No download URL found')
            return
        
        # Download file
        logger.info(f'📥 Downloading image from Slack: {download_url[:50]}...')
        headers = {'Authorization': f'Bearer {os.environ.get("SLACK_BOT_TOKEN")}'}
        response = requests.get(download_url, headers=headers)
        
        if response.status_code != 200:
            logger.error(f'❌ Failed to download file: {response.status_code}')
            return
        
        image_data = response.content
        logger.info(f'✅ Successfully downloaded image ({len(image_data)} bytes)')
        
        # Detect content type
        detected_content_type, extension = detect_content_type(image_data)
        logger.info(f'📤 Detected content type: {detected_content_type}')
        
        # Create filename
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f'image_{timestamp}{extension}'
        file_path = f'van_{van_number}/{filename}'
        
        logger.info(f'📤 Uploading to path: {file_path}')
        
        # Upload with simplified options
        try:
            logger.info(f'📤 SUPABASE CLIENT upload to: {file_path}')
            logger.info(f'📤 Content-Type: {detected_content_type}')
            logger.info(f'📤 Data size: {len(image_data)} bytes')
            
            # Use minimal file_options to avoid parameter issues
            file_options = {
                'content-type': detected_content_type
            }
            
            result = supabase.storage.from_(STORAGE_BUCKET).upload(
                path=file_path,
                file=image_data,
                file_options=file_options
            )
            
            logger.info(f'✅ Upload successful: {result}')
            
            # Create database record
            try:
                db_data = {
                    'van_id': van_id,
                    'image_url': f'{SUPABASE_URL}/storage/v1/object/public/{STORAGE_BUCKET}/{file_path}',
                    'filename': filename,
                    'file_path': file_path,
                    'upload_date': datetime.now().isoformat()
                }
                
                result = supabase.table('van_images').insert(db_data).execute()
                
                if result.data:
                    logger.info('✅ Database record created successfully')
                    logger.info(f'🎉 SUCCESS: Image uploaded for van #{van_number}')
                    logger.info(f'🌐 Image URL: {db_data["image_url"]}')
                    
                    # Send success message to channel
                    try:
                        client.chat_postMessage(
                            channel=channel_id,
                            text=f"✅ Successfully uploaded image for van #{van_number}!"
                        )
                    except Exception as e:
                        logger.warning(f'⚠️ Could not send success message: {e}')
                        
                else:
                    logger.error(f'❌ Failed to create database record: {result}')
            except Exception as e:
                logger.error(f'❌ Database record error: {e}')
                
        except Exception as e:
            logger.error(f'❌ Upload exception: {e}')
            # Send error message to channel
            try:
                client.chat_postMessage(
                    channel=channel_id,
                    text=f"❌ Van {van_number} not found in database."
                )
            except Exception as msg_error:
                logger.warning(f'⚠️ Could not send error message: {msg_error}')
        
    except Exception as e:
        logger.error(f'❌ Error processing file upload: {e}')

# Event handlers
@app.event('file_created')
def handle_file_created(event, client):
    logger.info('📁 Received file_created event')
    logger.info(f'📁 Event data: {json.dumps(event, indent=2)[:500]}...')
    file_info = event.get('file', {})
    # file_created events don't have channel_id, we'll try to find it from shares
    channel_id = None
    if 'channels' in file_info and file_info['channels']:
        channel_id = file_info['channels'][0]
    process_file_upload(client, file_info, channel_id, "file_created")

@app.event('file_shared')
def handle_file_shared(event, client):
    logger.info('📁 Received file_shared event')
    logger.info(f'📁 Event data: {json.dumps(event, indent=2)[:500]}...')
    file_info = event.get('file', {})
    channel_id = event.get('channel_id')
    process_file_upload(client, file_info, channel_id, "file_shared")

@app.event('message')
def handle_message_with_file(message, client):
    if message.get('subtype') == 'file_share':
        logger.info('📁 Received message with file_share subtype')
        logger.info('=' * 50)
        logger.info('📁 PROCESSING FILE UPLOAD (MESSAGE EVENT)')
        logger.info('=' * 50)
        logger.info(f'📁 Message data: {json.dumps(message, indent=2)[:500]}...')
        
        files = message.get('files', [])
        channel_id = message.get('channel')
        
        for file_info in files:
            if file_info.get('mimetype', '').startswith('image/'):
                process_file_upload(client, file_info, channel_id, "message")

if __name__ == '__main__':
    handler = SocketModeHandler(app, os.environ['SLACK_APP_TOKEN'])
    handler.start() 
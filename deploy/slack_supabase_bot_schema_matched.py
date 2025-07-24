#!/usr/bin/env python3
"""
Slack Bot for Van Damage Assessment - SCHEMA MATCHED VERSION
Uses only columns that actually exist in the database
"""

import os
import re
import json
import base64
import io
import logging
from datetime import datetime
from typing import Optional, Dict, Any, Tuple

import requests
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from supabase import create_client, Client
from anthropic import Anthropic
from PIL import Image

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Initialize Slack app
app = App(token=os.environ.get("SLACK_BOT_TOKEN"))

# Initialize Supabase client
supabase_url = os.environ.get("SUPABASE_URL")
supabase_key = os.environ.get("SUPABASE_KEY")
supabase: Client = create_client(supabase_url, supabase_key)

# Initialize Anthropic client
anthropic = Anthropic(api_key=os.environ.get("CLAUDE_API_KEY"))

def get_or_create_van(van_number: int) -> Optional[str]:
    """Get existing van or create new one using actual schema"""
    try:
        logger.info(f"🔍 Looking for van #{van_number}")
        
        # Try to find existing van
        result = supabase.table('vans').select('*').eq('van_number', van_number).execute()
        
        if result.data:
            van_id = result.data[0]['id']
            logger.info(f"✅ Found existing van: {van_id}")
            return van_id
        
        # Create new van with actual schema
        logger.info(f"🆕 Creating new van #{van_number} with actual schema")
        new_van = {
            'van_number': van_number,
            'make': 'Unknown',
            'model': 'Transit',
            'year': 2020,
            'status': 'Active',
            'color': 'White',
            'location': 'Fleet',
            'notes': f'Van #{van_number} created via Slack bot'
        }
        
        result = supabase.table('vans').insert(new_van).execute()
        
        if result.data:
            van_id = result.data[0]['id']
            logger.info(f"✅ Created new van: {van_id}")
            return van_id
        else:
            logger.error(f"❌ Failed to create van: {result}")
            return None
            
    except Exception as e:
        logger.error(f"❌ Error in get_or_create_van: {e}")
        return None

def store_van_image(van_id: str, van_number: int, image_data: bytes, file_name: str, content_type: str, user_id: str) -> bool:
    """Store van image in database"""
    try:
        # Convert image to base64
        base64_data = base64.b64encode(image_data).decode('utf-8')
        data_url = f"data:{content_type};base64,{base64_data}"
        
        logger.info(f"📤 Converted to base64 ({len(base64_data)} characters)")
        
        # Create file path
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        file_path = f"van_{van_number}/image_{timestamp}.jpg"
        
        logger.info(f"💾 Storing in database with path reference: {file_path}")
        
        # Store in van_images table
        image_record = {
            'van_id': van_id,
            'van_number': van_number,
            'image_url': data_url,
            'file_path': file_path,
            'file_size': len(image_data),
            'content_type': content_type,
            'van_damage': 'No damage description',
            'upload_method': 'slack_bot',
            'upload_source': 'slack',
            'image_data': base64_data
        }
        
        result = supabase.table('van_images').insert(image_record).execute()
        
        if result.data:
            logger.info(f"✅ Image stored successfully in database")
            logger.info(f"📊 Database record ID: {result.data[0]['id']}")
            return True
        else:
            logger.error(f"❌ Failed to store image: {result}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error processing and storing image: {e}")
        return False

def extract_van_number_from_messages(channel_id: str, file_ts: str) -> Optional[int]:
    """Extract van number from recent messages"""
    try:
        # Get recent messages from the channel
        result = app.client.conversations_history(
            channel=channel_id,
            oldest=str(float(file_ts) - 300),  # 5 minutes before file
            latest=str(float(file_ts) + 60),   # 1 minute after file
            limit=20
        )
        
        # Look for van number patterns
        van_patterns = [
            r'van\s*#?(\d+)',
            r'#(\d+)',
            r'(\d+)',
        ]
        
        for message in result['messages']:
            text = message.get('text', '').lower()
            logger.info(f"🔍 Analyzing text for van number: '{text}'")
            
            for pattern in van_patterns:
                match = re.search(pattern, text, re.IGNORECASE)
                if match:
                    van_number = int(match.group(1))
                    logger.info(f"✅ Found van number using pattern '{pattern}': {van_number}")
                    return van_number
        
        logger.warning("⚠️ No van number found in recent messages")
        return None
        
    except Exception as e:
        logger.error(f"❌ Error extracting van number: {e}")
        return None

def process_image_file(file_info: Dict[str, Any], channel_id: str) -> bool:
    """Process uploaded image file"""
    try:
        file_name = file_info.get('name', 'unknown')
        file_ts = file_info.get('timestamp', str(datetime.now().timestamp()))
        
        # Extract van number from messages
        van_number = extract_van_number_from_messages(channel_id, file_ts)
        if not van_number:
            logger.error("❌ Could not determine van number")
            return False
        
        # Get or create van
        van_id = get_or_create_van(van_number)
        if not van_id:
            logger.error("❌ Could not get or create van")
            return False
        
        logger.info(f"📷 Processing image for van #{van_number}")
        
        # Find download URL
        download_url = None
        for field in ['url_private_download', 'url_private']:
            if field in file_info:
                download_url = file_info[field]
                logger.info(f"✅ Found file URL in field \"{field}\": {download_url[:50]}...")
                break
        
        if not download_url:
            logger.error("❌ No download URL found")
            return False
        
        # Download image
        logger.info(f"📥 Downloading image from Slack: {download_url[:50]}...")
        headers = {'Authorization': f'Bearer {os.environ.get("SLACK_BOT_TOKEN")}'}
        response = requests.get(download_url, headers=headers)
        
        if response.status_code != 200:
            logger.error(f"❌ Failed to download image: {response.status_code}")
            return False
        
        image_data = response.content
        logger.info(f"✅ Successfully downloaded image ({len(image_data)} bytes)")
        
        # Store image
        content_type = file_info.get('mimetype', 'image/jpeg')
        user_id = file_info.get('user', 'unknown')
        
        success = store_van_image(van_id, van_number, image_data, file_name, content_type, user_id)
        
        if success:
            # Send success message
            app.client.chat_postMessage(
                channel=channel_id,
                text=f"✅ Successfully processed image for van #{van_number}"
            )
            logger.info("✅ Image processing completed successfully")
            return True
        else:
            # Send error message
            app.client.chat_postMessage(
                channel=channel_id,
                text=f"❌ Failed to process image for van #{van_number}"
            )
            logger.error("❌ Image processing failed")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error processing image file: {e}")
        return False

@app.event("file_shared")
def handle_file_shared(event, say):
    """Handle file shared events"""
    try:
        logger.info("📁 Received file_shared event")
        logger.info(f"📁 Event data: {json.dumps(event, indent=2)[:500]}...")
        
        file_id = event.get('file_id')
        channel_id = event.get('channel_id')
        
        logger.info(f"📁 Processing file from file_shared event")
        logger.info(f"📁 File ID: {file_id}")
        logger.info(f"📁 Channel ID: {channel_id}")
        
        # Get complete file info
        logger.info("🔍 Fetching complete file info for ID: {}".format(file_id))
        file_info = app.client.files_info(file=file_id)['file']
        
        file_name = file_info.get('name', 'unknown')
        mimetype = file_info.get('mimetype', '')
        
        logger.info(f"✅ Retrieved complete file info: {file_name} ({mimetype})")
        logger.info(f"📄 File mimetype: {mimetype}")
        
        # Process only image files
        if mimetype.startswith('image/'):
            process_image_file(file_info, channel_id)
        else:
            logger.info(f"⏭️ Skipping non-image file: {mimetype}")
            
    except Exception as e:
        logger.error(f"❌ Error handling file_shared event: {e}")

@app.event("message")
def handle_message_events(event, say):
    """Handle message events"""
    logger.info("📝 Message event received")

if __name__ == "__main__":
    logger.info("🚀 Starting SCHEMA MATCHED Slack Bot...")
    logger.info("📁 Focus: Use actual database schema columns")
    
    # Verify environment variables
    required_env_vars = [
        "SLACK_BOT_TOKEN",
        "SLACK_APP_TOKEN", 
        "SUPABASE_URL",
        "SUPABASE_KEY",
        "CLAUDE_API_KEY"
    ]
    
    missing_vars = [var for var in required_env_vars if not os.environ.get(var)]
    if missing_vars:
        logger.error(f"❌ Missing environment variables: {missing_vars}")
        exit(1)
    
    logger.info("✅ All environment variables found")
    
    # Start the app
    logger.info("🚀 Starting Slack bot with Socket Mode...")
    handler = SocketModeHandler(app, os.environ.get("SLACK_APP_TOKEN"))
    handler.start() 
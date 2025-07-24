#!/usr/bin/env python3
"""
Slack Bot for Van Damage Assessment - MINIMAL SCHEMA VERSION
Uses only the most basic columns to avoid schema cache issues
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

# Initialize Claude AI client
claude_client = Anthropic(api_key=os.environ.get("CLAUDE_API_KEY"))

def extract_van_number(message_text: str) -> Optional[str]:
    """Extract van number from message text."""
    patterns = [r'van\s*#?(\d+)', r'vehicle\s*#?(\d+)', r'#(\d+)']
    for pattern in patterns:
        match = re.search(pattern, message_text.lower())
        if match:
            return match.group(1)
    return None

def get_or_create_van(van_number: str) -> Tuple[str, Dict[str, Any]]:
    """Get existing van or create new one - MINIMAL SCHEMA VERSION."""
    try:
        # Try to get existing van
        result = supabase.table('vans').select('*').eq('van_number', van_number).execute()
        
        if result.data and len(result.data) > 0:
            logger.info(f"✅ Found existing van #{van_number}")
            return 'existing', result.data[0]
        
        # Create new van with MINIMAL schema (only essential columns)
        new_van = {
            'van_number': van_number,
            'type': 'Transit',
            'status': 'Active'
        }
        
        logger.info(f"🆕 Creating new van #{van_number} with minimal schema: {list(new_van.keys())}")
        create_result = supabase.table('vans').insert(new_van).execute()
        
        if create_result.data:
            logger.info(f"✅ Successfully created van #{van_number}")
            return 'new', create_result.data[0]
        else:
            raise Exception(f"Failed to create van: {create_result}")
            
    except Exception as e:
        logger.error(f"❌ Error in get_or_create_van: {e}")
        raise

def assess_damage_with_claude(image_data: bytes, filename: str) -> Dict[str, Any]:
    """Analyze image with Claude AI for damage assessment."""
    try:
        logger.info(f"🔍 Analyzing image with Claude AI: {filename}")
        
        # Convert to JPEG for Claude AI
        image = Image.open(io.BytesIO(image_data))
        
        # Convert to RGB if necessary
        if image.mode in ('RGBA', 'LA', 'P'):
            background = Image.new('RGB', image.size, (255, 255, 255))
            if image.mode == 'P':
                image = image.convert('RGBA')
            background.paste(image, mask=image.split()[-1] if image.mode in ('RGBA', 'LA') else None)
            image = background
        
        # Save as JPEG
        output_buffer = io.BytesIO()
        image.save(output_buffer, format='JPEG', quality=90, optimize=True)
        jpeg_data = output_buffer.getvalue()
        
        logger.info(f"✅ Converted to JPEG: {len(jpeg_data)} bytes")
        
        # Encode to base64
        image_b64 = base64.b64encode(jpeg_data).decode('utf-8')
        
        # Prepare Claude message
        message = {
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
                    "text": """Analyze this van image for damage assessment. Provide a JSON response with:
                    {
                        "damage_level": 0-3 (0=excellent, 1=minor wear, 2=moderate damage, 3=significant damage),
                        "damage_type": "description of damage type",
                        "location": "where damage is located",
                        "description": "detailed description",
                        "recommendations": "maintenance recommendations"
                    }
                    Focus on visible damage, wear, dents, scratches, or maintenance issues."""
                }
            ]
        }
        
        # Call Claude API
        response = claude_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1000,
            messages=[message]
        )
        
        # Parse response
        response_text = response.content[0].text
        logger.info(f"📝 Claude response: {response_text}")
        
        # Extract JSON from response
        try:
            json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
            if json_match:
                damage_assessment = json.loads(json_match.group())
            else:
                damage_assessment = {
                    "damage_level": 1,
                    "damage_type": "Assessment pending",
                    "location": "General",
                    "description": response_text,
                    "recommendations": "Review image manually"
                }
        except json.JSONDecodeError:
            damage_assessment = {
                "damage_level": 1,
                "damage_type": "Assessment pending", 
                "location": "General",
                "description": response_text,
                "recommendations": "Review image manually"
            }
        
        return damage_assessment
        
    except Exception as e:
        logger.error(f"❌ Error calling Claude AI: {e}")
        return {
            "damage_level": 1,
            "damage_type": "Assessment failed",
            "location": "Unknown",
            "description": f"Claude AI analysis failed: {str(e)}",
            "recommendations": "Manual review required"
        }

def store_van_image(van_id: str, van_number: str, image_data: bytes, filename: str, damage_assessment: Dict[str, Any]) -> str:
    """Store van image in database - MINIMAL SCHEMA VERSION."""
    try:
        # Convert image to base64 for database storage
        image_b64 = base64.b64encode(image_data).decode('utf-8')
        image_data_url = f"data:image/jpeg;base64,{image_b64}"
        
        # Prepare van_images record with MINIMAL schema
        van_image_record = {
            'van_id': van_id,
            'image_url': image_data_url,
            'uploaded_by': 'slack_bot',
            'description': damage_assessment.get('description', 'No description'),
            'damage_type': damage_assessment.get('damage_type', 'Unknown'),
            'damage_level': damage_assessment.get('damage_level', 0),
            'location': damage_assessment.get('location', 'General')
        }
        
        logger.info(f"💾 Storing van image with minimal schema: {list(van_image_record.keys())}")
        
        # Insert into van_images table
        result = supabase.table('van_images').insert(van_image_record).execute()
        
        if result.data:
            image_id = result.data[0]['id']
            logger.info(f"✅ Successfully stored van image: {image_id}")
            return image_id
        else:
            raise Exception(f"Failed to store image: {result}")
            
    except Exception as e:
        logger.error(f"❌ Error storing van image: {e}")
        raise

def download_image(url: str, token: str) -> Optional[bytes]:
    """Download image from Slack."""
    try:
        headers = {'Authorization': f'Bearer {token}'}
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.content
    except Exception as e:
        logger.error(f"❌ Error downloading image: {e}")
        return None

def process_image_file(file_info: Dict[str, Any], van_number: str, say, client) -> None:
    """Process an image file for damage assessment - MINIMAL SCHEMA VERSION."""
    try:
        logger.info(f"📷 Processing image for van #{van_number}: {file_info.get('name', 'unknown')}")
        
        # Get or create van
        status, van_data = get_or_create_van(van_number)
        van_id = van_data['id']
        
        # Download image
        image_data = download_image(
            file_info['url_private'],
            os.environ.get("SLACK_BOT_TOKEN")
        )
        
        if not image_data:
            say(f"❌ Failed to download image for van {van_number}")
            return
        
        # Analyze with Claude AI
        damage_assessment = assess_damage_with_claude(image_data, file_info.get('name', 'image.jpg'))
        
        # Store image with assessment
        image_id = store_van_image(van_id, van_number, image_data, file_info.get('name', 'image.jpg'), damage_assessment)
        
        # Send success message
        damage_level = damage_assessment.get('damage_level', 0)
        damage_type = damage_assessment.get('damage_type', 'Unknown')
        location = damage_assessment.get('location', 'General')
        description = damage_assessment.get('description', 'No description')
        
        # Create status emoji based on damage level
        status_emoji = ["🟢", "🟡", "🟠", "🔴"][min(damage_level, 3)]
        
        success_message = f"""✅ **Van {van_number} Image Processed**
        
{status_emoji} **Damage Level:** {damage_level}/3
🔧 **Type:** {damage_type}
📍 **Location:** {location}
📝 **Description:** {description}

📊 **Image ID:** {image_id}
🆔 **Van ID:** {van_id}"""
        
        say(success_message)
        logger.info(f"✅ Successfully processed image for van #{van_number}")
        
    except Exception as e:
        logger.error(f"❌ Error processing image file: {e}")
        say(f"❌ Error processing image for van {van_number}: {str(e)}")

@app.event("file_shared")
def handle_file_shared(event, say, client):
    """Handle file shared events."""
    try:
        file_id = event["file_id"]
        logger.info(f"📁 File shared event received: {file_id}")
        
        # Get file info
        file_info = client.files_info(file=file_id)["file"]
        
        # Check if it's an image
        if not file_info.get("mimetype", "").startswith("image/"):
            logger.info(f"⏭️ Skipping non-image file: {file_info.get('mimetype', 'unknown')}")
            return
        
        # Look for van number in recent messages
        van_number = None
        try:
            channel_id = event.get("channel_id")
            if channel_id:
                messages = client.conversations_history(
                    channel=channel_id,
                    limit=10
                )["messages"]
                
                for message in messages:
                    text = message.get("text", "")
                    van_number = extract_van_number(text)
                    if van_number:
                        logger.info(f"✅ Found van number {van_number} in recent message")
                        break
        except Exception as e:
            logger.error(f"⚠️ Error getting recent messages: {e}")
        
        if not van_number:
            say("❌ Please specify a van number (e.g., 'van 123') before uploading images")
            return
        
        # Process the image
        process_image_file(file_info, van_number, say, client)
        
    except Exception as e:
        logger.error(f"❌ Error handling file shared event: {e}")
        say(f"❌ Error processing file: {str(e)}")

@app.event("message")
def handle_message_events(body, logger):
    """Handle message events to prevent unhandled request warnings."""
    logger.info("📝 Message event received")

if __name__ == "__main__":
    logger.info("🚀 Starting CLAUDE AI ENHANCED Slack Bot (MINIMAL SCHEMA)...")
    
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
    
    # Test Supabase connection
    try:
        test_result = supabase.table('vans').select('id').limit(1).execute()
        logger.info("✅ Supabase connection successful")
    except Exception as e:
        logger.error(f"❌ Supabase connection failed: {e}")
        exit(1)
    
    # Start the app
    handler = SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"])
    logger.info("⚡ Slack bot is running with Claude AI integration!")
    handler.start() 
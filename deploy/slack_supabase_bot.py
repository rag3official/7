import os
import json
from datetime import datetime, timedelta
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from supabase import create_client, Client
from dotenv import load_dotenv
import requests
from urllib.parse import urlparse
import mimetypes
import logging
from anthropic import Anthropic
import re
import base64

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Print environment variables (without sensitive data)
logger.info("Checking environment variables...")
logger.info(f"SUPABASE_URL exists: {bool(os.environ.get('SUPABASE_URL'))}")
logger.info(f"SUPABASE_KEY exists: {bool(os.environ.get('SUPABASE_KEY'))}")
logger.info(f"SLACK_BOT_TOKEN exists: {bool(os.environ.get('SLACK_BOT_TOKEN'))}")
logger.info(f"SLACK_APP_TOKEN exists: {bool(os.environ.get('SLACK_APP_TOKEN'))}")

# Initialize Slack app
app = App(
    token=os.environ.get("SLACK_BOT_TOKEN"),
    signing_secret=os.environ.get("SLACK_SIGNING_SECRET")
)

# Initialize Supabase client
try:
    supabase: Client = create_client(
        os.environ.get("SUPABASE_URL"),
        os.environ.get("SUPABASE_KEY")
    )
    logger.info("Successfully connected to Supabase")
except Exception as e:
    logger.error(f"Failed to connect to Supabase: {str(e)}")
    raise

# Initialize Anthropic client
anthropic = Anthropic(api_key=os.environ.get('CLAUDE_API_KEY'))

def test_supabase_connection():
    """Test the Supabase connection and verify table structure"""
    try:
        # Try to fetch a single row from messages table
        result = supabase.table('messages').select("*").limit(1).execute()
        logger.info("Successfully connected to Supabase messages table")
        
        # Log the table structure
        logger.info("Checking table structure...")
        try:
            # Try to insert a test row
            test_data = {
                'channel_id': 'test_channel',
                'user_id': 'test_user',
                'message_text': 'test message',
                'timestamp': datetime.now().isoformat(),
                'image_urls': [],
                'created_at': datetime.now().isoformat(),
                'message_id': f"test_{datetime.now().timestamp()}",
                'thread_ts': None,
                'parent_message_id': None
            }
            test_result = supabase.table('messages').insert(test_data).execute()
            logger.info(f"Test insert successful: {json.dumps(test_result.data, indent=2)}")
            
            # Clean up test data
            supabase.table('messages').delete().eq('message_id', test_data['message_id']).execute()
            logger.info("Test data cleaned up")
            
        except Exception as e:
            logger.error(f"Error during table structure test: {str(e)}")
            logger.error(f"Error type: {type(e).__name__}")
            return False
            
        return True
    except Exception as e:
        logger.error(f"Failed to connect to Supabase messages table: {str(e)}")
        logger.error(f"Error type: {type(e).__name__}")
        return False

def assess_damage_with_claude(image_data: bytes, file_info: dict = None) -> dict:
    """Use Claude API to assess van damage from image data with automatic JPG conversion."""
    try:
        logger.info("🧠 Analyzing damage with Claude AI...")
        
        # Debug: Log first few bytes of original image data
        logger.info(f"🔍 Original image signature: {image_data[:12].hex()}")
        logger.info(f"📊 Original image size: {len(image_data)} bytes")
        
        # Detect original image format
        original_format = "unknown"
        if image_data[:8] == b'\x89PNG\r\n\x1a\n':
            original_format = "PNG"
        elif image_data[:3] == b'\xff\xd8\xff':
            original_format = "JPEG"
        elif image_data[:6] in [b'GIF87a', b'GIF89a']:
            original_format = "GIF"
        elif image_data[:4] == b'RIFF' and image_data[8:12] == b'WEBP':
            original_format = "WEBP"
        
        logger.info(f"📷 Original format detected: {original_format}")
        
        # Convert all images to JPG format for Claude AI
        try:
            from PIL import Image
            import io
            
            # Open the image with PIL
            image = Image.open(io.BytesIO(image_data))
            logger.info(f"📸 PIL opened image: {image.format} {image.size} {image.mode}")
            
            # Convert to RGB if necessary (required for JPEG)
            if image.mode in ('RGBA', 'LA', 'P'):
                logger.info(f"🔄 Converting from {image.mode} to RGB")
                # Create white background for transparency
                background = Image.new('RGB', image.size, (255, 255, 255))
                if image.mode == 'P':
                    image = image.convert('RGBA')
                background.paste(image, mask=image.split()[-1] if image.mode in ('RGBA', 'LA') else None)
                image = background
            elif image.mode != 'RGB':
                logger.info(f"🔄 Converting from {image.mode} to RGB")
                image = image.convert('RGB')
            
            # Save as JPEG with good quality
            output_buffer = io.BytesIO()
            image.save(output_buffer, format='JPEG', quality=90, optimize=True)
            converted_image_data = output_buffer.getvalue()
            
            logger.info(f"✅ Successfully converted to JPEG: {len(converted_image_data)} bytes")
            logger.info(f"🔍 Converted image signature: {converted_image_data[:12].hex()}")
            
            # Use the converted image data
            image_data = converted_image_data
            
        except Exception as e:
            logger.warning(f"⚠️ Image conversion failed, using original: {str(e)}")
            # Fall back to original image data if conversion fails
        
        # Always use JPEG media type since we convert all images to JPEG
        media_type = "image/jpeg"
        logger.info(f"🖼️ Final media type for Claude: {media_type}")
        logger.info(f"📊 Final image size: {len(image_data)} bytes")
        
        # Convert image to base64
        image_base64 = base64.b64encode(image_data).decode('utf-8')
        logger.info(f"📤 Converted to base64 ({len(image_base64)} characters)")
        
        # Call Claude API with image data
        message = anthropic.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1000,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media_type,  # Use correctly detected media type
                                "data": image_base64
                            }
                        },
                        {
                            "type": "text",
                            "text": """Analyze this van image for damage and provide assessment:

**Damage Level Scale (0-3):**
- 0: No visible damage, excellent condition
- 1: Minor issues (dirt, dust, small scratches)
- 2: Moderate damage (multiple scratches, small dents)
- 3: Severe damage (large dents, major damage, safety concerns)

**Van Side Detection:**
Identify which side/view of the van is shown:
- front, rear, driver_side, passenger_side, interior, roof, or unknown

**Response Format:**
Provide your assessment as a JSON object:
{
  "damage_level": [0-3],
  "description": "detailed description of damage observed",
  "van_side": "side of van shown",
  "location": "specific area where damage is located",
  "confidence": "high/medium/low"
}"""
                        }
                    ]
                }
            ]
        )
        
        # Parse Claude's response
        response_text = message.content[0].text.strip()
        logger.info(f"🧠 Claude response: {response_text}")
        
        # Try to extract JSON from response
        try:
            # Look for JSON object in the response
            import json
            import re
            
            # Find JSON object pattern
            json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
            if json_match:
                assessment = json.loads(json_match.group())
                logger.info(f"✅ Parsed Claude assessment: {assessment}")
                return assessment
            else:
                # Fallback: parse key information from text
                damage_level = 0
                if "damage_level" in response_text.lower():
                    level_match = re.search(r'damage_level["\s:]*(\d+)', response_text.lower())
                    if level_match:
                        damage_level = int(level_match.group(1))
                
                return {
                    "damage_level": damage_level,
                    "description": response_text[:200] + "..." if len(response_text) > 200 else response_text,
                    "van_side": "unknown",
                    "location": "unspecified",
                    "confidence": "medium"
                }
                
        except json.JSONDecodeError:
            logger.warning("⚠️ Could not parse JSON from Claude response, using fallback")
            return {
                "damage_level": 1,
                "description": response_text[:200] + "..." if len(response_text) > 200 else response_text,
                "van_side": "unknown", 
                "location": "unspecified",
                "confidence": "low"
            }
        
    except Exception as e:
        logger.error(f"❌ Error calling Claude AI: {str(e)}")
        return {
            "damage_level": 0,
            "description": f"Error during AI analysis: {str(e)}",
            "van_side": "unknown",
            "location": "unspecified", 
            "confidence": "low"
        }

def extract_van_number(message_text: str) -> str:
    """Extract van number from message text."""
    van_pattern = r'van\s*(\d+)'
    match = re.search(van_pattern, message_text.lower())
    return match.group(1) if match else None

def get_or_create_van(van_number: str) -> tuple[str, dict]:
    """Get existing van or create new one if it doesn't exist."""
    try:
        # Try to get existing van
        result = supabase.table('vans').select('*').eq('van_number', van_number).execute()
        
        if result.data and len(result.data) > 0:
            return 'existing', result.data[0]
        
        # Create new van if it doesn't exist
        new_van = {
            'van_number': van_number,
            'type': 'Unknown',
            'status': 'Active',
            'notes': '',
            'url': '',
            'driver': '',
            'damage': '',
            'damage_description': '',
            'rating': 0,
            'created_at': datetime.now().isoformat(),
            'last_updated': datetime.now().isoformat()
        }
        
        create_result = supabase.table('vans').insert(new_van).execute()
        return 'new', create_result.data[0]
    except Exception as e:
        logger.error(f"Error in get_or_create_van: {e}")
        raise

def update_van_damage(van_id: str, damage_assessment: dict, image_url: str) -> None:
    """Update van's damage information based on assessment."""
    try:
        # Get current van data
        van_result = supabase.table('vans').select('*').eq('id', van_id).execute()
        if not van_result.data:
            raise Exception(f"Van not found with ID: {van_id}")
            
        van_data = van_result.data[0]
        current_rating = float(van_data.get('rating', 0))
        new_rating = damage_assessment.get('damage_level', 0)
        
        # Update van data
        update_data = {
            'last_updated': datetime.now().isoformat(),
            'damage_description': damage_assessment.get('description', ''),
            'rating': max(current_rating, new_rating)  # Keep the highest damage rating
        }
        
        # Update status if severe damage detected
        if new_rating == 3:
            update_data['status'] = 'Maintenance'
            update_data['damage'] = 'Severe damage detected'
            
        # Add image URL if not present
        if not van_data.get('url'):
            update_data['url'] = image_url
            
        # Update van in database
        supabase.table('vans').update(update_data).eq('id', van_id).execute()
        logger.info(f"Updated van {van_id} with damage assessment")
        
    except Exception as e:
        logger.error(f"Error updating van damage: {e}")
        raise

def upload_to_supabase_storage(image_data: bytes, van_number: str, filename: str) -> str:
    """Upload image to Supabase Storage."""
    try:
        logger.info(f"Uploading image to Supabase Storage: {filename}")
        bucket_name = "van-images"
        file_path = f"van_{van_number}/{filename}"
        
        # Upload the file
        result = supabase.storage.from_(bucket_name).upload(
            file_path,
            image_data,
            {"content-type": mimetypes.guess_type(filename)[0] or 'image/jpeg'}
        )
        
        # Get public URL
        if result:
            public_url = supabase.storage.from_(bucket_name).get_public_url(file_path)
            logger.info(f"Successfully uploaded image: {public_url}")
            return public_url
            
        logger.error("Failed to upload image")
        return None
    except Exception as e:
        logger.error(f"Error uploading to Supabase Storage: {str(e)}")
        return None

def download_image(url: str, token: str) -> bytes:
    """Download image from Slack URL."""
    try:
        logger.info(f"Downloading image from URL: {url}")
        response = requests.get(url, headers={'Authorization': f'Bearer {token}'})
        if response.status_code == 200:
            logger.info("Successfully downloaded image")
            return response.content
        logger.error(f"Failed to download image. Status code: {response.status_code}")
        return None
    except Exception as e:
        logger.error(f"Error downloading image: {str(e)}")
        return None

@app.event("file_shared")
def handle_file_shared_events(body, say, client):
    """Handle file_shared events from Slack."""
    try:
        logger.info("📁 Received file_shared event")
        event = body['event']
        
        file_id = event.get('file_id')
        channel_id = event.get('channel_id')
        user_id = event.get('user_id')
        
        logger.info(f"📁 File ID: {file_id}")
        logger.info(f"📁 Channel ID: {channel_id}")
        
        # Get complete file info
        file_info_response = client.files_info(file=file_id)
        if not file_info_response.get('ok'):
            logger.error("❌ Failed to get file info")
            return
            
        file_info = file_info_response['file']
        logger.info(f"📄 File: {file_info.get('name')} ({file_info.get('mimetype')})")
        
        # Check if it's an image
        if not file_info.get('mimetype', '').startswith('image/'):
            logger.info("📄 File is not an image, skipping")
            return
        
        # Look for van number in recent channel messages
        van_number = None
        try:
            # Get recent messages from the channel
            messages_response = client.conversations_history(
                channel=channel_id,
                limit=10
            )
            
            if messages_response.get('ok'):
                for message in messages_response['messages']:
                    text = message.get('text', '')
                    found_van = extract_van_number(text)
                    if found_van:
                        van_number = found_van
                        logger.info(f"✅ Found van number {van_number} in recent message")
                        break
        except Exception as e:
            logger.error(f"❌ Error searching for van number: {e}")
        
        if not van_number:
            say("❌ Please mention a van number (e.g., 'van 123') when uploading images")
            return
        
        # Process the image
        process_image_file(file_info, van_number, say, client)
        
    except Exception as e:
        logger.error(f"❌ Error handling file_shared event: {e}")

def process_image_file(file_info, van_number, say, client):
    """Process an image file for damage assessment."""
    try:
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
        
        # Generate filename with timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"slack_image_{timestamp}.jpg"
        
        # Upload to Supabase
        public_url = upload_to_supabase_storage(
            image_data,
            van_number,
            filename
        )
        
        if public_url:
            # Get damage assessment from Claude
            damage_assessment = assess_damage_with_claude(image_data, file_info)
            
            # Update van with damage assessment
            update_van_damage(van_id, damage_assessment, public_url)
            
            # Send enhanced damage assessment reply
            damage_level = damage_assessment.get('damage_level', 0)
            damage_desc = damage_assessment.get('description', '')
            van_side = damage_assessment.get('van_side', 'unknown')
            location = damage_assessment.get('location', 'unspecified')
            confidence = damage_assessment.get('confidence', 'medium')
            
            # Create detailed response
            reply = f"🔍 **Claude AI Analysis for Van #{van_number}**\n\n"
            reply += f"📊 **Damage Level:** {damage_level}/3\n"
            reply += f"🚐 **Van Side:** {van_side.replace('_', ' ').title()}\n"
            reply += f"📍 **Location:** {location}\n"
            reply += f"📝 **Description:** {damage_desc}\n"
            reply += f"🎯 **Confidence:** {confidence.title()}\n"
            
            # Add severity indicators
            if damage_level == 0:
                reply += "\n✅ **Status:** No damage detected - Excellent condition"
            elif damage_level == 1:
                reply += "\n🟡 **Status:** Minor issues - Monitor for changes"
            elif damage_level == 2:
                reply += "\n🟠 **Status:** Moderate damage - Schedule maintenance"
            elif damage_level == 3:
                reply += "\n🔴 **Status:** SEVERE DAMAGE - Immediate attention required"
                reply += "\n⚠️ *Van status automatically updated to Maintenance*"
            
            say(reply)
        else:
            say(f"❌ Failed to upload image for van {van_number}")
            
    except Exception as e:
        logger.error(f"❌ Error processing image file: {e}")
        say(f"❌ Error processing image for van {van_number}")

@app.event("message")
def handle_message_events(body, say, client):
    """Handle incoming message events."""
    try:
        event = body['event']
        
        # Handle file_share subtype messages
        if event.get('subtype') == 'file_share':
            logger.info("📁 Received message with file_share subtype")
            
            # Extract files from the message
            files = event.get('files', [])
            if not files:
                logger.info("📄 No files found in file_share message")
                return
            
            # Look for van number in message text
            message_text = event.get('text', '')
            van_number = extract_van_number(message_text)
            
            if not van_number:
                logger.warning("No van number found in message text")
                say("❌ Please mention a van number (e.g., 'van 123') when uploading images")
                return
            
            # Process each image file
            for file_info in files:
                if file_info.get('mimetype', '').startswith('image/'):
                    logger.info(f"📷 Processing image: {file_info.get('name')}")
                    process_image_file(file_info, van_number, say, client)
            
            return
        
        # Handle regular text messages
        logger.info("💬 Received regular message event")
        message_text = event.get('text', '')
        
        # Skip messages from bots
        if 'bot_id' in event:
            logger.info("Skipping bot message")
            return
        
        # For now, just log regular messages
        if message_text:
            logger.info(f"📝 Message text: {message_text}")
        
    except Exception as e:
        logger.error(f"❌ Error handling message: {str(e)}")
        raise

def main():
    """Main function to start the Slack bot."""
    logger.info("Starting Slack bot...")
    handler = SocketModeHandler(app, os.environ.get("SLACK_APP_TOKEN"))
    handler.start()

if __name__ == "__main__":
    main() 
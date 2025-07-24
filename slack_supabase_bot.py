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
import uuid

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

# Initialize Supabase client with service role key for admin operations
try:
    supabase: Client = create_client(
        os.environ.get("SUPABASE_URL"),
        os.environ.get("SUPABASE_KEY")  # Should be service_role key for admin operations
    )
    logger.info("Successfully connected to Supabase")
except Exception as e:
    logger.error(f"Failed to connect to Supabase: {str(e)}")
    raise

# Initialize Anthropic client
anthropic = Anthropic(api_key=os.environ.get('CLAUDE_API_KEY'))

def setup_database_schema():
    """Set up the database schema if needed"""
    try:
        # Check if uploaded_at column exists
        result = supabase.table('van_images').select('uploaded_at').limit(1).execute()
        logger.info("Database schema is ready")
        return True
    except Exception as e:
        if "does not exist" in str(e):
            logger.info("Adding uploaded_at column to van_images table")
            try:
                # Add the uploaded_at column
                supabase.rpc('exec_sql', {
                    'sql': '''
                    ALTER TABLE van_images 
                    ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
                    '''
                }).execute()
                logger.info("Successfully added uploaded_at column")
                return True
            except Exception as add_error:
                logger.error(f"Failed to add uploaded_at column: {str(add_error)}")
                return False
        else:
            logger.error(f"Database schema error: {str(e)}")
            return False

def upload_to_supabase_storage(image_data, van_number, filename):
    """Upload image to Supabase Storage using direct REST API with service role bypass"""
    try:
        logger.info(f"Uploading image to Supabase Storage: {filename}")
        
        bucket_name = "van-images"
        file_path = f"van_{van_number}/{filename}"
        
        # Use direct REST API with service role key - bypasses all SDK limitations
        headers = {
            'Authorization': f'Bearer {os.environ.get("SUPABASE_KEY")}',
            'Content-Type': 'image/jpeg',
            'x-upsert': 'true',  # Allow overwrite if file exists
        }
        
        upload_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/{bucket_name}/{file_path}"
        
        logger.info(f"Uploading to URL: {upload_url}")
        logger.info(f"File path: {file_path}")
        logger.info(f"Data size: {len(image_data)} bytes")
        
        response = requests.post(
            upload_url,
            headers=headers,
            data=image_data,
            timeout=60
        )
        
        logger.info(f"Upload response status: {response.status_code}")
        logger.info(f"Upload response text: {response.text}")
        
        if response.status_code in [200, 201]:
            # Get public URL
            public_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/public/{bucket_name}/{file_path}"
            logger.info(f"✅ Successfully uploaded to storage: {public_url}")
            return public_url
        else:
            logger.error(f"❌ Storage upload failed: {response.status_code} - {response.text}")
            
            # Try alternative approach with different headers
            return upload_with_multipart(image_data, van_number, filename)
            
    except Exception as e:
        logger.error(f"❌ Error with storage upload: {str(e)}")
        return upload_with_multipart(image_data, van_number, filename)

def upload_with_multipart(image_data, van_number, filename):
    """Alternative upload using multipart form data"""
    try:
        logger.info(f"Trying multipart upload for: {filename}")
        
        bucket_name = "van-images"
        file_path = f"van_{van_number}/{filename}"
        
        # Use multipart form data
        files = {
            'file': (filename, image_data, 'image/jpeg')
        }
        
        headers = {
            'Authorization': f'Bearer {os.environ.get("SUPABASE_KEY")}',
        }
        
        upload_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/{bucket_name}/{file_path}"
        
        response = requests.post(
            upload_url,
            headers=headers,
            files=files,
            timeout=60
        )
        
        logger.info(f"Multipart upload response: {response.status_code} - {response.text}")
        
        if response.status_code in [200, 201]:
            public_url = f"{os.environ.get('SUPABASE_URL')}/storage/v1/object/public/{bucket_name}/{file_path}"
            logger.info(f"✅ Multipart upload successful: {public_url}")
            return public_url
        else:
            logger.error(f"❌ Multipart upload failed: {response.status_code} - {response.text}")
            return None
            
    except Exception as e:
        logger.error(f"❌ Error with multipart upload: {str(e)}")
        return None

def save_van_image(van_id, image_url, damage_assessment, driver_id=None):
    """Save van image record to database"""
    try:
        logger.info(f"Saving van image record to database for van {van_id}")
        
        image_data = {
            'van_id': van_id,
            'image_url': image_url,
            'description': damage_assessment.get('description', ''),
            'damage_level': damage_assessment.get('confidence', 0.0),
            'uploaded_at': datetime.utcnow().isoformat(),
            'driver_id': driver_id
        }
        
        result = supabase.table('van_images').insert(image_data).execute()
        
        if result.data:
            image_record = result.data[0]
            logger.info(f"Successfully created van_images record: {image_record['id']}")
            return image_record
        else:
            logger.error("Failed to create van_images record - no data returned")
            return None
            
    except Exception as e:
        logger.error(f"Error saving van image: {str(e)}")
        return None

def update_van_damage(van_id, damage_level, damage_description):
    """Update van damage information"""
    try:
        logger.info(f"Updating van damage for van {van_id}")
        
        # Get current van data
        van_result = supabase.table('vans').select('*').eq('id', van_id).execute()
        
        if not van_result.data:
            logger.error(f"Van {van_id} not found")
            return False
            
        current_van = van_result.data[0]
        
        # Update van with new damage info
        update_data = {
            'damage_level': max(current_van.get('damage_level', 0), damage_level),
            'damage_description': damage_description,
            'updated_at': datetime.utcnow().isoformat()
        }
        
        update_result = supabase.table('vans').update(update_data).eq('id', van_id).execute()
        
        if update_result.data:
            logger.info(f"Successfully updated van damage for van {van_id}")
            return True
        else:
            logger.error(f"Failed to update van damage for van {van_id}")
            return False
            
    except Exception as e:
        logger.error(f"Error updating van damage: {str(e)}")
        return False

def analyze_damage_with_claude(image_url, van_number):
    """Analyze damage using Claude AI"""
    try:
        logger.info(f"Analyzing damage with Claude for van {van_number}")
        
        prompt = f"""
        Analyze this image of van #{van_number} for damage. Provide:
        1. Damage level (0-5 scale: 0=no damage, 5=severe damage)
        2. Brief description of any damage found
        3. Confidence score (0.0-1.0)
        
        Return as JSON: {{"damage_level": int, "description": "text", "confidence": float}}
        """
        
        response = anthropic.messages.create(
            model="claude-3-sonnet-20240229",
            max_tokens=1000,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "url",
                                "url": image_url
                            }
                        },
                        {
                            "type": "text",
                            "text": prompt
                        }
                    ]
                }
            ]
        )
        
        # Parse response
        response_text = response.content[0].text
        logger.info(f"Claude analysis: {response_text}")
        
        # Extract JSON from response
        json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
        if json_match:
            damage_data = json.loads(json_match.group())
            return damage_data
        else:
            # Fallback if no JSON found
            return {
                "damage_level": 1,
                "description": response_text[:200],
                "confidence": 0.5
            }
            
    except Exception as e:
        logger.error(f"Error analyzing damage with Claude: {str(e)}")
        return {
            "damage_level": 0,
            "description": "Analysis failed",
            "confidence": 0.0
        }

def extract_van_number(text):
    """Extract van number from text using multiple patterns"""
    if not text:
        return None
        
    # Look for patterns like "van 123", "van123", "#123", etc.
    patterns = [
        r'van\s*(\d+)',
        r'#(\d+)',
        r'\b(\d{1,4})\b'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text.lower())
        if match:
            return int(match.group(1))
    
    return None

def get_van_by_number(van_number):
    """Get van record by van number"""
    try:
        result = supabase.table('vans').select('*').eq('van_number', van_number).execute()
        
        if result.data:
            return result.data[0]
        else:
            logger.warning(f"Van {van_number} not found in database")
            return None
            
    except Exception as e:
        logger.error(f"Error fetching van {van_number}: {str(e)}")
        return None

@app.message(re.compile(r"van", re.IGNORECASE))
def handle_van_messages(message, say, logger):
    """Handle messages containing 'van'"""
    try:
        logger.info(f"🔍 Processing message: {message.get('text', '')}")
        
        # Extract van number from message text
        van_number = extract_van_number(message.get('text', ''))
        
        if not van_number:
            logger.info("No van number found in message")
            return
            
        logger.info(f"🚐 Detected van number: {van_number}")
        
        # Check if message has files
        files = message.get('files', [])
        if not files:
            logger.info("No files attached to message")
            say(f"🚐 Van {van_number} detected! Please attach an image for damage assessment.")
            return
            
        # Process each file
        for file_info in files:
            if file_info.get('mimetype', '').startswith('image/'):
                process_van_image(file_info, van_number, say, logger)
            else:
                logger.info(f"Skipping non-image file: {file_info.get('name', 'unknown')}")
                
    except Exception as e:
        logger.error(f"Error handling van message: {str(e)}")
        say("❌ Error processing your message. Please try again.")

def process_van_image(file_info, van_number, say, logger):
    """Process a single van image"""
    try:
        logger.info(f"📸 Processing image for van {van_number}")
        
        # Get van record
        van_record = get_van_by_number(van_number)
        if not van_record:
            say(f"❌ Van {van_number} not found in database.")
            return
            
        van_id = van_record['id']
        logger.info(f"Found van ID: {van_id}")
        
        # Download image
        image_url = file_info['url_private_download']
        logger.info(f"📥 Downloading image from URL: {image_url}")
        
        headers = {'Authorization': f'Bearer {os.environ.get("SLACK_BOT_TOKEN")}'}
        response = requests.get(image_url, headers=headers, timeout=30)
        
        if response.status_code != 200:
            logger.error(f"Failed to download image: {response.status_code}")
            say("❌ Failed to download image.")
            return
            
        image_data = response.content
        logger.info(f"✅ Successfully downloaded image ({len(image_data)} bytes)")
        
        # Upload to Supabase Storage
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"slack_image_{timestamp}.jpg"
        
        storage_url = upload_to_supabase_storage(image_data, van_number, filename)
        
        if not storage_url:
            # Even if storage fails, still save to database with placeholder URL
            storage_url = f"placeholder://van_{van_number}/{filename}"
            logger.warning(f"⚠️ Storage upload failed, using placeholder URL: {storage_url}")
            
        # Analyze damage with Claude (skip if storage failed)
        if storage_url.startswith("http"):
            damage_assessment = analyze_damage_with_claude(storage_url, van_number)
        else:
            damage_assessment = {
                "damage_level": 1,
                "description": "Storage upload failed - manual review needed",
                "confidence": 0.0
            }
        
        # Save to database
        image_record = save_van_image(van_id, storage_url, damage_assessment)
        
        if image_record:
            # Update van damage level
            update_van_damage(van_id, damage_assessment['damage_level'], damage_assessment['description'])
            
            # Send response
            storage_status = "✅ Stored in bucket" if storage_url.startswith("http") else "⚠️ Storage failed"
            
            say(f"""✅ **Van {van_number} Image Processed**
            
🔗 **Image**: {storage_url}
📊 **Damage Level**: {damage_assessment['damage_level']}/5
📝 **Assessment**: {damage_assessment['description']}
🎯 **Confidence**: {int(damage_assessment['confidence'] * 100)}%
💾 **Storage**: {storage_status}
📋 **Database**: ✅ Record saved
            
Image processing complete.""")
        else:
            say("❌ Failed to save image record to database.")
            
    except Exception as e:
        logger.error(f"Error processing van image: {str(e)}")
        say("❌ Error processing image. Please try again.")

@app.event("file_shared")
def handle_file_shared(event, logger):
    """Handle file_shared events (acknowledge but don't process)"""
    logger.info(f"📎 File shared event received: {event.get('file_id', 'unknown')}")
    # Just acknowledge - actual processing happens in message handler

@app.message("test")
def handle_test(message, say):
    """Test handler"""
    say("🤖 Bot is working! Send 'van [number]' with an image to test damage assessment.")

# Set up database schema on startup
setup_database_schema()

if __name__ == "__main__":
    handler = SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"])
    logger.info("🤖 Starting Slack bot...")
    handler.start() 
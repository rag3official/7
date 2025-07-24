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

def setup_database_schema():
    """Ensure van_images table has proper schema with uploaded_at column."""
    try:
        # Check if uploaded_at column exists in van_images table
        result = supabase.rpc('check_column_exists', {
            'table_name': 'van_images',
            'column_name': 'uploaded_at'
        }).execute()
        
        # If function doesn't exist or fails, try direct SQL
        try:
            # First, try to add uploaded_at column if it doesn't exist
            sql_add_column = """
            DO $$ 
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM information_schema.columns 
                    WHERE table_name = 'van_images' 
                    AND column_name = 'uploaded_at'
                    AND table_schema = 'public'
                ) THEN
                    ALTER TABLE public.van_images 
                    ADD COLUMN uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL;
                    
                    -- Populate existing records
                    UPDATE public.van_images 
                    SET uploaded_at = COALESCE(created_at, NOW()) 
                    WHERE uploaded_at IS NULL;
                    
                    -- Create index for performance
                    CREATE INDEX IF NOT EXISTS idx_van_images_uploaded_at 
                    ON public.van_images(uploaded_at DESC);
                END IF;
            END $$;
            """
            
            supabase.rpc('exec_sql', {'sql': sql_add_column}).execute()
            logger.info("Successfully ensured van_images table has uploaded_at column")
            
        except Exception as e:
            logger.warning(f"Could not add uploaded_at column via RPC: {e}")
            
    except Exception as e:
        logger.warning(f"Could not verify van_images schema: {e}")

def extract_van_number(text: str) -> str:
    """Extract van number from message text."""
    if not text:
        return None
        
    # Look for patterns like "van 123", "Van 123", "VAN 123", "#123"
    patterns = [
        r'van\s*#?(\d+)',
        r'#(\d+)',
        r'vehicle\s*#?(\d+)',
        r'truck\s*#?(\d+)'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1)
    
    return None

def get_or_create_van(van_number: str) -> tuple:
    """Get existing van or create new one."""
    try:
        logger.info(f"Looking for van #{van_number}")
        
        # Check if van exists
        result = supabase.table('vans').select('*').eq('van_number', van_number).execute()
        
        if result.data:
            logger.info(f"Found existing van: {result.data[0]['id']}")
            return "existing", result.data[0]
        
        # Create new van
        logger.info(f"Creating new van #{van_number}")
        new_van = {
            'van_number': van_number,
            'status': 'Active',
            'damage': 'No damage reported',
            'rating': 0,
            'created_at': datetime.now().isoformat(),
            'last_updated': datetime.now().isoformat()
        }
        
        create_result = supabase.table('vans').insert(new_van).execute()
        logger.info(f"Created new van: {create_result.data[0]['id']}")
        return "created", create_result.data[0]
        
    except Exception as e:
        logger.error(f"Error getting/creating van: {e}")
        raise

def save_van_image(van_id: str, image_url: str, damage_assessment: dict, filename: str) -> dict:
    """Save image record to van_images table with uploaded_at timestamp."""
    try:
        logger.info(f"Saving image record for van {van_id}")
        
        # Extract damage info from assessment
        damage_level = damage_assessment.get('damage_level', 0)
        description = damage_assessment.get('description', '')
        location = damage_assessment.get('location', 'unknown')
        
        # Create van_images record with uploaded_at
        van_image_data = {
            'id': str(uuid.uuid4()),
            'van_id': van_id,
            'image_url': image_url,
            'damage_level': damage_level,
            'damage_location': location,
            'damage_description': description,
            'filename': filename,
            'uploaded_at': datetime.now().isoformat(),  # THIS IS THE KEY FIX
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat()
        }
        
        result = supabase.table('van_images').insert(van_image_data).execute()
        logger.info(f"Successfully saved van_images record: {result.data[0]['id']}")
        return result.data[0]
        
    except Exception as e:
        logger.error(f"Error saving van image: {e}")
        # Don't raise - continue even if image record fails
        return None

def assess_damage_with_claude(image_url: str) -> dict:
    """Assess damage using Claude Vision API."""
    try:
        logger.info("Assessing damage with Claude...")
        
        message = anthropic.messages.create(
            model="claude-3-sonnet-20240229",
            max_tokens=300,
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
                            "text": """Assess this vehicle damage image and provide:
1. Damage level (0=no damage, 1=minor, 2=moderate, 3=severe)
2. Brief description of damage
3. Location of damage (front, rear, side, interior, etc.)

Respond in JSON format:
{
  "damage_level": 0-3,
  "description": "brief description",
  "location": "damage location"
}"""
                        }
                    ]
                }
            ]
        )
        
        response_text = message.content[0].text
        
        # Extract JSON from response
        try:
            # Find JSON in the response
            import json
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1
            if json_start >= 0 and json_end > json_start:
                damage_assessment = json.loads(response_text[json_start:json_end])
            else:
                raise ValueError("No JSON found in response")
        except:
            # Fallback assessment
            damage_assessment = {
                "damage_level": 1,
                "description": "Unable to parse damage assessment",
                "location": "unknown"
            }
        
        logger.info(f"Damage assessment: {damage_assessment}")
        return damage_assessment
        
    except Exception as e:
        logger.error(f"Error assessing damage: {e}")
        return {
            "damage_level": 1,
            "description": "Assessment failed - manual review required",
            "location": "unknown"
        }

def update_van_damage(van_id: str, damage_assessment: dict, image_url: str):
    """Update van with damage assessment and save image record."""
    try:
        logger.info(f"Updating van {van_id} with damage assessment")
        
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

@app.event("message")
def handle_message_events(body, say, client):
    """Handle incoming message events."""
    try:
        logger.info("="*50)
        logger.info("MESSAGE EVENT RECEIVED")
        logger.info("="*50)
        logger.info(f"Event body: {json.dumps(body, indent=2)}")
        
        event = body['event']
        message_text = event.get('text', '')
        
        # Skip messages from bots
        if 'bot_id' in event:
            logger.info("Skipping bot message")
            return
            
        # Extract van number
        van_number = extract_van_number(message_text)
        if not van_number:
            logger.warning("No van number found in message")
            return
            
        # Get or create van
        status, van_data = get_or_create_van(van_number)
        van_id = van_data['id']
        
        # Process any images in the message
        if 'files' in event:
            for file in event['files']:
                if file.get('mimetype', '').startswith('image/'):
                    # Download and process image
                    image_data = download_image(
                        file['url_private'],
                        os.environ.get("SLACK_BOT_TOKEN")
                    )
                    
                    if image_data:
                        # Generate filename with timestamp
                        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                        filename = f"damage_{timestamp}.jpg"
                        
                        # Upload to Supabase Storage
                        public_url = upload_to_supabase_storage(
                            image_data,
                            van_number,
                            filename
                        )
                        
                        if public_url:
                            # Get damage assessment from Claude
                            damage_assessment = assess_damage_with_claude(public_url)
                            
                            # Save image record to van_images table (WITH uploaded_at)
                            image_record = save_van_image(van_id, public_url, damage_assessment, filename)
                            
                            # Update van with damage assessment
                            update_van_damage(van_id, damage_assessment, public_url)
                            
                            # Send damage assessment reply
                            damage_level = damage_assessment.get('damage_level', 0)
                            damage_desc = damage_assessment.get('description', '')
                            
                            reply = f"🔍 Damage Assessment for Van #{van_number}:\n"
                            reply += f"Level: {damage_level}/3\n"
                            reply += f"Description: {damage_desc}\n"
                            
                            if damage_level == 3:
                                reply += "\n⚠️ *SEVERE DAMAGE DETECTED* - Van status updated to Maintenance"
                            
                            if image_record:
                                reply += f"\n📸 Image saved to database with ID: {image_record['id'][:8]}..."
                            
                            say(reply)
        
    except Exception as e:
        logger.error(f"Error handling message: {str(e)}")
        raise

def main():
    """Main function to start the Slack bot."""
    logger.info("Starting Slack bot...")
    
    # Setup database schema
    setup_database_schema()
    
    handler = SocketModeHandler(app, os.environ.get("SLACK_APP_TOKEN"))
    handler.start()

if __name__ == "__main__":
    main() 
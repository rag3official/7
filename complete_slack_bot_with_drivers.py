import os
import json
import hashlib
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

def assess_damage_with_claude(image_url: str) -> dict:
    """Use Claude API to assess van damage from image."""
    try:
        logger.info(f"Assessing damage for image: {image_url}")
        
        # Prepare the prompt for Claude
        prompt = f"""Please analyze this van image ({image_url}) and assess any damage on a scale of 0-3:
        0 - No visible damage
        1 - Minor issues (dirt, dust)
        2 - Moderate damage (scratches)
        3 - Severe damage (dents, major damage)
        
        Provide your assessment in a JSON format with:
        - damage_level (0-3)
        - description (brief explanation)
        """
        
        # Call Claude API
        message = anthropic.messages.create(
            model="claude-3-sonnet-20240229",
            max_tokens=300,
            messages=[{
                "role": "user",
                "content": prompt
            }]
        )
        
        # Parse Claude's response
        response = json.loads(message.content[0].text)
        logger.info(f"Claude assessment: {response}")
        return response
        
    except Exception as e:
        logger.error(f"Error assessing damage with Claude: {str(e)}")
        return {
            "damage_level": 0,
            "description": "Error assessing damage"
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

def save_image_assessment(van_id: str, image_url: str, image_hash: str, assessment: dict) -> dict:
    """Save image assessment to van_images table."""
    try:
        image_data = {
            'van_id': van_id,
            'image_url': image_url,
            'image_hash': image_hash,
            'damage_level': assessment.get('damage_level', 0),
            'damage_location': assessment.get('location', 'unknown'),
            'damage_description': assessment.get('description', ''),
            'status': 'active',
            'created_at': datetime.now().isoformat()
        }
        
        result = supabase.table('van_images').insert(image_data).execute()
        return result.data[0]
    except Exception as e:
        logger.error(f"Error in save_image_assessment: {e}")
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

def get_or_create_driver_profile(user_id: str, user_info: dict) -> dict:
    """Get or create a driver profile for a Slack user."""
    try:
        # Try to get existing driver profile
        result = supabase.table('driver_profiles').select('*').eq('slack_user_id', user_id).execute()
        
        if result.data and len(result.data) > 0:
            return result.data[0]
        
        # Get user's real name from Slack profile
        real_name = user_info.get('real_name', user_info.get('name', 'Unknown Driver'))
        email = user_info.get('profile', {}).get('email', '')
        phone = user_info.get('profile', {}).get('phone', '')
        
        # Create new driver profile if it doesn't exist
        new_driver = {
            'slack_user_id': user_id,
            'slack_username': user_info.get('name', ''),
            'name': real_name,  # Required
            'license_number': f'TEMP-{user_id}',  # Required - temporary
            'license_expiry': (datetime.now() + timedelta(days=30)).date().isoformat(),  # Required - temporary 30 days
            'phone_number': phone if phone else '000-000-0000',  # Required
            'email': email if email else f'{user_id}@example.com',  # Optional but good to have
            'status': 'active',  # One of: active, inactive, on_leave
            'certifications': [],  # Optional array
            'additional_info': {  # Optional JSONB
                'needs_update': True,
                'temporary_profile': True,
                'created_from_slack': True
            },
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat()
        }
        
        create_result = supabase.table('driver_profiles').insert(new_driver).execute()
        
        if not create_result.data:
            raise Exception("Failed to create driver profile")
            
        logger.info(f"Created new driver profile for {real_name} (Slack ID: {user_id})")
        return create_result.data[0]
        
    except Exception as e:
        logger.error(f"Error in get_or_create_driver_profile: {e}")
        raise

def assign_van_to_driver(van_id: str, driver_id: str) -> dict:
    """Create or update van assignment for a driver."""
    try:
        # Check if assignment already exists
        existing = supabase.table('driver_van_assignments').select('*').eq('van_id', van_id).eq('driver_id', driver_id).eq('status', 'active').execute()
        
        if existing.data:
            logger.info(f"Van assignment already exists: {existing.data[0]['id']}")
            return existing.data[0]
        
        # Create new assignment
        assignment = {
            'driver_id': driver_id,
            'van_id': van_id,
            'assigned_date': datetime.now().date().isoformat(),
            'status': 'active',
            'created_at': datetime.now().isoformat()
        }
        
        result = supabase.table('driver_van_assignments').insert(assignment).execute()
        logger.info(f"Created van assignment: {result.data[0]['id']}")
        return result.data[0]
        
    except Exception as e:
        logger.error(f"Error in assign_van_to_driver: {e}")
        raise

def save_driver_image(driver_id: str, van_id: str, van_image_id: str) -> dict:
    """Link a van image to a driver."""
    try:
        new_driver_image = {
            'driver_id': driver_id,
            'van_id': van_id,
            'van_image_id': van_image_id,
            'image_date': datetime.now().date().isoformat(),
            'created_at': datetime.now().isoformat()
        }
        
        result = supabase.table('driver_images').insert(new_driver_image).execute()
        return result.data[0]
    except Exception as e:
        logger.error(f"Error in save_driver_image: {e}")
        raise

def upload_to_supabase_storage(image_data: bytes, van_number: str, filename: str, user_id: str = None, user_info: dict = None) -> dict:
    """Upload image to Supabase Storage and create van_images record."""
    try:
        logger.info(f"Uploading image to Supabase Storage: {filename}")
        
        # Calculate image hash first
        image_hash = hashlib.sha256(image_data).hexdigest()
        
        # Get van ID from van number
        van_result = supabase.table('vans').select('id').eq('van_number', van_number).execute()
        if not van_result.data:
            logger.error(f"Van not found with number: {van_number}")
            return None
            
        van_id = van_result.data[0]['id']
        
        # Check if we already have this image for this van
        existing_images = supabase.table('van_images').select('*').eq('van_id', van_id).eq('image_hash', image_hash).execute()
        
        if existing_images.data:
            logger.info(f"Image with hash {image_hash} already exists for van {van_number}")
            return {
                'url': existing_images.data[0]['image_url'],
                'image_hash': image_hash,
                'van_id': van_id,
                'image_record': existing_images.data[0]
            }
        
        # If image doesn't exist, proceed with upload
        bucket_name = "van-images"
        file_path = f"van_{van_number}/{filename}"
        
        # Upload the file
        result = supabase.storage.from_(bucket_name).upload(
            file_path,
            image_data,
            {"content-type": mimetypes.guess_type(filename)[0] or 'image/jpeg'}
        )
        
        if not result:
            logger.error("Failed to upload image")
            return None
            
        # Get public URL
        public_url = supabase.storage.from_(bucket_name).get_public_url(file_path)
        logger.info(f"Successfully uploaded image: {public_url}")
        
        # Create van_images record
        image_record_data = {
            'van_id': van_id,
            'image_url': public_url,
            'image_hash': image_hash,
            'damage_level': 0,  # Will be updated by damage assessment
            'status': 'active',
            'original_format': mimetypes.guess_type(filename)[0] or 'image/jpeg',
            'original_size_bytes': len(image_data),
            'created_at': datetime.now().isoformat()
        }
        
        image_result = supabase.table('van_images').insert(image_record_data).execute()
        if not image_result.data:
            logger.error("Failed to create van_images record")
            return None
            
        # If user info is provided, create driver profile and link image
        if user_id and user_info:
            try:
                # Get or create driver profile
                driver_profile = get_or_create_driver_profile(user_id, user_info)
                
                # Create driver image record
                driver_image = save_driver_image(
                    driver_id=driver_profile['id'],
                    van_id=van_id,
                    van_image_id=image_result.data[0]['id']
                )
                
                # Create van assignment if it doesn't exist
                assign_van_to_driver(van_id, driver_profile['id'])
                
                logger.info(f"Created driver image record: {driver_image['id']}")
            except Exception as e:
                logger.error(f"Error creating driver records: {str(e)}")
            
        logger.info(f"Created van_images record: {image_result.data[0]['id']}")
        return {
            'url': public_url,
            'image_hash': image_hash,
            'van_id': van_id,
            'image_record': image_result.data[0]
        }
        
    except Exception as e:
        logger.error(f"Error in upload_to_supabase_storage: {str(e)}")
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
def handle_file_shared_events(body, client, logger):
    """Handle file shared events."""
    try:
        logger.info("="*50)
        logger.info("FILE SHARED EVENT RECEIVED")
        logger.info("="*50)
        logger.info(f"Event body: {json.dumps(body, indent=2)}")
        
        event = body['event']
        file_id = event.get('file_id')
        user_id = event.get('user_id')
        
        # Get user info
        user_info_response = client.users_info(user=user_id)
        if not user_info_response['ok']:
            logger.error(f"Failed to get user info: {user_info_response['error']}")
            return
            
        user_info = user_info_response['user']
        
        # Get file info
        file_info = client.files_info(file=file_id)
        if not file_info['ok']:
            logger.error(f"Failed to get file info: {file_info['error']}")
            return
            
        file = file_info['file']
        
        # Get channel info to find the message
        channel_id = file.get('channels', [])[0] if file.get('channels') else None
        if not channel_id:
            logger.warning("No channel found for file")
            return
            
        # Get channel history to find the message with the van number
        history = client.conversations_history(
            channel=channel_id,
            limit=10  # Look at last 10 messages
        )
        
        if not history['ok']:
            logger.error(f"Failed to get channel history: {history['error']}")
            return
            
        # Find the most recent message with a van number
        van_number = None
        for msg in history['messages']:
            potential_van = extract_van_number(msg.get('text', ''))
            if potential_van:
                van_number = potential_van
                break
                
        if not van_number:
            logger.warning("No van number found in recent messages")
            return
            
        # Get or create van
        status, van_data = get_or_create_van(van_number)
        van_id = van_data['id']
        
        # Process the file if it's an image
        if file.get('mimetype', '').startswith('image/'):
            # Download and process image
            image_data = download_image(
                file['url_private'],
                os.environ.get("SLACK_BOT_TOKEN")
            )
            
            if image_data:
                # Generate filename with timestamp and unique identifier
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                unique_id = os.urandom(4).hex()
                filename = f"slack_image_{timestamp}_{unique_id}.jpg"
                
                # Upload to Supabase with user info
                upload_result = upload_to_supabase_storage(
                    image_data,
                    van_number,
                    filename,
                    user_id,
                    user_info
                )
                
                if upload_result:
                    try:
                        # Get damage assessment from Claude
                        damage_assessment = assess_damage_with_claude(upload_result['url'])
                        
                        # Update van with damage assessment
                        update_van_damage(van_id, damage_assessment, upload_result['url'])
                        
                        # Get the saved image record
                        image_record = supabase.table('van_images').select('*').eq('image_url', upload_result['url']).single().execute()
                        
                        if image_record.data:
                            # Log the assessment with image ID
                            image_id = image_record.data['id']
                            damage_level = damage_assessment.get('damage_level', 0)
                            damage_desc = damage_assessment.get('description', '')
                            logger.info(f"Image {image_id} for Van #{van_number} - Damage Level: {damage_level}/3, Description: {damage_desc}")
                    except Exception as e:
                        logger.error(f"Error processing damage assessment: {str(e)}")
                        
    except Exception as e:
        logger.error(f"Error handling file shared event: {str(e)}")
        raise

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
        user_id = event.get('user')
        
        # Skip messages from bots
        if 'bot_id' in event:
            logger.info("Skipping bot message")
            return
            
        # Get user info
        user_info_response = client.users_info(user=user_id)
        if not user_info_response['ok']:
            logger.error(f"Failed to get user info: {user_info_response['error']}")
            return
            
        user_info = user_info_response['user']
        
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
            # Track all image uploads and assessments
            upload_results = []
            
            # First, process all image uploads concurrently
            for file in event['files']:
                if file.get('mimetype', '').startswith('image/'):
                    # Download and process image
                    image_data = download_image(
                        file['url_private'],
                        os.environ.get("SLACK_BOT_TOKEN")
                    )
                    
                    if image_data:
                        # Generate filename with timestamp and unique identifier
                        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                        unique_id = os.urandom(4).hex()  # Add unique identifier to prevent collisions
                        filename = f"slack_image_{timestamp}_{unique_id}.jpg"
                        
                        # Upload to Supabase with user info
                        upload_result = upload_to_supabase_storage(
                            image_data,
                            van_number,
                            filename,
                            user_id,
                            user_info
                        )
                        
                        if upload_result:
                            upload_results.append(upload_result)
                            logger.info(f"Successfully uploaded image {filename} for van #{van_number}")
            
            # Now process all damage assessments
            highest_damage_level = 0
            for upload_result in upload_results:
                try:
                    # Get damage assessment from Claude
                    damage_assessment = assess_damage_with_claude(upload_result['url'])
                    
                    # Update van with damage assessment
                    update_van_damage(van_id, damage_assessment, upload_result['url'])
                    
                    # Track highest damage level
                    damage_level = damage_assessment.get('damage_level', 0)
                    highest_damage_level = max(highest_damage_level, damage_level)
                    
                    # Get the saved image record
                    image_record = supabase.table('van_images').select('*').eq('image_url', upload_result['url']).single().execute()
                    
                    if image_record.data:
                        # Log the assessment with image ID
                        image_id = image_record.data['id']
                        damage_desc = damage_assessment.get('description', '')
                        logger.info(f"Image {image_id} for Van #{van_number} - Damage Level: {damage_level}/3, Description: {damage_desc}")
                except Exception as e:
                    logger.error(f"Error processing damage assessment for image {upload_result['url']}: {str(e)}")
                    continue
            
            # Update van's overall status based on highest damage level found
            if highest_damage_level > 0:
                update_data = {
                    'last_updated': datetime.now().isoformat(),
                    'rating': highest_damage_level
                }
                
                if highest_damage_level == 3:
                    update_data['status'] = 'Maintenance'
                
                supabase.table('vans').update(update_data).eq('id', van_id).execute()
                logger.info(f"Updated van {van_id} with highest damage level: {highest_damage_level}")
                    
    except Exception as e:
        logger.error(f"Error handling message: {str(e)}")
        raise

def main():
    """Main function to start the Slack bot."""
    logger.info("Starting Slack bot...")
    handler = SocketModeHandler(app, os.environ.get("SLACK_APP_TOKEN"))
    handler.start()

if __name__ == "__main__":
    main() 
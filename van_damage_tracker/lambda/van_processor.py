import json
import os
import boto3
import datetime
import mimetypes
import re
from typing import Dict, Any, Optional, List, Tuple
import logging
from supabase import create_client, Client

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize Supabase client
supabase: Client = create_client(
    os.environ.get('SUPABASE_URL'),
    os.environ.get('SUPABASE_KEY')
)

def extract_van_number(message_text: str) -> Optional[str]:
    """Extract van number from Slack message text."""
    # Pattern to match "van" followed by numbers, with optional space
    van_pattern = r'van\s*(\d+)'
    match = re.search(van_pattern, message_text.lower())
    if match:
        return match.group(1)
    return None

def get_public_url(bucket_name: str, file_path: str) -> str:
    """Get public URL for a file in Supabase storage."""
    try:
        return supabase.storage.from_(bucket_name).get_public_url(file_path)
    except Exception as e:
        logger.error(f"Error getting public URL: {e}")
        return ""

def get_signed_url(bucket_name: str, file_path: str, expiry: int = 3600) -> str:
    """Get signed URL for a file in Supabase storage."""
    try:
        result = supabase.storage.from_(bucket_name).create_signed_url(
            file_path,
            expiry  # URL expires in 1 hour by default
        )
        return result.get('signedURL', '')
    except Exception as e:
        logger.error(f"Error getting signed URL: {e}")
        return ""

def upload_image_to_storage(image_data: bytes, van_number: str, filename: str, content_type: Optional[str] = None) -> str:
    """Upload image to Supabase Storage and return the URL."""
    try:
        bucket_name = "van-images"
        # Organize images by van number
        file_path = f"van_{van_number}/{filename}"
        
        # Guess content type if not provided
        if not content_type:
            content_type = mimetypes.guess_type(filename)[0] or 'image/jpeg'
        
        # Upload the file
        result = supabase.storage.from_(bucket_name).upload(
            file_path,
            image_data,
            {"content-type": content_type}
        )
        
        # Get the URL - assuming public bucket
        if result:
            return get_public_url(bucket_name, file_path)
        
        return ""
    except Exception as e:
        logger.error(f"Error uploading image: {e}")
        return ""

def get_or_create_van(van_number: str) -> Tuple[str, Dict[str, Any]]:
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
            'date': datetime.datetime.now().isoformat(),
            'last_updated': datetime.datetime.now().isoformat(),
            'notes': '',
            'url': '',
            'driver': '',
            'damage': '',
            'damage_description': '',
            'rating': 0
        }
        
        create_result = supabase.table('vans').insert(new_van).execute()
        return 'new', create_result.data[0]
    except Exception as e:
        logger.error(f"Error in get_or_create_van: {e}")
        raise

def process_slack_message(event_data: Dict[str, Any]) -> Dict[str, Any]:
    """Process Slack message and update van profile."""
    try:
        # Extract message text and van number
        message_text = event_data.get('message_text', '')
        van_number = extract_van_number(message_text)
        
        if not van_number:
            raise ValueError("No van number found in message")
            
        # Get or create van profile
        status, van_data = get_or_create_van(van_number)
        
        # Handle images
        image_urls = []
        if 'images' in event_data and event_data['images']:
            for idx, image_data in enumerate(event_data['images']):
                # Assuming image_data is base64 encoded
                import base64
                decoded_image = base64.b64decode(image_data)
                timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
                filename = f"slack_image_{timestamp}_{idx}.jpg"
                
                image_url = upload_image_to_storage(
                    decoded_image,
                    van_number,
                    filename
                )
                if image_url:
                    image_urls.append(image_url)
        
        # Update van data
        update_data = {
            'last_updated': datetime.datetime.now().isoformat()
        }
        
        # Update URL only if we have new images
        if image_urls:
            # If there's an existing URL, append new ones; otherwise use the first new URL
            existing_url = van_data.get('url', '')
            if existing_url:
                update_data['url'] = f"{existing_url}, {', '.join(image_urls)}"
            else:
                update_data['url'] = image_urls[0]
        
        # Update notes if message contains text
        if message_text:
            existing_notes = van_data.get('notes', '')
            timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            new_note = f"[{timestamp}] {message_text}"
            update_data['notes'] = f"{existing_notes}\n{new_note}" if existing_notes else new_note
        
        # Update van in database
        result = supabase.table('vans').update(update_data).eq('id', van_data['id']).execute()
        
        if result.data:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f"Successfully {'updated' if status == 'existing' else 'created'} van profile",
                    'van_id': result.data[0]['id'],
                    'van_number': van_number,
                    'image_urls': image_urls
                })
            }
        else:
            raise Exception("No data returned from update operation")
            
    except Exception as e:
        logger.error(f"Error processing Slack message: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Error processing Slack message: {str(e)}'
            })
        }

def lambda_handler(event, context):
    """Main Lambda handler function."""
    try:
        # Log the incoming event
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Process the event body
        if 'body' in event:
            event_data = json.loads(event['body'])
        else:
            event_data = event
            
        # Process Slack message
        result = process_slack_message(event_data)
        
        return result
    except Exception as e:
        logger.error(f"Error in lambda_handler: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Error processing request: {str(e)}'
            })
        } 
#!/usr/bin/env python3
"""
Van Damage Tracker - Slack Bot (Real Storage Upload)
Actually uploads images to Supabase storage bucket AND creates database records.
"""

import os
import logging
import base64
import re
from datetime import datetime
from slack_bolt import App
from slack_bolt.adapter.socket_mode.websocket_client import SocketModeHandler
from supabase import create_client, Client
import requests
import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def extract_van_number(text: str) -> str:
    """Extract van number from message text."""
    if not text:
        return None
    
    # Look for patterns like: van 123, #456, van#789, etc.
    patterns = [
        r'van\s*#?(\d+)',
        r'#(\d+)',
        r'(\d{3,})'  # 3+ digit numbers
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text.lower())
        if match:
            return match.group(1)
    
    return None

def upload_to_storage_bucket(image_data: bytes, van_number: str, file_extension: str = "jpg") -> dict:
    """Upload image directly to Supabase storage bucket."""
    try:
        # Generate unique filename (folder == van_number text)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{van_number}/slack_image_{timestamp}.{file_extension}"
        
        logger.info(f"📤 Uploading {len(image_data)} bytes to storage bucket: {filename}")
        
        # Validate image data
        if not isinstance(image_data, bytes):
            raise ValueError(f"Invalid image data type: {type(image_data)}. Expected bytes.")
        
        # Upload to Supabase storage
        result = supabase.storage.from_("van-images").upload(
            path=filename,
            file=image_data,
            file_options={"contentType": f"image/{file_extension}"}
        )
        
        if result.status_code and result.status_code >= 400:
            raise Exception(result.text)
        
        public_url = supabase.storage.from_("van-images").get_public_url(filename)
        
        logger.info("✅ Uploaded successfully to storage bucket")
        return {"success": True, "url": public_url, "file_path": filename}
    except Exception as e:
        logger.error(f"❌ Storage upload failed: {e}")
        return {"success": False, "error": f"Storage upload failed: {e}"}

def save_image_metadata_to_db(van_number: str, image_url: str, file_path: str, image_size: int, uploader_id: str, original_filename: str, slack_file_info: dict) -> dict:
    """Save image record to database after successful storage upload."""
    try:
        # Step 1: Get or create the van record
        van_select_result = supabase.table('vans').select('van_number').eq('van_number', van_number).execute()
        
        if van_select_result.data:
            logger.info(f"✅ Found existing van #{van_number}")
        else:
            logger.info(f"🚐 Van #{van_number} not found, creating new record...")
            new_van_result = supabase.table('vans').insert({
                'van_number': van_number,
                'status': 'Active'  # Default status
            }).execute()
            
            if not new_van_result.data:
                error_details = new_van_result.error.details if new_van_result.error else "Unknown error"
                logger.error(f"❌ Failed to create van: {error_details}")
                return {"success": False, "error": f"Failed to create van: {error_details}"}
        
        # Step 2: Insert the new van_image record using van_number directly
        image_insert_result = supabase.table('van_images').insert({
            'van_id': str(van_number),  # Ensure van_number is a string
            'image_url': image_url,
            'file_path': file_path,
            'uploaded_by': uploader_id,
            'image_size': image_size,
            'original_filename': original_filename,
            'slack_metadata': slack_file_info,
            'description': f"Damage report for van #{van_number} from Slack"
        }).execute()
        
        if image_insert_result.data:
            image_id = image_insert_result.data[0]['id']
            logger.info(f"✅ Image record saved to database with ID: {image_id}")
            return {
                "success": True,
                "van_id": str(van_number),  # Return van_number as van_id
                "image_id": image_id,
                "file_path": file_path
            }
        else:
            error_details = image_insert_result.error.details if image_insert_result.error else "Unknown error"
            logger.error(f"❌ Failed to save image record to database: {error_details}")
            return {"success": False, "error": f"Failed to save image record: {error_details}"}
            
    except Exception as e:
        import traceback
        logger.error(f"❌ Database operation failed: {e}")
        logger.error(traceback.format_exc())
        return {"success": False, "error": str(e)}

def process_image(file_info: dict, van_number: str, say, client):
    """Orchestrate downloading, uploading, and saving metadata for a single image."""
    try:
        # Step 1: Download image from Slack
        image_data, file_extension, original_filename = download_image_from_slack(file_info, client)
        if not image_data:
            raise Exception("Failed to download image from Slack (image_data is empty)")

        logger.info(f"🔄 Starting complete image processing for van {van_number}")

        # Step 2: Save image using the working database function
        result = save_image_via_database_function(
            image_data=image_data,
            van_number=van_number,
            uploader_name="slack_bot"
        )

        if result and result.get("success"):
            public_url = result.get("storage_result", {}).get("url")
            logger.info(f"✅ Successfully processed and saved image: {public_url}")
            say(
                text=f"✅ *Damage report saved for Van #{van_number}*\n"
                     f"Image successfully uploaded and recorded.\n"
                     f"<{public_url}|View Image>"
            )
        else:
            error_msg = result.get('error', 'Unknown error')
            logger.error(f"❌ Failed to save image: {error_msg}")
            say(f":x: Failed to save damage report for Van #{van_number}\n:exclamation: Error: {error_msg}")

    except Exception as e:
        error_msg = str(e)
        logger.error(f"❌ Failed to process image: {error_msg}", exc_info=True)
        say(f":x: Failed to save damage report for Van #{van_number}\n:exclamation: Error: {error_msg}")

def download_image_from_slack(file_info: dict, client) -> (bytes, str, str):
    """Download image from Slack, returning its data, extension, and original name."""
    url = file_info.get("url_private_download")
    token = client.token
    original_filename = file_info.get("name", "unknown_file")
    mimetype = file_info.get("mimetype", "")
    
    try:
        logger.info(f"📥 Downloading image '{original_filename}' from Slack...")
        headers = {"Authorization": f"Bearer {token}"}
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()  # Raise HTTPError for bad responses (4xx or 5xx)
        
        image_data = response.content
        file_extension = get_file_extension(original_filename, mimetype)
        
        logger.info(f"✅ Downloaded {len(image_data)} bytes. Extension: '{file_extension}'")
        return image_data, file_extension, original_filename
            
    except requests.exceptions.RequestException as e:
        logger.error(f"❌ Error downloading image '{original_filename}': {e}")
        raise Exception(f"Failed to download image from Slack: {e}")

def get_file_extension(filename: str, mimetype: str) -> str:
    """Get appropriate file extension from filename or mimetype."""
    if filename and '.' in filename:
        return filename.split('.')[-1].lower()
    
    # Map common mimetypes to extensions
    mimetype_map = {
        'image/jpeg': 'jpg',
        'image/jpg': 'jpg',
        'image/png': 'png',
        'image/webp': 'webp',
        'image/gif': 'gif'
    }
    
    return mimetype_map.get(mimetype, 'jpg')

def save_image_via_database_function(image_data: bytes, van_number: str, uploader_name: str = "slack_bot") -> dict:
    """Save image using the working database function instead of direct storage upload."""
    try:
        # Convert image to base64
        image_base64 = base64.b64encode(image_data).decode('utf-8')
        
        logger.info(f"📤 Saving image for van {van_number} via database function...")
        
        # Use the working save_slack_image function
        result = supabase.rpc('save_slack_image', {
            'van_number': str(van_number),  # Ensure van_number is a string
            'image_data': image_base64,
            'uploader_name': uploader_name
        }).execute()
        
        if result.data:
            # Check if the response indicates success
            if result.data.get('success') == True:
                logger.info("✅ Image saved successfully via database function!")
                return {
                    "success": True,
                    "van_id": str(van_number),  # Use van_number directly
                    "image_id": result.data.get('image_id'),
                    "file_path": result.data.get('file_path'),
                    "storage_result": result.data.get('storage_result', {})
                }
            else:
                error_msg = result.data.get('error', 'Database function returned success=false')
                logger.error(f"❌ Database function failed: {error_msg}")
                return {"success": False, "error": error_msg}
        else:
            logger.error("❌ Database function returned no data")
            return {"success": False, "error": "No data returned from database function"}
            
    except Exception as e:
        logger.error(f"❌ Database function error: {e}")
        return {"success": False, "error": str(e)}

# Initialize Supabase client
supabase_url = os.environ.get('SUPABASE_URL')
supabase_key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')
supabase: Client = create_client(supabase_url, supabase_key)

# Initialize Slack app
app = App(
    token=os.environ.get('SLACK_BOT_TOKEN'),
    signing_secret=os.environ.get('SLACK_SIGNING_SECRET')
)

@app.event("file_shared")
def handle_file_shared_events(body, logger):
    """Acknowledge file_shared events to prevent warnings."""
    logger.info("Ignoring 'file_shared' event to avoid noise.")
    pass

@app.event("message")
def handle_message_events(body, say, client):
    """Handle message events with file uploads."""
    try:
        event = body.get("event", {})
        
        # Skip bot messages
        if event.get("bot_id"):
            return
        
        message_text = event.get("text", "")
        files = event.get("files", [])
        
        # Extract van number
        van_number = extract_van_number(message_text)
        if not van_number:
            logger.info("No van number found in message")
            return
        
        logger.info(f"🚐 Processing message for van #{van_number}")
        
        # Process images
        if files:
            for file_info in files:
                if file_info.get('mimetype', '').startswith('image/'):
                    logger.info(f"📷 Processing image: {file_info.get('name', 'unknown')}")
                    
                    # Download image
                    file_url = file_info.get("url_private_download") or file_info.get("url_private")
                    if not file_url:
                        logger.error("❌ No download URL found")
                        continue
                    
                    logger.info("📥 Downloading image from Slack...")
                    headers = {"Authorization": f"Bearer {os.environ.get('SLACK_BOT_TOKEN')}"}
                    response = requests.get(file_url, headers=headers, timeout=30)
                    
                    if response.status_code != 200:
                        logger.error(f"❌ Download failed: {response.status_code}")
                        continue
                    
                    image_data = response.content
                    logger.info(f"✅ Downloaded image ({len(image_data)} bytes)")
                    
                    # Save image using database function
                    save_result = save_image_via_database_function(image_data, van_number)
                    
                    if save_result.get('success'):
                        # Get the public URL from the storage result
                        public_url = save_result.get('storage_result', {}).get('url')
                        if public_url:
                            say(
                                text=f"✅ *Damage report saved for Van #{van_number}*\n"
                                     f"Image successfully uploaded and recorded.\n"
                                     f"<{public_url}|View Image>"
                            )
                        else:
                            say(f"✅ Image saved for Van #{van_number}, but URL not available.")
                    else:
                        error_msg = save_result.get('error', 'Unknown error')
                        say(f"❌ Failed to save image for Van #{van_number}: {error_msg}")
                        
    except Exception as e:
        logger.error(f"❌ Error processing message: {e}")
        say(f"❌ An error occurred while processing the message: {str(e)}")

@app.message("help")
def handle_help(message, say):
    """Show help message."""
    help_text = """
*Van Damage Tracker - Help*
Upload images of van damage by mentioning the van number in your message:
• Use `van 123` or `#123` format
• Attach one or more images
• The bot will save the images and create damage reports

*Examples:*
> Damage report for van #456 [+ image attachment]
> Here's the dent in van 789 [+ image attachment]
"""
    say(help_text)

def validate_environment():
    """Validate all required environment variables are present."""
    required_vars = [
        'SLACK_BOT_TOKEN',
        'SLACK_APP_TOKEN',
        'SLACK_SIGNING_SECRET',
        'SUPABASE_URL',
        'SUPABASE_SERVICE_ROLE_KEY'
    ]
    
    missing = [var for var in required_vars if not os.environ.get(var)]
    
    if missing:
        raise ValueError(f"Missing environment variables: {', '.join(missing)}")
    else:
        logger.info("✅ All environment variables present")

if __name__ == "__main__":
    # Validate environment
    validate_environment()
    logger.info("✅ Environment validated")
    logger.info("✅ Real storage bucket uploads enabled")
    logger.info("✅ Complete image processing (storage + database)")
    
    # Start the app
    logger.info("🔄 Starting bot...")
    handler = SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"])
    handler.start() 
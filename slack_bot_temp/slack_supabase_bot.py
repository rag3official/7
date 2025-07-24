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

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

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

def get_or_create_driver_profile(user_id: str, user_info: dict) -> tuple[str, dict]:
    """Get existing driver profile or create a new one."""
    try:
        # Try to get existing driver
        result = supabase.table('driver_profiles').select('*').eq('id', user_id).execute()
        
        if result.data and len(result.data) > 0:
            return 'existing', result.data[0]
        
        # Create new driver profile if it doesn't exist
        new_driver = {
            'id': user_id,
            'name': user_info.get('real_name', 'Unknown'),
            'email': user_info.get('profile', {}).get('email', ''),
            'phone_number': user_info.get('profile', {}).get('phone', ''),
            'status': 'active',
            'license_number': '',  # To be updated later
            'license_expiry': (datetime.now() + timedelta(days=365)).isoformat(),  # Default 1 year
            'certifications': [],
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat()
        }
        
        create_result = supabase.table('driver_profiles').insert(new_driver).execute()
        return 'new', create_result.data[0]
    except Exception as e:
        logger.error(f"Error in get_or_create_driver_profile: {e}")
        raise

def update_driver_profile(user_id: str, updates: dict) -> dict:
    """Update driver profile with new information."""
    try:
        updates['updated_at'] = datetime.now().isoformat()
        result = supabase.table('driver_profiles').update(updates).eq('id', user_id).execute()
        return result.data[0] if result.data else None
    except Exception as e:
        logger.error(f"Error updating driver profile: {e}")
        raise

def handle_driver_profile(event: dict, client) -> None:
    """Handle driver profile creation/update when a message is received."""
    try:
        user_id = event.get('user')
        if not user_id:
            return

        # Get user info from Slack
        user_info = client.users_info(user=user_id)['user']
        
        # Get or create driver profile
        status, driver_data = get_or_create_driver_profile(user_id, user_info)
        
        if status == 'new':
            logger.info(f"Created new driver profile for user {user_id}")
            
            # Send welcome message
            welcome_blocks = [
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": f"Welcome to the van fleet management system! 👋\nI've created a driver profile for you. Please update your information using the buttons below:"
                    }
                },
                {
                    "type": "actions",
                    "elements": [
                        {
                            "type": "button",
                            "text": {
                                "type": "plain_text",
                                "text": "Update License Info"
                            },
                            "value": "update_license",
                            "action_id": "update_license"
                        },
                        {
                            "type": "button",
                            "text": {
                                "type": "plain_text",
                                "text": "Update Contact Info"
                            },
                            "value": "update_contact",
                            "action_id": "update_contact"
                        }
                    ]
                }
            ]
            
            client.chat_postEphemeral(
                channel=event['channel'],
                user=user_id,
                blocks=welcome_blocks
            )
    except Exception as e:
        logger.error(f"Error handling driver profile: {e}")
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
        
        # Skip messages from bots
        if 'bot_id' in event:
            logger.info("Skipping bot message")
            return
            
        # Handle driver profile
        handle_driver_profile(event, client)
        
        message_text = event.get('text', '')
        
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
                        filename = f"slack_image_{timestamp}.jpg"
                        
                        # Upload to Supabase
                        public_url = upload_to_supabase_storage(
                            image_data,
                            van_number,
                            filename
                        )
                        
                        if public_url:
                            # Get damage assessment from Claude
                            damage_assessment = assess_damage_with_claude(public_url)
                            
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
                            
                            say(reply)
        
    except Exception as e:
        logger.error(f"Error handling message: {str(e)}")
        raise

@app.action("update_license")
def handle_update_license(ack, body, client):
    """Handle license info update request."""
    ack()
    try:
        # Open a modal for license info update
        client.views_open(
            trigger_id=body["trigger_id"],
            view={
                "type": "modal",
                "callback_id": "license_update",
                "title": {"type": "plain_text", "text": "Update License Info"},
                "submit": {"type": "plain_text", "text": "Submit"},
                "blocks": [
                    {
                        "type": "input",
                        "block_id": "license_number",
                        "label": {"type": "plain_text", "text": "License Number"},
                        "element": {
                            "type": "plain_text_input",
                            "action_id": "license_number_input"
                        }
                    },
                    {
                        "type": "input",
                        "block_id": "license_expiry",
                        "label": {"type": "plain_text", "text": "License Expiry Date"},
                        "element": {
                            "type": "datepicker",
                            "action_id": "license_expiry_input"
                        }
                    }
                ]
            }
        )
    except Exception as e:
        logger.error(f"Error opening license update modal: {e}")

@app.action("update_contact")
def handle_update_contact(ack, body, client):
    """Handle contact info update request."""
    ack()
    try:
        # Open a modal for contact info update
        client.views_open(
            trigger_id=body["trigger_id"],
            view={
                "type": "modal",
                "callback_id": "contact_update",
                "title": {"type": "plain_text", "text": "Update Contact Info"},
                "submit": {"type": "plain_text", "text": "Submit"},
                "blocks": [
                    {
                        "type": "input",
                        "block_id": "phone",
                        "label": {"type": "plain_text", "text": "Phone Number"},
                        "element": {
                            "type": "plain_text_input",
                            "action_id": "phone_input"
                        }
                    },
                    {
                        "type": "input",
                        "block_id": "email",
                        "label": {"type": "plain_text", "text": "Email"},
                        "element": {
                            "type": "plain_text_input",
                            "action_id": "email_input",
                            "type": "email"
                        }
                    }
                ]
            }
        )
    except Exception as e:
        logger.error(f"Error opening contact update modal: {e}")

@app.view("license_update")
def handle_license_submission(ack, body, client):
    """Handle license info submission."""
    ack()
    try:
        user_id = body["user"]["id"]
        values = body["view"]["state"]["values"]
        
        updates = {
            'license_number': values["license_number"]["license_number_input"]["value"],
            'license_expiry': values["license_expiry"]["license_expiry_input"]["selected_date"]
        }
        
        update_driver_profile(user_id, updates)
        
        client.chat_postEphemeral(
            channel=body["user"]["id"],
            user=user_id,
            text="✅ License information updated successfully!"
        )
    except Exception as e:
        logger.error(f"Error handling license submission: {e}")

@app.view("contact_update")
def handle_contact_submission(ack, body, client):
    """Handle contact info submission."""
    ack()
    try:
        user_id = body["user"]["id"]
        values = body["view"]["state"]["values"]
        
        updates = {
            'phone_number': values["phone"]["phone_input"]["value"],
            'email': values["email"]["email_input"]["value"]
        }
        
        update_driver_profile(user_id, updates)
        
        client.chat_postEphemeral(
            channel=body["user"]["id"],
            user=user_id,
            text="✅ Contact information updated successfully!"
        )
    except Exception as e:
        logger.error(f"Error handling contact submission: {e}")

def main():
    """Main function to start the Slack bot."""
    logger.info("Starting Slack bot...")
    handler = SocketModeHandler(app, os.environ.get("SLACK_APP_TOKEN"))
    handler.start()

if __name__ == "__main__":
    main() 
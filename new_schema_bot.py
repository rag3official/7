#!/usr/bin/env python3
"""
🚀 NEW SCHEMA Slack Bot - Updated for van_profiles, driver_profiles, van_images schema
Handles van fleet management with comprehensive driver and van profile tracking
"""

import os
import re
import sys
import json
import logging
import requests
from datetime import datetime
from typing import Optional, Dict, Any
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from supabase import create_client, Client

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class NewSchemaSlackBot:
    def __init__(self):
        logger.info("🚀 Starting NEW SCHEMA Slack Bot...")
        logger.info("📁 Focus: Updated for van_profiles, driver_profiles, van_images schema")
        
        # Load environment variables
        self.slack_bot_token = os.getenv("SLACK_BOT_TOKEN")
        self.slack_app_token = os.getenv("SLACK_APP_TOKEN")
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        
        # Validate environment variables
        required_vars = [
            "SLACK_BOT_TOKEN", "SLACK_APP_TOKEN", 
            "SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"
        ]
        
        missing_vars = [var for var in required_vars if not os.getenv(var)]
        if missing_vars:
            logger.error(f"❌ Missing environment variables: {missing_vars}")
            sys.exit(1)
        
        logger.info("✅ All environment variables found")
        
        # Initialize Supabase client
        self.supabase: Client = create_client(self.supabase_url, self.supabase_key)
        
        # Initialize Slack app
        self.app = App(token=self.slack_bot_token)
        
        # Register event handlers
        self.register_handlers()
        
        # Van number patterns
        self.van_patterns = [
            r'van\s*#?(\d+)',
            r'#(\d+)',
            r'\b(\d{3})\b'  # 3-digit numbers
        ]
        
        # Damage keywords
        self.damage_keywords = [
            'damage', 'dent', 'scratch', 'scrape', 'ding', 'crack', 'broken',
            'bent', 'torn', 'ripped', 'loose', 'missing', 'worn', 'chipped'
        ]
        
        # Rating patterns
        self.rating_patterns = [
            r'rating[:\s]*(\d)',
            r'condition[:\s]*(\d)',
            r'(\d)/3',
            r'rate[:\s]*(\d)'
        ]

    def register_handlers(self):
        """Register all Slack event handlers"""
        self.app.event("file_shared")(self.handle_file_shared)
        self.app.event("file_created")(self.handle_file_created)
        self.app.event("message")(self.handle_message_with_file)

    async def handle_file_shared(self, event, say, client):
        """Handle file_shared events"""
        try:
            logger.info("📁 Received file_shared event")
            logger.info(f"📁 Event data: {json.dumps(event, indent=2)}...")
            
            await self.process_file_event(event, say, client, "file_shared")
            
        except Exception as e:
            logger.error(f"❌ Error in handle_file_shared: {e}")

    async def handle_file_created(self, event, say, client):
        """Handle file_created events"""
        try:
            logger.info("📁 Received file_created event")
            await self.process_file_event(event, say, client, "file_created")
            
        except Exception as e:
            logger.error(f"❌ Error in handle_file_created: {e}")

    async def handle_message_with_file(self, event, say, client):
        """Handle message events that might contain files"""
        try:
            if event.get("subtype") == "file_share" and "files" in event:
                logger.info("📁 Received message with file_share subtype")
                for file_info in event["files"]:
                    # Create a synthetic event for consistency
                    synthetic_event = {
                        "file_id": file_info["id"],
                        "user_id": event["user"],
                        "channel_id": event["channel"],
                        "file": file_info,
                        "event_ts": event["ts"]
                    }
                    await self.process_file_event(synthetic_event, say, client, "message_file_share")
                    
        except Exception as e:
            logger.error(f"❌ Error in handle_message_with_file: {e}")

    async def process_file_event(self, event, say, client, event_type):
        """Process file events and upload to Supabase"""
        try:
            logger.info(f"📁 Processing file from {event_type} event")
            
            file_id = event.get("file_id")
            channel_id = event.get("channel_id")
            user_id = event.get("user_id")
            
            logger.info(f"📁 File ID: {file_id}")
            logger.info(f"📁 Channel ID: {channel_id}")
            
            if not file_id:
                logger.warning("⚠️ No file_id found in event")
                return
            
            # Get file info
            file_info = event.get("file")
            if not file_info or not file_info.get("mimetype"):
                logger.info("🔄 File info is minimal, fetching complete details...")
                file_info = await self.get_complete_file_info(client, file_id)
            
            if not file_info:
                logger.error("❌ Could not retrieve file information")
                return
            
            # Check if it's an image
            mimetype = file_info.get("mimetype", "")
            logger.info(f"📄 File mimetype: {mimetype}")
            
            if not mimetype.startswith("image/"):
                logger.info(f"⏭️ Skipping non-image file: {mimetype}")
                return
            
            # Look for van number in recent messages
            van_number = await self.find_van_number_in_context(client, channel_id, user_id)
            
            if not van_number:
                logger.warning("⚠️ No van number found in context")
                await say(":warning: Please mention a van number (e.g., 'van 123') when uploading images")
                return
            
            # Get or create driver profile
            driver_profile = await self.get_or_create_driver_profile(client, user_id)
            if not driver_profile:
                logger.error("❌ Could not create driver profile")
                return
            
            # Get or create van profile
            van_profile = await self.get_or_create_van_profile(van_number, driver_profile["id"])
            if not van_profile:
                logger.error("❌ Could not create van profile")
                return
            
            # Process the image
            success = await self.process_image_upload(
                file_info, van_profile, driver_profile, user_id, channel_id
            )
            
            if success:
                # Look for damage description and rating
                damage_info = await self.extract_damage_info(client, channel_id)
                
                success_msg = f":white_check_mark: Successfully uploaded image for van {van_number}"
                if damage_info.get("description"):
                    success_msg += f"\n:memo: Damage: {damage_info['description']}"
                if damage_info.get("rating") is not None:
                    success_msg += f"\n:star: Rating: {damage_info['rating']}/3"
                    
                await say(success_msg)
                logger.info("✅ Upload successful")
            else:
                await say(f":x: Failed to upload image for van {van_number}")
                logger.error("❌ Upload failed")
                
        except Exception as e:
            logger.error(f"❌ Error processing file event: {e}")
            await say(":x: An error occurred while processing the image")

    async def get_complete_file_info(self, client, file_id: str) -> Optional[Dict]:
        """Get complete file information from Slack API"""
        try:
            logger.info(f"🔍 Fetching complete file info for ID: {file_id}")
            
            response = await client.files_info(file=file_id)
            
            if response["ok"]:
                file_info = response["file"]
                logger.info(f"✅ Retrieved complete file info: {file_info.get('name', 'Unknown')} ({file_info.get('mimetype', 'Unknown')})")
                return file_info
            else:
                logger.error(f"❌ Failed to get file info: {response.get('error', 'Unknown error')}")
                return None
                
        except Exception as e:
            logger.error(f"❌ Error getting complete file info: {e}")
            return None

    async def find_van_number_in_context(self, client, channel_id: str, user_id: str) -> Optional[int]:
        """Find van number in recent channel messages"""
        try:
            # Get recent messages from the channel
            response = await client.conversations_history(
                channel=channel_id,
                limit=10
            )
            
            if not response["ok"]:
                logger.error(f"❌ Failed to get channel history: {response.get('error')}")
                return None
            
            # Look through messages for van numbers
            for message in response["messages"]:
                text = message.get("text", "").lower()
                
                # Log the text we're analyzing
                logger.info(f"🔍 Analyzing text for van number: '{text}'")
                
                for pattern in self.van_patterns:
                    match = re.search(pattern, text, re.IGNORECASE)
                    if match:
                        van_number = int(match.group(1))
                        logger.info(f"✅ Found van number using pattern '{pattern}': {van_number}")
                        logger.info(f"✅ Found van number {van_number} in recent message")
                        return van_number
            
            logger.warning("⚠️ No van number found in recent messages")
            return None
            
        except Exception as e:
            logger.error(f"❌ Error finding van number: {e}")
            return None

    async def get_or_create_driver_profile(self, client, slack_user_id: str) -> Optional[Dict]:
        """Get or create driver profile from Slack user ID"""
        try:
            # First check if driver profile exists
            response = self.supabase.table("driver_profiles").select("*").eq("slack_user_id", slack_user_id).execute()
            
            if response.data:
                logger.info(f"✅ Found existing driver profile: {response.data[0]['driver_name']}")
                return response.data[0]
            
            # Get user info from Slack
            user_response = await client.users_info(user=slack_user_id)
            if not user_response["ok"]:
                logger.error(f"❌ Failed to get user info: {user_response.get('error')}")
                return None
            
            user_info = user_response["user"]
            driver_name = user_info.get("real_name", user_info.get("name", f"User-{slack_user_id}"))
            email = user_info.get("profile", {}).get("email", f"{slack_user_id}@slack.local")
            
            # Create new driver profile
            new_driver = {
                "slack_user_id": slack_user_id,
                "driver_name": driver_name,
                "email": email,
                "status": "active"
            }
            
            response = self.supabase.table("driver_profiles").insert(new_driver).execute()
            
            if response.data:
                logger.info(f"✅ Created new driver profile: {driver_name}")
                return response.data[0]
            else:
                logger.error("❌ Failed to create driver profile")
                return None
                
        except Exception as e:
            logger.error(f"❌ Error getting/creating driver profile: {e}")
            return None

    async def get_or_create_van_profile(self, van_number: int, driver_id: str) -> Optional[Dict]:
        """Get or create van profile"""
        try:
            logger.info(f"🔍 Looking for van #{van_number}")
            
            # Check if van profile exists
            response = self.supabase.table("van_profiles").select("*").eq("van_number", van_number).execute()
            
            if response.data:
                van_profile = response.data[0]
                # Update current driver if different
                if van_profile.get("current_driver_id") != driver_id:
                    update_response = self.supabase.table("van_profiles").update({
                        "current_driver_id": driver_id,
                        "updated_at": datetime.utcnow().isoformat()
                    }).eq("id", van_profile["id"]).execute()
                    
                    if update_response.data:
                        logger.info(f"✅ Updated van #{van_number} current driver")
                        return update_response.data[0]
                
                logger.info(f"✅ Found existing van #{van_number}")
                return van_profile
            
            # Create new van profile
            new_van = {
                "van_number": van_number,
                "make": "Unknown",
                "model": "Unknown", 
                "year": None,
                "status": "active",
                "current_driver_id": driver_id
            }
            
            response = self.supabase.table("van_profiles").insert(new_van).execute()
            
            if response.data:
                logger.info(f"✅ Created new van #{van_number}")
                return response.data[0]
            else:
                logger.error(f"❌ Failed to create van profile")
                return None
                
        except Exception as e:
            logger.error(f"❌ Error getting/creating van profile: {e}")
            return None

    async def process_image_upload(self, file_info: Dict, van_profile: Dict, driver_profile: Dict, user_id: str, channel_id: str) -> bool:
        """Process and upload image to Supabase storage"""
        try:
            logger.info(f"📷 Processing image for van #{van_profile['van_number']}")
            
            # Get file download URL
            file_url = self.get_file_download_url(file_info)
            if not file_url:
                logger.error("❌ Could not get file download URL")
                return False
            
            # Download the image
            image_data = await self.download_image(file_url)
            if not image_data:
                logger.error("❌ Could not download image")
                return False
            
            # Generate storage path
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            file_extension = self.get_file_extension(file_info.get("mimetype", "image/jpeg"))
            storage_path = f"van_{van_profile['van_number']}/image_{timestamp}.{file_extension}"
            
            # Upload to Supabase storage
            success = await self.upload_to_storage(image_data, storage_path, file_info.get("mimetype", "image/jpeg"))
            
            if success:
                # Create database record
                image_url = f"{self.supabase_url}/storage/v1/object/public/van-images/{storage_path}"
                
                # Get damage info from recent messages
                damage_info = await self.extract_damage_info_from_channel(channel_id)
                
                image_record = {
                    "van_id": van_profile["id"],
                    "van_number": van_profile["van_number"],
                    "driver_id": driver_profile["id"],
                    "slack_user_id": user_id,
                    "image_url": image_url,
                    "file_path": storage_path,
                    "file_size": file_info.get("size"),
                    "content_type": file_info.get("mimetype", "image/jpeg"),
                    "van_damage": damage_info.get("description"),
                    "van_rating": damage_info.get("rating"),
                    "upload_method": "slack_bot",
                    "upload_source": "slack_channel"
                }
                
                db_response = self.supabase.table("van_images").insert(image_record).execute()
                
                if db_response.data:
                    logger.info("✅ Created database record for image")
                    return True
                else:
                    logger.error("❌ Failed to create database record")
                    return False
            
            return False
            
        except Exception as e:
            logger.error(f"❌ Error processing image upload: {e}")
            return False

    def get_file_download_url(self, file_info: Dict) -> Optional[str]:
        """Get the download URL for a Slack file"""
        try:
            # Log available fields for debugging
            logger.info(f"🔗 File info keys: {list(file_info.keys())}")
            
            # Try different URL fields in order of preference
            url_fields = ["url_private_download", "url_private", "permalink_public", "url"]
            
            for field in url_fields:
                if field in file_info and file_info[field]:
                    logger.info(f"✅ Found file URL in field \"{field}\": {file_info[field][:50]}...")
                    return file_info[field]
            
            logger.error("❌ No valid download URL found in file info")
            return None
            
        except Exception as e:
            logger.error(f"❌ Error getting file download URL: {e}")
            return None

    async def download_image(self, url: str) -> Optional[bytes]:
        """Download image from Slack"""
        try:
            logger.info(f"📥 Downloading image from Slack: {url[:50]}...")
            
            headers = {
                "Authorization": f"Bearer {self.slack_bot_token}"
            }
            
            response = requests.get(url, headers=headers)
            response.raise_for_status()
            
            logger.info(f"✅ Successfully downloaded image ({len(response.content)} bytes)")
            return response.content
            
        except Exception as e:
            logger.error(f"❌ Error downloading image: {e}")
            return None

    async def upload_to_storage(self, image_data: bytes, storage_path: str, content_type: str) -> bool:
        """Upload image to Supabase storage"""
        try:
            logger.info(f"📤 Uploading to path: {storage_path}")
            
            # Use the storage client to upload
            response = self.supabase.storage.from_("van-images").upload(
                path=storage_path,
                file=image_data,
                file_options={
                    "content-type": content_type,
                    "cache-control": "3600"
                }
            )
            
            if hasattr(response, 'error') and response.error:
                logger.error(f"❌ Storage upload failed: {response.error}")
                return False
            
            logger.info("✅ Successfully uploaded to Supabase storage")
            return True
            
        except Exception as e:
            logger.error(f"❌ Error uploading to storage: {e}")
            return False

    def get_file_extension(self, mimetype: str) -> str:
        """Get file extension from mimetype"""
        mime_to_ext = {
            "image/jpeg": "jpg",
            "image/jpg": "jpg", 
            "image/png": "png",
            "image/gif": "gif",
            "image/webp": "webp",
            "image/bmp": "bmp"
        }
        return mime_to_ext.get(mimetype, "jpg")

    async def extract_damage_info(self, client, channel_id: str) -> Dict[str, Any]:
        """Extract damage description and rating from recent messages"""
        try:
            response = await client.conversations_history(
                channel=channel_id,
                limit=10
            )
            
            if not response["ok"]:
                return {}
            
            damage_info = {"description": None, "rating": None}
            
            for message in response["messages"]:
                text = message.get("text", "").lower()
                
                # Look for damage keywords
                if not damage_info["description"]:
                    for keyword in self.damage_keywords:
                        if keyword in text:
                            # Extract sentence containing damage keyword
                            sentences = text.split('.')
                            for sentence in sentences:
                                if keyword in sentence:
                                    damage_info["description"] = sentence.strip()
                                    break
                            break
                
                # Look for rating
                if damage_info["rating"] is None:
                    for pattern in self.rating_patterns:
                        match = re.search(pattern, text)
                        if match:
                            rating = int(match.group(1))
                            if 0 <= rating <= 3:
                                damage_info["rating"] = rating
                                break
            
            return damage_info
            
        except Exception as e:
            logger.error(f"❌ Error extracting damage info: {e}")
            return {}

    async def extract_damage_info_from_channel(self, channel_id: str) -> Dict[str, Any]:
        """Extract damage info from channel (simplified version)"""
        # For now, return empty dict - can be enhanced later
        return {"description": None, "rating": None}

    def run(self):
        """Start the Slack bot"""
        try:
            logger.info("🚀 Starting Slack bot with Socket Mode...")
            handler = SocketModeHandler(self.app, self.slack_app_token)
            handler.start()
            
        except Exception as e:
            logger.error(f"❌ Error starting bot: {e}")
            sys.exit(1)

def main():
    """Main entry point"""
    bot = NewSchemaSlackBot()
    bot.run()

if __name__ == "__main__":
    main() 
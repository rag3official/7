#!/usr/bin/env python3
"""
🚀 STORAGE BYPASS Slack Bot - Direct HTTP upload to bypass storage constraints
Handles van fleet management with comprehensive driver and van profile tracking
"""

import os
import re
import sys
import json
import logging
import requests
import base64
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

class StorageBypassSlackBot:
    def __init__(self):
        logger.info("🚀 Starting STORAGE BYPASS Slack Bot...")
        logger.info("📁 Focus: Direct HTTP upload to bypass storage constraints")
        
        # Load environment variables
        self.slack_bot_token = os.getenv("SLACK_BOT_TOKEN")
        self.slack_app_token = os.getenv("SLACK_APP_TOKEN")
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_KEY")
        
        # Validate environment variables
        required_vars = [
            "SLACK_BOT_TOKEN", "SLACK_APP_TOKEN", 
            "SUPABASE_URL", "SUPABASE_KEY"
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

    def register_handlers(self):
        """Register all Slack event handlers"""
        self.app.event("file_shared")(self.handle_file_shared)
        self.app.event("file_created")(self.handle_file_created)
        self.app.event("message")(self.handle_message_with_file)

    def handle_file_shared(self, event, say, client):
        """Handle file_shared events - SYNCHRONOUS"""
        try:
            logger.info("📁 Received file_shared event")
            logger.info(f"📁 Event data: {json.dumps(event, indent=2)}...")
            
            self.process_file_event(event, say, client, "file_shared")
            
        except Exception as e:
            logger.error(f"❌ Error in handle_file_shared: {e}")

    def handle_file_created(self, event, say, client):
        """Handle file_created events - SYNCHRONOUS"""
        try:
            logger.info("📁 Received file_created event")
            self.process_file_event(event, say, client, "file_created")
            
        except Exception as e:
            logger.error(f"❌ Error in handle_file_created: {e}")

    def handle_message_with_file(self, event, say, client):
        """Handle message events that might contain files - SYNCHRONOUS"""
        try:
            if event.get("subtype") == "file_share" and "files" in event:
                logger.info("📁 Received message with file_share subtype")
                for file_info in event["files"]:
                    # Create a synthetic event for consistency
                    synthetic_event = {
                        "file_id": file_info["id"],
                        "user_id": event["user"],
                        "channel_id": event["channel"],
                        "event_ts": event["ts"],
                        "file": file_info
                    }
                    self.process_file_event(synthetic_event, say, client, "message_file_share")
        except Exception as e:
            logger.error(f"❌ Error in handle_message_with_file: {e}")

    def process_file_event(self, event, say, client, event_type):
        """Process file events and upload to Supabase - SYNCHRONOUS"""
        try:
            file_id = event.get("file_id")
            channel_id = event.get("channel_id")
            user_id = event.get("user_id")
            
            logger.info(f"📁 Processing file from {event_type} event")
            logger.info(f"📁 File ID: {file_id}")
            logger.info(f"📁 Channel ID: {channel_id}")
            
            # Get file info
            file_info = event.get("file")
            if not file_info or not file_info.get("name"):
                logger.info("🔄 File info is minimal, fetching complete details...")
                file_info = self.get_file_info(client, file_id)
                if not file_info:
                    logger.error("❌ Could not retrieve file information")
                    return
            
            logger.info(f"✅ Retrieved complete file info: {file_info.get('name')} ({file_info.get('mimetype')})")
            
            # Check if it's an image
            if not self.is_image_file(file_info):
                logger.info("📄 File is not an image, skipping")
                return
            
            logger.info(f"📄 File mimetype: {file_info.get('mimetype')}")
            
            # Find van number in recent messages
            van_number = self.find_van_number_in_context(client, channel_id, user_id)
            if not van_number:
                logger.info("❌ No van number found in recent messages")
                say("❌ Please mention a van number (e.g., 'van 123' or '#123') when uploading images")
                return
            
            logger.info(f"✅ Found van number {van_number} in recent message")
            
            # Get or create driver profile
            driver_profile = self.get_or_create_driver_profile(user_id, client)
            if not driver_profile:
                logger.error("❌ Could not create driver profile")
                say("❌ Failed to create driver profile")
                return
            
            # Get or create van profile
            van_profile = self.get_or_create_van_profile(van_number, driver_profile['id'])
            if not van_profile:
                logger.error("❌ Could not create van profile")
                say("❌ Failed to create van profile")
                return
            
            # Parse damage info from recent messages
            damage_info = self.parse_damage_info_from_context(client, channel_id, user_id)
            
            # Process and upload image using direct HTTP method
            success = self.process_and_upload_image_direct(
                file_info, van_profile, driver_profile, damage_info, client, channel_id
            )
            
            if success:
                # Send success message with details
                van_rating = damage_info.get('rating', 'Not specified')
                van_damage = damage_info.get('description', 'No damage description')
                driver_name = driver_profile.get('driver_name', 'Unknown')
                
                success_msg = (
                    f"✅ Image uploaded successfully!\n"
                    f"🚐 Van: #{van_number}\n"
                    f"👤 Driver: {driver_name}\n"
                    f"⭐ Rating: {van_rating}/3\n"
                    f"📝 Damage: {van_damage}"
                )
                say(success_msg)
            else:
                say(f"❌ Failed to upload image for van {van_number}")
                
        except Exception as e:
            logger.error(f"❌ Error processing file event: {e}")
            say("❌ Error processing image upload")

    def get_file_info(self, client, file_id):
        """Get complete file information from Slack"""
        try:
            logger.info(f"🔍 Fetching complete file info for ID: {file_id}")
            response = client.files_info(file=file_id)
            if response.get("ok"):
                return response.get("file")
            else:
                logger.error(f"❌ Failed to get file info: {response.get('error')}")
                return None
        except Exception as e:
            logger.error(f"❌ Error getting file info: {e}")
            return None

    def is_image_file(self, file_info):
        """Check if the file is an image"""
        mimetype = file_info.get("mimetype", "")
        return mimetype.startswith("image/")

    def find_van_number_in_context(self, client, channel_id, user_id):
        """Find van number in recent channel messages"""
        try:
            # Get recent messages from the channel
            response = client.conversations_history(
                channel=channel_id,
                limit=20
            )
            
            if not response.get("ok"):
                logger.error(f"❌ Failed to get channel history: {response.get('error')}")
                return None
            
            messages = response.get("messages", [])
            
            # Look for van numbers in recent messages
            van_patterns = [
                r'van\s*#?(\d+)',
                r'#(\d+)',
                r'\b(\d{3})\b'  # 3-digit numbers
            ]
            
            for message in messages:
                text = message.get("text", "").lower()
                logger.info(f"🔍 Analyzing text for van number: '{text}'")
                
                for pattern in van_patterns:
                    matches = re.findall(pattern, text, re.IGNORECASE)
                    if matches:
                        van_number = matches[0]
                        logger.info(f"✅ Found van number using pattern '{pattern}': {van_number}")
                        return van_number
            
            return None
            
        except Exception as e:
            logger.error(f"❌ Error finding van number: {e}")
            return None

    def get_or_create_driver_profile(self, slack_user_id, client):
        """Get existing driver profile or create new one"""
        try:
            # First, try to find existing driver
            logger.info(f"🔍 Looking for driver with Slack ID: {slack_user_id}")
            
            response = self.supabase.table("driver_profiles").select("*").eq("slack_user_id", slack_user_id).execute()
            
            if response.data:
                logger.info(f"✅ Found existing driver profile: {response.data[0]['driver_name']}")
                return response.data[0]
            
            # Get user info from Slack
            logger.info("🆕 Creating new driver profile")
            user_info = client.users_info(user=slack_user_id)
            
            if not user_info.get("ok"):
                logger.error(f"❌ Failed to get user info: {user_info.get('error')}")
                return None
            
            user = user_info.get("user", {})
            profile = user.get("profile", {})
            
            # Create new driver profile
            driver_data = {
                "slack_user_id": slack_user_id,
                "driver_name": profile.get("real_name") or profile.get("display_name") or user.get("name", "Unknown Driver"),
                "email": profile.get("email"),
                "status": "active"
            }
            
            response = self.supabase.table("driver_profiles").insert(driver_data).execute()
            
            if response.data:
                logger.info(f"✅ Created new driver profile: {response.data[0]['driver_name']}")
                return response.data[0]
            else:
                logger.error("❌ Failed to create driver profile")
                return None
                
        except Exception as e:
            logger.error(f"❌ Error getting/creating driver profile: {e}")
            return None

    def get_or_create_van_profile(self, van_number, driver_id):
        """Get existing van profile or create new one"""
        try:
            logger.info(f"🔍 Looking for van #{van_number}")
            
            # First, try to find existing van
            response = self.supabase.table("van_profiles").select("*").eq("van_number", van_number).execute()
            
            if response.data:
                van_profile = response.data[0]
                logger.info(f"✅ Found existing van profile: #{van_profile['van_number']}")
                
                # Update current driver if different
                if van_profile.get('current_driver_id') != driver_id:
                    logger.info(f"🔄 Updating current driver for van #{van_number}")
                    update_response = self.supabase.table("van_profiles").update({
                        "current_driver_id": driver_id,
                        "updated_at": datetime.now().isoformat()
                    }).eq("id", van_profile['id']).execute()
                    
                    if update_response.data:
                        return update_response.data[0]
                
                return van_profile
            
            # Create new van profile
            logger.info(f"🆕 Creating new van #{van_number}")
            van_data = {
                "van_number": van_number,
                "make": "Unknown",
                "model": "Unknown", 
                "status": "active",
                "current_driver_id": driver_id
            }
            
            response = self.supabase.table("van_profiles").insert(van_data).execute()
            
            if response.data:
                logger.info(f"✅ Created new van profile: {response.data[0]['id']}")
                return response.data[0]
            else:
                logger.error("❌ Failed to create van profile")
                return None
                
        except Exception as e:
            logger.error(f"❌ Error getting/creating van profile: {e}")
            return None

    def parse_damage_info_from_context(self, client, channel_id, user_id):
        """Parse damage description and rating from recent messages"""
        try:
            # Get recent messages
            response = client.conversations_history(
                channel=channel_id,
                limit=10
            )
            
            if not response.get("ok"):
                return {"description": "No damage description", "rating": None}
            
            messages = response.get("messages", [])
            damage_info = {"description": "No damage description", "rating": None}
            
            # Look for damage keywords and ratings
            damage_keywords = ["damage", "dent", "scratch", "broken", "cracked", "worn"]
            rating_patterns = [
                r'rating[:\s]*(\d)',
                r'condition[:\s]*(\d)',
                r'(\d)/3',
                r'(\d)\s*out\s*of\s*3'
            ]
            
            for message in messages:
                text = message.get("text", "").lower()
                
                # Look for damage description
                for keyword in damage_keywords:
                    if keyword in text:
                        damage_info["description"] = text.strip()
                        break
                
                # Look for rating
                for pattern in rating_patterns:
                    matches = re.findall(pattern, text, re.IGNORECASE)
                    if matches:
                        rating = int(matches[0])
                        if 0 <= rating <= 3:
                            damage_info["rating"] = rating
                            break
            
            return damage_info
            
        except Exception as e:
            logger.error(f"❌ Error parsing damage info: {e}")
            return {"description": "No damage description", "rating": None}

    def process_and_upload_image_direct(self, file_info, van_profile, driver_profile, damage_info, client, channel_id):
        """Download image from Slack and upload using direct HTTP bypass method"""
        try:
            logger.info(f"📷 Processing image for van #{van_profile['van_number']}")
            
            # Get download URL
            download_url = self.get_file_download_url(file_info)
            if not download_url:
                logger.error("❌ Could not get file download URL")
                return False
            
            logger.info(f"📥 Downloading image from Slack: {download_url[:50]}...")
            
            # Download file
            headers = {"Authorization": f"Bearer {self.slack_bot_token}"}
            response = requests.get(download_url, headers=headers)
            
            if response.status_code != 200:
                logger.error(f"❌ Failed to download file: {response.status_code}")
                return False
            
            image_data = response.content
            logger.info(f"✅ Successfully downloaded image ({len(image_data)} bytes)")
            
            # Determine file extension and content type
            content_type = file_info.get("mimetype", "image/jpeg")
            file_extension = self.get_file_extension(file_info.get("name", ""), content_type)
            
            logger.info(f"📤 Detected content type: {content_type}")
            
            # Create file path
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            file_path = f"van_{van_profile['van_number']}/image_{timestamp}.{file_extension}"
            
            logger.info(f"📤 Uploading to path: {file_path}")
            
            # Method 1: Try direct HTTP upload with custom headers
            upload_success = self.direct_http_upload(file_path, image_data, content_type)
            
            if not upload_success:
                # Method 2: Try base64 upload method
                logger.info("🔄 Trying base64 upload method...")
                upload_success = self.base64_upload(file_path, image_data, content_type)
            
            if not upload_success:
                # Method 3: Try simple PUT request
                logger.info("🔄 Trying simple PUT request...")
                upload_success = self.simple_put_upload(file_path, image_data, content_type)
            
            if upload_success:
                # Get public URL
                public_url = self.supabase.storage.from_("van-images").get_public_url(file_path)
                logger.info(f"✅ Image uploaded successfully: {public_url}")
                
                # Save image record to database
                image_record = {
                    "van_id": van_profile["id"],
                    "driver_id": driver_profile["id"],
                    "image_url": public_url,
                    "file_path": file_path,
                    "van_damage": damage_info.get("description", "No damage description"),
                    "van_rating": damage_info.get("rating")
                }
                
                db_response = self.supabase.table("van_images").insert(image_record).execute()
                
                if db_response.data:
                    logger.info("✅ Image record saved to database")
                    return True
                else:
                    logger.error("❌ Failed to save image record to database")
                    return False
            else:
                logger.error("❌ All upload methods failed")
                return False
                
        except Exception as e:
            logger.error(f"❌ Error processing and uploading image: {e}")
            return False

    def direct_http_upload(self, file_path, image_data, content_type):
        """Direct HTTP upload with custom headers to bypass constraints"""
        try:
            logger.info("🔄 Attempting direct HTTP upload...")
            
            storage_url = f"{self.supabase_url}/storage/v1/object/van-images/{file_path}"
            
            headers = {
                "Authorization": f"Bearer {self.supabase_key}",
                "Content-Type": content_type,
                "x-upsert": "true",
                "x-bypass-rls": "true",
                "apikey": self.supabase_key
            }
            
            logger.info(f"📤 Direct upload URL: {storage_url}")
            logger.info(f"📋 Headers: {list(headers.keys())}")
            
            response = requests.post(storage_url, data=image_data, headers=headers)
            
            logger.info(f"📊 Direct upload response: {response.status_code}")
            
            if response.status_code in [200, 201]:
                logger.info("✅ Direct HTTP upload successful")
                return True
            else:
                logger.error(f"❌ Direct upload failed: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"❌ Direct HTTP upload error: {e}")
            return False

    def base64_upload(self, file_path, image_data, content_type):
        """Base64 encoded upload method"""
        try:
            logger.info("🔄 Attempting base64 upload...")
            
            # Encode image as base64
            base64_data = base64.b64encode(image_data).decode('utf-8')
            
            storage_url = f"{self.supabase_url}/storage/v1/object/van-images/{file_path}"
            
            headers = {
                "Authorization": f"Bearer {self.supabase_key}",
                "Content-Type": "application/json",
                "apikey": self.supabase_key
            }
            
            payload = {
                "data": base64_data,
                "contentType": content_type
            }
            
            response = requests.post(storage_url, json=payload, headers=headers)
            
            logger.info(f"📊 Base64 upload response: {response.status_code}")
            
            if response.status_code in [200, 201]:
                logger.info("✅ Base64 upload successful")
                return True
            else:
                logger.error(f"❌ Base64 upload failed: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"❌ Base64 upload error: {e}")
            return False

    def simple_put_upload(self, file_path, image_data, content_type):
        """Simple PUT request upload"""
        try:
            logger.info("🔄 Attempting simple PUT upload...")
            
            storage_url = f"{self.supabase_url}/storage/v1/object/van-images/{file_path}"
            
            headers = {
                "Authorization": f"Bearer {self.supabase_key}",
                "Content-Type": content_type
            }
            
            response = requests.put(storage_url, data=image_data, headers=headers)
            
            logger.info(f"📊 PUT upload response: {response.status_code}")
            
            if response.status_code in [200, 201]:
                logger.info("✅ PUT upload successful")
                return True
            else:
                logger.error(f"❌ PUT upload failed: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"❌ PUT upload error: {e}")
            return False

    def get_file_download_url(self, file_info):
        """Get the appropriate download URL for the file"""
        # Try different URL fields in order of preference
        url_fields = [
            "url_private_download",
            "url_private", 
            "url_download",
            "permalink_public"
        ]
        
        for field in url_fields:
            if field in file_info and file_info[field]:
                logger.info(f"✅ Found file URL in field \"{field}\": {file_info[field][:50]}...")
                return file_info[field]
        
        logger.error("❌ No suitable download URL found in file info")
        return None

    def get_file_extension(self, filename, content_type):
        """Get file extension from filename or content type"""
        if filename and "." in filename:
            return filename.split(".")[-1].lower()
        
        # Fallback to content type
        content_type_map = {
            "image/jpeg": "jpg",
            "image/jpg": "jpg", 
            "image/png": "png",
            "image/gif": "gif",
            "image/webp": "webp"
        }
        
        return content_type_map.get(content_type, "jpg")

    def start(self):
        """Start the Slack bot"""
        logger.info("🚀 Starting Slack bot with Socket Mode...")
        handler = SocketModeHandler(self.app, self.slack_app_token)
        handler.start()

def main():
    """Main function"""
    try:
        bot = StorageBypassSlackBot()
        bot.start()
    except KeyboardInterrupt:
        logger.info("👋 Bot stopped by user")
    except Exception as e:
        logger.error(f"❌ Bot crashed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
🤖 ENHANCED CLAUDE AI Slack Bot - Analyze van images with Claude AI
Handles van fleet management with AI-powered image analysis
"""

import os
import re
import sys
import json
import logging
import requests
import base64
from datetime import datetime
from typing import Optional, Dict, Any, Tuple
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from supabase import create_client, Client
import anthropic

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ClaudeEnhancedSlackBot:
    def __init__(self):
        logger.info("🚀 Starting CLAUDE AI ENHANCED Slack Bot...")
        logger.info("🧠 Focus: AI-powered image analysis with damage detection")
        
        # Load environment variables
        self.slack_bot_token = os.getenv("SLACK_BOT_TOKEN")
        self.slack_app_token = os.getenv("SLACK_APP_TOKEN")
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_KEY")
        self.claude_api_key = os.getenv("CLAUDE_API_KEY")
        
        # Validate environment variables
        required_vars = [
            "SLACK_BOT_TOKEN", "SLACK_APP_TOKEN", 
            "SUPABASE_URL", "SUPABASE_KEY", "CLAUDE_API_KEY"
        ]
        
        missing_vars = [var for var in required_vars if not os.getenv(var)]
        if missing_vars:
            logger.error(f"❌ Missing environment variables: {missing_vars}")
            sys.exit(1)
        
        logger.info("✅ All environment variables found")
        
        # Initialize clients
        self.supabase: Client = create_client(self.supabase_url, self.supabase_key)
        self.claude_client = anthropic.Anthropic(api_key=self.claude_api_key)
        
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
        """Handle file_shared events"""
        try:
            logger.info("📁 Received file_shared event")
            self.process_file_event(event, say, client, "file_shared")
        except Exception as e:
            logger.error(f"❌ Error in handle_file_shared: {e}")

    def handle_file_created(self, event, say, client):
        """Handle file_created events"""
        try:
            logger.info("📁 Received file_created event")
            self.process_file_event(event, say, client, "file_created")
        except Exception as e:
            logger.error(f"❌ Error in handle_file_created: {e}")

    def handle_message_with_file(self, event, say, client):
        """Handle message events that might contain files"""
        try:
            if event.get("subtype") == "file_share" and "files" in event:
                logger.info("📁 Received message with file_share subtype")
                for file_info in event["files"]:
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
        """Process file events with Claude AI analysis"""
        try:
            file_id = event.get("file_id")
            channel_id = event.get("channel_id")
            user_id = event.get("user_id")
            
            logger.info(f"📁 Processing file from {event_type} event")
            logger.info(f"📁 File ID: {file_id}")
            
            # Get file info
            file_info = event.get("file")
            if not file_info or not file_info.get("name"):
                file_info = self.get_file_info(client, file_id)
                if not file_info:
                    logger.error("❌ Could not retrieve file information")
                    return
            
            # Check if it's an image
            if not self.is_image_file(file_info):
                logger.info("📄 File is not an image, skipping")
                return
            
            logger.info(f"📷 Processing image: {file_info.get('name')}")
            
            # Find van number in context
            van_number = self.find_van_number_in_context(client, channel_id, user_id)
            if not van_number:
                say("❌ Please mention a van number (e.g., 'van 123' or '#123') when uploading images")
                return
            
            # Get or create profiles
            driver_profile = self.get_or_create_driver_profile(user_id, client)
            van_profile = self.get_or_create_van_profile(van_number, driver_profile['id'])
            
            if not driver_profile or not van_profile:
                say("❌ Failed to create driver or van profile")
                return
            
            # Download and analyze image with Claude AI
            success, analysis_results = self.download_and_analyze_image(
                file_info, van_profile, driver_profile, client, channel_id
            )
            
            if success and analysis_results:
                # Send detailed success message
                self.send_analysis_results(say, van_number, driver_profile, analysis_results)
            else:
                say(f"❌ Failed to analyze image for van {van_number}")
                
        except Exception as e:
            logger.error(f"❌ Error processing file event: {e}")
            say("❌ Error processing image upload")

    def analyze_image_with_claude(self, base64_image: str, content_type: str) -> Optional[Dict]:
        """Analyze image using Claude AI for damage assessment and van side detection"""
        try:
            prompt = """
            You are an expert vehicle damage assessor. Analyze this van image and provide a JSON response with the following information:

            1. **van_side**: Which side/view of the van is shown (choose one):
               - "front" (front bumper, headlights, grille)
               - "rear" (back doors, tail lights, rear bumper)
               - "driver_side" (left side when facing forward)
               - "passenger_side" (right side when facing forward)
               - "interior" (inside the van)
               - "roof" (top view)
               - "undercarriage" (bottom view)
               - "unknown" (if unclear)

            2. **damage_description**: Detailed description of any visible damage (or "No visible damage" if none)

            3. **damage_type**: Primary type of damage (choose one):
               - "scratch" (surface scratches)
               - "dent" (dents or impacts)
               - "paint_damage" (paint chips, fading, rust)
               - "broken_part" (broken lights, mirrors, etc.)
               - "wear" (normal wear and tear)
               - "none" (no damage visible)

            4. **damage_severity**: Severity level (choose one):
               - "none" (no damage)
               - "minor" (cosmetic only)
               - "moderate" (noticeable but functional)
               - "major" (affects function or safety)

            5. **damage_rating**: Numerical rating 0-3:
               - 0 = No damage/excellent condition
               - 1 = Minor cosmetic damage
               - 2 = Moderate damage requiring attention
               - 3 = Major damage requiring immediate repair

            6. **damage_location**: Specific location of damage on the van side (e.g., "front bumper", "door panel", "wheel well")

            7. **confidence**: Your confidence in this assessment ("high", "medium", "low")

            Respond ONLY with valid JSON in this exact format:
            {
                "van_side": "front",
                "damage_description": "Minor scratch on front bumper",
                "damage_type": "scratch",
                "damage_severity": "minor",
                "damage_rating": 1,
                "damage_location": "front bumper",
                "confidence": "high"
            }
            """

            message = self.claude_client.messages.create(
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
                                    "media_type": content_type,
                                    "data": base64_image
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
            
            # Parse Claude's response
            response_text = message.content[0].text.strip()
            logger.info(f"🧠 Claude AI response: {response_text}")
            
            # Extract JSON from response
            try:
                json_start = response_text.find('{')
                json_end = response_text.rfind('}') + 1
                if json_start >= 0 and json_end > json_start:
                    json_str = response_text[json_start:json_end]
                    analysis = json.loads(json_str)
                    
                    # Validate required fields
                    required_fields = ['van_side', 'damage_description', 'damage_type', 'damage_severity', 'damage_rating', 'damage_location', 'confidence']
                    if all(field in analysis for field in required_fields):
                        logger.info("✅ Claude AI analysis successful")
                        return analysis
                    else:
                        logger.error(f"❌ Missing required fields in Claude response: {analysis}")
                        return None
                else:
                    logger.error("❌ No valid JSON found in Claude response")
                    return None
                    
            except json.JSONDecodeError as e:
                logger.error(f"❌ Failed to parse Claude response as JSON: {e}")
                return None
                
        except Exception as e:
            logger.error(f"❌ Error calling Claude AI: {e}")
            return None

    def download_and_analyze_image(self, file_info, van_profile, driver_profile, client, channel_id) -> Tuple[bool, Optional[Dict]]:
        """Download image and analyze with Claude AI"""
        try:
            # Download image
            download_url = self.get_file_download_url(file_info)
            if not download_url:
                logger.error("❌ Could not get file download URL")
                return False, None
            
            logger.info(f"📥 Downloading image from Slack...")
            headers = {"Authorization": f"Bearer {self.slack_bot_token}"}
            response = requests.get(download_url, headers=headers)
            
            if response.status_code != 200:
                logger.error(f"❌ Failed to download file: {response.status_code}")
                return False, None
            
            image_data = response.content
            logger.info(f"✅ Downloaded image ({len(image_data)} bytes)")
            
            # Convert to base64 for Claude AI
            base64_image = base64.b64encode(image_data).decode('utf-8')
            
            # Analyze with Claude AI
            logger.info("🧠 Analyzing image with Claude AI...")
            analysis_results = self.analyze_image_with_claude(base64_image, file_info.get("mimetype", "image/jpeg"))
            
            if not analysis_results:
                logger.error("❌ Claude AI analysis failed")
                return False, None
            
            # Store in database with AI analysis results
            success = self.store_analyzed_image_in_db(
                file_info, van_profile, driver_profile, analysis_results, 
                base64_image, image_data, channel_id
            )
            
            return success, analysis_results
            
        except Exception as e:
            logger.error(f"❌ Error downloading and analyzing image: {e}")
            return False, None

    def store_analyzed_image_in_db(self, file_info, van_profile, driver_profile, analysis_results, base64_image, image_data, channel_id):
        """Store image with Claude AI analysis results in database"""
        try:
            content_type = file_info.get("mimetype", "image/jpeg")
            file_extension = self.get_file_extension(file_info.get("name", ""), content_type)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            file_path = f"van_{van_profile['van_number']}/image_{timestamp}.{file_extension}"
            
            logger.info(f"💾 Storing analyzed image in database...")
            
            # Create comprehensive image record with AI analysis
            image_record = {
                "van_id": van_profile["id"],
                "van_number": van_profile["van_number"],
                "driver_id": driver_profile["id"],
                "slack_user_id": driver_profile.get("slack_user_id"),
                "slack_channel_id": channel_id,
                
                # Image data
                "image_url": f"data:{content_type};base64,{base64_image}",
                "image_data": base64_image,
                "file_path": file_path,
                "file_size": len(image_data),
                "content_type": content_type,
                
                # Claude AI Analysis Results
                "van_side": analysis_results["van_side"],
                "van_damage": analysis_results["damage_description"],
                "damage_type": analysis_results["damage_type"],
                "damage_severity": analysis_results["damage_severity"],
                "van_rating": analysis_results["damage_rating"],
                "damage_level": analysis_results["damage_rating"],
                "damage_location": analysis_results["damage_location"],
                "location": analysis_results["damage_location"],
                "description": analysis_results["damage_description"],
                
                # Metadata
                "upload_method": "claude_ai_slack_bot",
                "uploaded_by": driver_profile.get("driver_name", "unknown"),
                "driver_name": driver_profile.get("driver_name"),
                "upload_source": f"claude_analysis_confidence_{analysis_results['confidence']}"
            }
            
            # Insert into database
            db_response = self.supabase.table("van_images").insert(image_record).execute()
            
            if db_response.data:
                logger.info("✅ Image with AI analysis stored successfully")
                logger.info(f"📊 Database record ID: {db_response.data[0]['id']}")
                return True
            else:
                logger.error("❌ Failed to save analyzed image to database")
                return False
                
        except Exception as e:
            logger.error(f"❌ Error storing analyzed image: {e}")
            return False

    def send_analysis_results(self, say, van_number, driver_profile, analysis_results):
        """Send detailed AI analysis results to Slack"""
        try:
            # Create status emojis
            damage_emoji = {
                "none": "✅",
                "minor": "⚠️",
                "moderate": "🔶",
                "major": "🚨"
            }
            
            side_emoji = {
                "front": "🚐",
                "rear": "🚛",
                "driver_side": "👈",
                "passenger_side": "👉",
                "interior": "🪑",
                "roof": "⬆️",
                "undercarriage": "⬇️",
                "unknown": "❓"
            }
            
            severity = analysis_results["damage_severity"]
            van_side = analysis_results["van_side"]
            
            success_msg = (
                f"🤖 **AI Analysis Complete!**\n\n"
                f"🚐 **Van:** #{van_number}\n"
                f"👤 **Driver:** {driver_profile.get('driver_name', 'Unknown')}\n"
                f"{side_emoji.get(van_side, '📷')} **Van Side:** {van_side.replace('_', ' ').title()}\n\n"
                f"{damage_emoji.get(severity, '🔍')} **Damage Assessment:**\n"
                f"• **Type:** {analysis_results['damage_type'].replace('_', ' ').title()}\n"
                f"• **Severity:** {severity.title()}\n"
                f"• **Rating:** {analysis_results['damage_rating']}/3\n"
                f"• **Location:** {analysis_results['damage_location']}\n"
                f"• **Description:** {analysis_results['damage_description']}\n\n"
                f"🎯 **AI Confidence:** {analysis_results['confidence'].title()}\n"
                f"💾 **Storage:** Database (Base64 + AI Analysis)"
            )
            
            say(success_msg)
            
        except Exception as e:
            logger.error(f"❌ Error sending analysis results: {e}")
            say(f"✅ Image analyzed and stored for van {van_number}")

    def get_file_info(self, client, file_id):
        """Get complete file information from Slack"""
        try:
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
            response = client.conversations_history(channel=channel_id, limit=20)
            if not response.get("ok"):
                return None
            
            messages = response.get("messages", [])
            van_patterns = [r'van\s*#?(\d+)', r'#(\d+)', r'\b(\d{3})\b']
            
            for message in messages:
                text = message.get("text", "").lower()
                for pattern in van_patterns:
                    matches = re.findall(pattern, text, re.IGNORECASE)
                    if matches:
                        return matches[0]
            return None
        except Exception as e:
            logger.error(f"❌ Error finding van number: {e}")
            return None

    def get_or_create_driver_profile(self, slack_user_id, client):
        """Get existing driver profile or create new one"""
        try:
            response = self.supabase.table("driver_profiles").select("*").eq("slack_user_id", slack_user_id).execute()
            
            if response.data:
                return response.data[0]
            
            # Create new driver profile
            user_info = client.users_info(user=slack_user_id)
            if not user_info.get("ok"):
                return None
            
            user = user_info.get("user", {})
            profile = user.get("profile", {})
            
            driver_data = {
                "slack_user_id": slack_user_id,
                "driver_name": profile.get("real_name") or profile.get("display_name") or user.get("name", "Unknown Driver"),
                "email": profile.get("email"),
                "status": "active"
            }
            
            response = self.supabase.table("driver_profiles").insert(driver_data).execute()
            return response.data[0] if response.data else None
        except Exception as e:
            logger.error(f"❌ Error getting/creating driver profile: {e}")
            return None

    def get_or_create_van_profile(self, van_number, driver_id):
        """Get existing van profile or create new one"""
        try:
            response = self.supabase.table("van_profiles").select("*").eq("van_number", van_number).execute()
            
            if response.data:
                van_profile = response.data[0]
                # Update current driver if different
                if van_profile.get('current_driver_id') != driver_id:
                    update_response = self.supabase.table("van_profiles").update({
                        "current_driver_id": driver_id,
                        "updated_at": datetime.now().isoformat()
                    }).eq("id", van_profile['id']).execute()
                    return update_response.data[0] if update_response.data else van_profile
                return van_profile
            
            # Create new van profile
            van_data = {
                "van_number": van_number,
                "make": "Unknown",
                "model": "Unknown", 
                "status": "active",
                "current_driver_id": driver_id
            }
            
            response = self.supabase.table("van_profiles").insert(van_data).execute()
            return response.data[0] if response.data else None
        except Exception as e:
            logger.error(f"❌ Error getting/creating van profile: {e}")
            return None

    def get_file_download_url(self, file_info):
        """Get the appropriate download URL for the file"""
        url_fields = ["url_private_download", "url_private", "url_download", "permalink_public"]
        
        for field in url_fields:
            if field in file_info and file_info[field]:
                return file_info[field]
        
        return None

    def get_file_extension(self, filename, content_type):
        """Get file extension from filename or content type"""
        if filename and "." in filename:
            return filename.split(".")[-1].lower()
        
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
        logger.info("🚀 Starting Claude AI Enhanced Slack bot...")
        handler = SocketModeHandler(self.app, self.slack_app_token)
        handler.start()

def main():
    """Main function"""
    try:
        bot = ClaudeEnhancedSlackBot()
        bot.start()
    except KeyboardInterrupt:
        logger.info("👋 Bot stopped by user")
    except Exception as e:
        logger.error(f"❌ Bot crashed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 
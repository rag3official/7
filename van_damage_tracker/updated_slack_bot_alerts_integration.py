# INTEGRATION CODE FOR EC2 slack_supabase_bot.py
# Add this function to your existing slack_supabase_bot.py file

def update_van_alerts(van_id, damage_level, van_number):
    """
    Update van alerts based on damage level from Claude AI analysis
    Called after Claude AI gives damage rating
    """
    try:
        # Set alert flag for damage level 2 or 3
        alert_flag = 'yes' if damage_level >= 2 else 'no'
        
        print(f"🚨 Updating alerts for van #{van_number} (ID: {van_id}), damage level: {damage_level}")
        
        # Update van_profiles table with alert flag
        response = supabase.table('van_profiles').update({
            'alerts': alert_flag,
            'updated_at': 'now()'
        }).eq('id', van_id).execute()
        
        if response.data:
            if alert_flag == 'yes':
                print(f"🚨 CRITICAL DAMAGE ALERT SET: Van #{van_number} flagged for damage level {damage_level}")
                logger.info(f"🚨 CRITICAL DAMAGE ALERT SET: Van #{van_number} flagged for damage level {damage_level}")
            else:
                print(f"✅ Alert cleared for van #{van_number} (damage level {damage_level})")
                logger.info(f"✅ Alert cleared for van #{van_number} (damage level {damage_level})")
                
            return True
        else:
            print(f"❌ Failed to update alerts for van #{van_number}")
            logger.error(f"❌ Failed to update alerts for van #{van_number}")
            return False
            
    except Exception as e:
        print(f"❌ Error updating van alerts: {e}")
        logger.error(f"❌ Error updating van alerts: {e}")
        return False

# MODIFICATION TO YOUR EXISTING CODE:
# Find the section where you update van profile after Claude analysis
# It should be around the line that says "Updating van #XXX profile with damage rating..."
# 
# ADD THIS CODE after Claude analysis and BEFORE updating driver statistics:

# After this line in your existing code:
# logger.info(f"✅ Successfully updated van #{van_number} profile with damage rating")

# ADD THIS CODE:
"""
# Update van alerts based on damage level
if 'van_rating' in claude_result:
    damage_level = claude_result['van_rating']
    update_success = update_van_alerts(van_id, damage_level, van_number)
    
    if update_success and damage_level >= 2:
        # Optional: Send additional Slack notification for critical damage
        try:
            app.client.chat_postMessage(
                channel=channel_id,
                text=f"🚨 *CRITICAL DAMAGE ALERT* 🚨\\n"
                     f"Van #{van_number} has been flagged with damage level {damage_level}\\n"
                     f"⚠️ This van requires immediate attention!",
                thread_ts=message_ts
            )
            logger.info(f"🚨 Sent critical damage alert notification for van #{van_number}")
        except Exception as e:
            logger.error(f"❌ Failed to send critical damage alert: {e}")
"""

# COMPLETE INTEGRATION EXAMPLE:
# Replace your van profile creation section with this updated version:

def create_or_update_van_profile(van_number):
    """
    Enhanced van profile creation with alerts support
    """
    try:
        # Check if van exists
        van_query = supabase.table('van_profiles').select('*').eq('van_number', van_number)
        existing_van = van_query.execute()
        
        if existing_van.data:
            # Van exists
            van_id = existing_van.data[0]['id']
            logger.info(f"✅ Found existing van: {van_id}")
        else:
            # Create new van with alerts field
            new_van_data = {
                'van_number': van_number,
                'make': 'Rental Van',
                'model': 'Fleet Vehicle', 
                'status': 'active',
                'alerts': 'no',  # Default to no alerts
                'created_at': 'now()',
                'updated_at': 'now()'
            }
            
            create_response = supabase.table('van_profiles').insert(new_van_data).execute()
            if create_response.data:
                van_id = create_response.data[0]['id']
                logger.info(f"✅ Created new van: {van_id}")
            else:
                raise Exception("Failed to create van profile")
                
        return van_id
        
    except Exception as e:
        logger.error(f"❌ Error creating/updating van profile: {e}")
        return None 
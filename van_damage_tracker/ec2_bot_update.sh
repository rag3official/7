#!/bin/bash
# EC2 Slack Bot Update Script - Run this on your EC2 instance
# SSH into EC2: ssh -i ~/Downloads/supabase.pem ubuntu@3.15.163.231

echo "🚀 Starting Slack Bot Update for Van Alerts System"

# Step 1: First add the alerts column to database (run in Supabase Dashboard)
echo "📋 IMPORTANT: First run this in Supabase Dashboard -> SQL Editor:"
echo "ALTER TABLE van_profiles ADD COLUMN IF NOT EXISTS alerts TEXT DEFAULT 'no' CHECK (alerts IN ('yes', 'no'));"
echo ""
read -p "Press Enter after running the SQL migration..."

# Step 2: Navigate to bot directory and backup
echo "📁 Creating backup..."
cd /home/ubuntu
sudo cp slack_supabase_bot.py slack_supabase_bot.py.backup.$(date +%Y%m%d_%H%M%S)

# Step 3: Create the alerts function
echo "📝 Adding alerts function..."
cat << 'EOF' > /tmp/update_van_alerts_function.py

def update_van_alerts(van_id, damage_level, van_number):
    """Update van alerts based on damage level from Claude AI analysis"""
    try:
        alert_flag = 'yes' if damage_level >= 2 else 'no'
        
        print(f"🚨 Updating alerts for van #{van_number}, damage level: {damage_level}")
        logger.info(f"🚨 Updating alerts for van #{van_number}, damage level: {damage_level}")
        
        response = supabase.table('van_profiles').update({
            'alerts': alert_flag,
            'updated_at': 'now()'
        }).eq('id', van_id).execute()
        
        if response.data:
            if alert_flag == 'yes':
                print(f"🚨 CRITICAL DAMAGE ALERT: Van #{van_number} flagged for level {damage_level}")
                logger.info(f"🚨 CRITICAL DAMAGE ALERT: Van #{van_number} flagged for level {damage_level}")
            else:
                print(f"✅ Alert cleared for van #{van_number}")
                logger.info(f"✅ Alert cleared for van #{van_number}")
            return True
        else:
            print(f"❌ Failed to update alerts for van #{van_number}")
            logger.error(f"❌ Failed to update alerts for van #{van_number}")
            return False
        
    except Exception as e:
        print(f"❌ Error updating van alerts: {e}")
        logger.error(f"❌ Error updating van alerts: {e}")
        return False

EOF

# Step 4: Add the alerts integration code
cat << 'EOF' > /tmp/alerts_integration.py

        # Update van alerts based on damage level
        if 'van_rating' in claude_result:
            damage_level = claude_result['van_rating']
            print(f"🎯 Damage level detected: {damage_level}")
            
            # Update alerts in database  
            alert_updated = update_van_alerts(van_id, damage_level, van_number)
            
            if alert_updated and damage_level >= 2:
                print(f"🚨 HIGH DAMAGE ALERT: Van {van_number} requires immediate attention!")
                logger.info(f"🚨 HIGH DAMAGE ALERT: Van {van_number} requires immediate attention!")

EOF

# Step 5: Find insertion points and add the code
echo "📝 Updating bot file..."

# Add function after environment validation (around line 50)
LINE_NUM=$(grep -n "Environment validation complete" slack_supabase_bot.py | cut -d: -f1)
if [ -n "$LINE_NUM" ]; then
    sudo sed -i "${LINE_NUM}r /tmp/update_van_alerts_function.py" slack_supabase_bot.py
    echo "✅ Added alerts function"
else
    echo "⚠️  Could not find environment validation line. Adding function at line 50..."
    sudo sed -i "50r /tmp/update_van_alerts_function.py" slack_supabase_bot.py
fi

# Add integration after Claude analysis result
CLAUDE_LINE=$(grep -n "Claude analysis result:" slack_supabase_bot.py | cut -d: -f1)
if [ -n "$CLAUDE_LINE" ]; then
    sudo sed -i "${CLAUDE_LINE}r /tmp/alerts_integration.py" slack_supabase_bot.py
    echo "✅ Added alerts integration"
else
    echo "⚠️  Could not find Claude analysis line. Manual integration needed."
fi

# Step 6: Update van creation to include alerts field
echo "📝 Updating van creation..."
sudo sed -i "s/'status': 'active'/'status': 'active',\\n        'alerts': 'no'/" slack_supabase_bot.py

# Step 7: Clean up temp files
rm /tmp/update_van_alerts_function.py /tmp/alerts_integration.py

# Step 8: Restart the bot service
echo "🔄 Restarting bot service..."
sudo systemctl restart python3

# Step 9: Check if bot is running
echo "✅ Checking bot status..."
ps aux | grep python3 | grep slack

echo ""
echo "🎉 Bot update complete!"
echo "📱 Test by uploading an image with damage level 2 or 3 to Slack"
echo "📋 Monitor logs with: sudo journalctl -f | grep python3" 
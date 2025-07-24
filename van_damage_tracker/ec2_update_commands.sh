#!/bin/bash
# EC2 Slack Bot Update Commands
# Run these commands on your EC2 instance

echo "🚀 Starting EC2 Slack Bot Update for Van Alerts System"

# Step 1: First run the database migration in Supabase Dashboard
echo "📋 Step 1: Run this SQL in Supabase Dashboard -> SQL Editor:"
echo "ALTER TABLE van_profiles ADD COLUMN IF NOT EXISTS alerts TEXT DEFAULT 'no' CHECK (alerts IN ('yes', 'no'));"
echo ""
echo "⏸️  Press Enter after running the SQL migration..."
read -p ""

# Step 2: Backup the current bot file
echo "📁 Step 2: Creating backup of current bot..."
sudo cp slack_supabase_bot.py slack_supabase_bot.py.backup.$(date +%Y%m%d_%H%M%S)

# Step 3: Add the alerts function to the bot
echo "📝 Step 3: Adding alerts function to the bot..."

# Create a temporary file with the new function
cat << 'EOF' > /tmp/alerts_function.py

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

# Step 4: Add the function to the bot file after imports
echo "📝 Step 4: Adding function to bot file..."
# Find the line number after imports (typically after logging setup)
LINE_NUM=$(grep -n "logger.info.*Supabase.*connection successful" slack_supabase_bot.py | cut -d: -f1)
if [ -z "$LINE_NUM" ]; then
    LINE_NUM=50  # Fallback line number
fi

# Insert the function after the imports section
sudo sed -i "${LINE_NUM}r /tmp/alerts_function.py" slack_supabase_bot.py

# Step 5: Add the alerts call after Claude analysis
echo "📝 Step 5: Adding alerts call after Claude analysis..."

# Create the alerts integration code
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

# Find the line with Claude analysis result and add after it
CLAUDE_LINE=$(grep -n "logger.info.*Claude analysis result" slack_supabase_bot.py | cut -d: -f1)
if [ -n "$CLAUDE_LINE" ]; then
    sudo sed -i "${CLAUDE_LINE}r /tmp/alerts_integration.py" slack_supabase_bot.py
    echo "✅ Added alerts integration after Claude analysis"
else
    echo "⚠️  Could not find Claude analysis line. Manual integration needed."
fi

# Step 6: Update van creation to include alerts field
echo "📝 Step 6: Updating van creation code..."
sudo sed -i "s/'status': 'active',/'status': 'active',\\n        'alerts': 'no',/" slack_supabase_bot.py

# Step 7: Clean up temporary files
rm /tmp/alerts_function.py /tmp/alerts_integration.py

# Step 8: Restart the bot service
echo "🔄 Step 8: Restarting bot service..."
sudo systemctl restart slack-bot.service

# Step 9: Check service status
echo "✅ Step 9: Checking service status..."
sudo systemctl status slack-bot.service --no-pager -l

echo ""
echo "🎉 Bot update complete! Check the logs for any errors:"
echo "sudo journalctl -u slack-bot.service -f"
echo ""
echo "📱 Test by uploading an image with damage to Slack!" 
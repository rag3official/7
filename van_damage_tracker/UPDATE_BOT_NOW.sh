#!/bin/bash
# COMPLETE BOT UPDATE SCRIPT
# Copy and paste these commands one by one

echo "🚀 UPDATING SLACK BOT WITH ALERTS FUNCTIONALITY"

# Step 1: First add alerts column in Supabase Dashboard SQL Editor
echo "📋 STEP 1: Run this in Supabase Dashboard -> SQL Editor:"
echo "ALTER TABLE van_profiles ADD COLUMN IF NOT EXISTS alerts TEXT DEFAULT 'no' CHECK (alerts IN ('yes', 'no'));"
echo ""
read -p "Press Enter after running the SQL migration..."

# Step 2: SSH into EC2
echo "🔗 STEP 2: Connecting to EC2..."
ssh -i ~/Downloads/supabase.pem ubuntu@3.15.163.231 << 'EOF'

# Step 3: Stop the bot service
echo "⏹️  Stopping bot service..."
sudo systemctl stop slack-supabase-bot

# Step 4: Backup the bot file
echo "💾 Creating backup..."
sudo cp slack_supabase_bot.py slack_supabase_bot.py.backup.$(date +%Y%m%d_%H%M%S)

# Step 5: Add the alerts function (after imports, around line 50)
echo "📝 Adding alerts function..."
sudo sed -i '50a\
def update_van_alerts(van_id, damage_level, van_number):\
    """Update van alerts based on damage level from Claude AI analysis"""\
    try:\
        alert_flag = "yes" if damage_level >= 2 else "no"\
        print(f"🚨 Updating alerts for van #{van_number}, damage level: {damage_level}")\
        logger.info(f"🚨 Updating alerts for van #{van_number}, damage level: {damage_level}")\
        response = supabase.table("van_profiles").update({\
            "alerts": alert_flag,\
            "updated_at": "now()"\
        }).eq("id", van_id).execute()\
        if response.data:\
            if alert_flag == "yes":\
                print(f"🚨 CRITICAL DAMAGE ALERT: Van #{van_number} flagged for level {damage_level}")\
                logger.info(f"🚨 CRITICAL DAMAGE ALERT: Van #{van_number} flagged for level {damage_level}")\
            return True\
        return False\
    except Exception as e:\
        print(f"❌ Error updating van alerts: {e}")\
        logger.error(f"❌ Error updating van alerts: {e}")\
        return False\
' slack_supabase_bot.py

# Step 6: Find the Claude analysis result line and add alerts integration
echo "📝 Adding alerts integration..."
sudo sed -i '/logger.info(f"🎯 Claude analysis result: {claude_result}")/a\
        # Update van alerts based on damage level\
        if "van_rating" in claude_result:\
            damage_level = claude_result["van_rating"]\
            print(f"🎯 Damage level detected: {damage_level}")\
            alert_updated = update_van_alerts(van_id, damage_level, van_number)\
            if alert_updated and damage_level >= 2:\
                print(f"🚨 HIGH DAMAGE ALERT: Van {van_number} requires immediate attention!")\
                logger.info(f"🚨 HIGH DAMAGE ALERT: Van {van_number} requires immediate attention!")\
' slack_supabase_bot.py

# Step 7: Start the bot service
echo "▶️  Starting bot service..."
sudo systemctl start slack-supabase-bot

# Step 8: Check if bot is running
echo "✅ Checking bot status..."
sudo systemctl status slack-supabase-bot --no-pager

echo ""
echo "🎉 BOT UPDATE COMPLETE!"
echo "📱 Test by uploading an image with damage level 2 or 3 to Slack"
echo "📋 Monitor logs with: sudo journalctl -f -u slack-supabase-bot"

EOF

echo "✅ Bot update completed successfully!" 
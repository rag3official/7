#!/bin/bash

# Deploy Complete Van Fleet Management Solution
# This script deploys the database schema and profile-aware bot

set -e

SERVER="ubuntu@3.15.163.231"
KEY_FILE="~/Downloads/supabase.pem"
REMOTE_DIR="/home/ubuntu/slack_bot"

echo "🚀 Deploying Complete Van Fleet Management Solution..."

# Upload files
echo "📤 Uploading database schema..."
scp -i "$KEY_FILE" complete_database_schema.sql "$SERVER:$REMOTE_DIR/"

echo "📤 Uploading profile-aware bot..."
scp -i "$KEY_FILE" profile_aware_bot.py "$SERVER:$REMOTE_DIR/"

echo "📤 Uploading simple metadata function..."
scp -i "$KEY_FILE" simple_metadata_function.sql "$SERVER:$REMOTE_DIR/"

# Connect to server and deploy
echo "🔗 Connecting to server to deploy..."
ssh -i "$KEY_FILE" "$SERVER" << 'EOF'
cd /home/ubuntu/slack_bot

echo "📋 Current directory contents:"
ls -la

echo "🔄 Stopping current bot service..."
sudo systemctl stop slack_bot.service

echo "🔄 Backing up current bot..."
if [ -f "database_bypass_bot.py" ]; then
    cp database_bypass_bot.py database_bypass_bot.py.backup
fi

echo "🔄 Installing new profile-aware bot..."
cp profile_aware_bot.py database_bypass_bot.py

echo "✅ Updated bot file"

echo "🔄 Starting bot service..."
sudo systemctl start slack_bot.service

echo "📊 Checking service status..."
sudo systemctl status slack_bot.service --no-pager -l

echo "📋 Recent logs:"
sudo journalctl -u slack_bot.service --no-pager -l -n 20

echo "✅ Deployment complete!"
echo ""
echo "🎯 NEXT STEPS:"
echo "1. Execute complete_database_schema.sql in Supabase SQL Editor"
echo "2. Execute simple_metadata_function.sql in Supabase SQL Editor"
echo "3. Test with: 'van 123' + image upload"
echo ""
echo "📊 The bot now supports:"
echo "   - Driver profiles (auto-created from Slack users)"
echo "   - Van profiles (auto-created when needed)"
echo "   - Image uploads with damage assessment"
echo "   - Rating system (0-3 scale)"
echo "   - Proper relationships between drivers, vans, and images"
EOF

echo ""
echo "🎉 DEPLOYMENT SUCCESSFUL!"
echo ""
echo "📋 **IMPORTANT: Execute these SQL files in Supabase:**"
echo "   1. complete_database_schema.sql"
echo "   2. simple_metadata_function.sql"
echo ""
echo "🧪 **Test the new features:**"
echo "   - 'van 123' + image = Basic upload"
echo "   - 'van 456 damage: scratched door rating: 2' + image = Full assessment"
echo "   - 'van 789 condition: 3' + image = Rating only"
echo ""
echo "📊 **New capabilities:**"
echo "   ✅ Driver profiles linked to Slack users"
echo "   ✅ Van profiles with status tracking"
echo "   ✅ Damage descriptions and ratings"
echo "   ✅ Image relationships to both drivers and vans"
echo "   ✅ Chronological ordering of images"
echo "   ✅ Database views for easy querying"
EOF 
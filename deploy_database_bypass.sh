#!/bin/bash

# Deploy Database Bypass Bot to EC2
# This script uploads the new bot and SQL function to fix the storage constraint issue

set -e

SERVER="ubuntu@3.15.163.231"
KEY_FILE="~/Downloads/supabase.pem"
REMOTE_DIR="/home/ubuntu/slack_bot"

echo "🚀 Deploying Database Bypass Bot..."

# Upload the new bot file
echo "📤 Uploading database_bypass_bot.py..."
scp -i "$KEY_FILE" database_bypass_bot.py "$SERVER:$REMOTE_DIR/"

# Upload the SQL function
echo "📤 Uploading create_bypass_function.sql..."
scp -i "$KEY_FILE" create_bypass_function.sql "$SERVER:$REMOTE_DIR/"

# Connect to server and deploy
echo "🔗 Connecting to server to deploy..."
ssh -i "$KEY_FILE" "$SERVER" << 'EOF'
cd /home/ubuntu/slack_bot

echo "📋 Current directory contents:"
ls -la

echo "🛑 Stopping current bot service..."
sudo systemctl stop slack_bot.service

echo "📁 Backing up current bot..."
if [ -f slack_supabase_bot.py ]; then
    cp slack_supabase_bot.py slack_supabase_bot.py.backup.$(date +%Y%m%d_%H%M%S)
fi

echo "🔄 Replacing bot with database bypass version..."
cp database_bypass_bot.py slack_supabase_bot.py

echo "📊 Checking SQL function file..."
if [ -f create_bypass_function.sql ]; then
    echo "✅ SQL function file uploaded successfully"
    echo "📝 File size: $(wc -l < create_bypass_function.sql) lines"
    echo "🔍 First few lines:"
    head -5 create_bypass_function.sql
else
    echo "❌ SQL function file not found!"
    exit 1
fi

echo "🚀 Starting bot service..."
sudo systemctl start slack_bot.service

echo "⏱️ Waiting for service to start..."
sleep 3

echo "📊 Checking service status..."
sudo systemctl status slack_bot.service --no-pager -l

echo "📋 Recent logs:"
sudo journalctl -u slack_bot.service --since "1 minute ago" --no-pager

echo ""
echo "🎯 NEXT STEPS:"
echo "1. Run the SQL function in Supabase SQL Editor:"
echo "   - Copy contents of create_bypass_function.sql"
echo "   - Paste and execute in Supabase dashboard"
echo "   - Test with: SELECT public.test_slack_bot_bypass();"
echo ""
echo "2. Test the bot:"
echo "   - Upload an image with 'van 123' in Slack"
echo "   - Check logs: sudo journalctl -u slack_bot.service -f"
echo ""
echo "3. If issues persist, check:"
echo "   - Database function exists: SELECT public.check_storage_system();"
echo "   - Bot logs for database function calls"

EOF

echo ""
echo "✅ Deployment completed!"
echo ""
echo "🔧 MANUAL STEPS REQUIRED:"
echo "1. Go to Supabase SQL Editor: https://supabase.com/dashboard/project/lcvbagsksedduygdzsca/sql"
echo "2. Copy and execute the contents of create_bypass_function.sql"
echo "3. Test the function: SELECT public.test_slack_bot_bypass();"
echo "4. Test bot by uploading image with 'van 123' message"
echo ""
echo "📊 Monitor logs with:"
echo "ssh -i $KEY_FILE $SERVER 'sudo journalctl -u slack_bot.service -f'" 
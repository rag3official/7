#!/bin/bash
# Quick configuration script for Claude AI Enhanced Slack Bot

echo "🤖 Claude AI Enhanced Slack Bot Configuration"
echo "=============================================="
echo ""

# Check if we're on the EC2 instance
if [ ! -d "/home/ubuntu/claude-bot" ]; then
    echo "❌ Claude bot directory not found. Please run this on the EC2 instance."
    echo "📋 Run: ssh -i ~/Downloads/supabase.pem ubuntu@3.15.163.231"
    exit 1
fi

cd /home/ubuntu/claude-bot

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "❌ .env file not found. Creating from template..."
    cp claude_bot_env_template.txt .env
fi

echo "📝 Current .env file contents:"
echo "=============================="
cat .env
echo ""
echo "=============================="
echo ""

echo "🔑 Required API Keys:"
echo "• SLACK_BOT_TOKEN - From Slack App settings"
echo "• SLACK_APP_TOKEN - From Slack App settings (Socket Mode)"  
echo "• SUPABASE_URL - From Supabase project settings"
echo "• SUPABASE_KEY - From Supabase project API settings"
echo "• CLAUDE_API_KEY - From Anthropic Console"
echo ""

read -p "📝 Do you want to edit the .env file now? (y/n): " edit_env

if [ "$edit_env" = "y" ] || [ "$edit_env" = "Y" ]; then
    nano .env
fi

echo ""
echo "🔧 Service Management:"
echo "• Start: sudo systemctl start claude_slack_bot"
echo "• Stop: sudo systemctl stop claude_slack_bot"
echo "• Status: sudo systemctl status claude_slack_bot"
echo "• Logs: sudo journalctl -u claude_slack_bot -f"
echo ""

read -p "🚀 Do you want to start the Claude AI bot service now? (y/n): " start_service

if [ "$start_service" = "y" ] || [ "$start_service" = "Y" ]; then
    echo "🔄 Starting Claude AI Enhanced Slack Bot..."
    sudo systemctl start claude_slack_bot
    sleep 2
    
    echo "📊 Service Status:"
    sudo systemctl status claude_slack_bot --no-pager
    
    echo ""
    echo "📋 To view live logs, run:"
    echo "sudo journalctl -u claude_slack_bot -f"
fi

echo ""
echo "✅ Configuration complete!"
echo "🧪 Test by uploading a van image to Slack with a van number (e.g., 'van 123')"

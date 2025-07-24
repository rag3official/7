#!/bin/bash
# Deploy Claude AI Enhanced Slack Bot to EC2

echo "🚀 Deploying Claude AI Enhanced Slack Bot..."

# Set variables
BOT_NAME="claude_enhanced_slack_bot"
SERVICE_NAME="claude_slack_bot"
WORK_DIR="/home/ubuntu/claude-bot"

# Create working directory
echo "📁 Creating working directory..."
mkdir -p $WORK_DIR
cd $WORK_DIR

# Copy files (assuming they're in current directory)
echo "📋 Copying bot files..."
cp ../claude_enhanced_slack_bot.py .
cp ../claude_bot_requirements.txt .
cp ../claude_bot_env_template.txt .

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install -r claude_bot_requirements.txt

# Create environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "⚙️ Creating environment file template..."
    cp claude_bot_env_template.txt .env
    echo "❗ Please edit .env file with your actual API keys!"
fi

# Make bot executable
chmod +x claude_enhanced_slack_bot.py

# Create systemd service file
echo "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOL
[Unit]
Description=Claude AI Enhanced Slack Bot Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=$WORK_DIR
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/python3 $WORK_DIR/claude_enhanced_slack_bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=claude-slack-bot

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and enable service
echo "🔄 Reloading systemd..."
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME

echo "✅ Claude AI Enhanced Slack Bot deployed successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Edit $WORK_DIR/.env with your API keys"
echo "2. Start the service: sudo systemctl start $SERVICE_NAME"
echo "3. Check status: sudo systemctl status $SERVICE_NAME"
echo "4. View logs: sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "🔑 Required API Keys:"
echo "• SLACK_BOT_TOKEN - From Slack App settings"
echo "• SLACK_APP_TOKEN - From Slack App settings (Socket Mode)"
echo "• SUPABASE_URL - From Supabase project settings"
echo "• SUPABASE_KEY - From Supabase project API settings"
echo "• CLAUDE_API_KEY - From Anthropic Console"

#!/bin/bash

# Create project directory
mkdir -p ~/slack_bot
cd ~/slack_bot

# Set up virtual environment
echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Create requirements.txt
echo "📝 Creating requirements.txt..."
cat > requirements.txt << EOL
slack-bolt>=1.18.0
python-dotenv>=1.0.0
supabase>=2.0.0
requests>=2.31.0
anthropic>=0.7.0
EOL

# Install requirements
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Create .env template
echo "🔑 Creating .env template..."
cat > .env.template << EOL
# Slack Configuration
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_APP_TOKEN=xapp-your-app-token
SLACK_SIGNING_SECRET=your-signing-secret

# Supabase Configuration
SUPABASE_URL=your-supabase-url
SUPABASE_KEY=your-supabase-key

# Claude API Configuration
CLAUDE_API_KEY=your-claude-api-key
EOL

# Copy .env template if .env doesn't exist
if [ ! -f .env ]; then
    cp .env.template .env
    echo "⚠️ Please update the .env file with your actual credentials"
fi

# Create systemd service file
echo "🔧 Creating systemd service file..."
cat > slack_bot.service << EOL
[Unit]
Description=Slack Bot for Van Fleet Management
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/slack_bot
Environment=PATH=/home/ubuntu/slack_bot/venv/bin
ExecStart=/home/ubuntu/slack_bot/venv/bin/python slack_supabase_bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Move files to correct locations
echo "📂 Moving files to correct locations..."
mv slack_supabase_bot.py ~/slack_bot/

# Set up systemd service
echo "🔧 Setting up systemd service..."
sudo mv slack_bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable slack_bot
sudo systemctl restart slack_bot

echo "✅ Setup complete!"
echo "📝 Check logs with: journalctl -u slack_bot -f"
echo "⚠️ Don't forget to update the .env file with your actual credentials" 
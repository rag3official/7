#!/bin/bash

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Python and pip
sudo apt-get install -y python3 python3-pip python3-venv

# Create directory for the bot
mkdir -p ~/slack-bot
cd ~/slack-bot

# Create and activate virtual environment
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
pip install -r requirements.txt

# Create systemd service file
echo "🔧 Creating systemd service file..."
cat > slack-supabase-bot.service << EOL
[Unit]
Description=Slack Bot for Van Fleet Management
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/slack-bot
Environment=PATH=/home/ubuntu/slack-bot/venv/bin
ExecStart=/home/ubuntu/slack-bot/venv/bin/python slack_supabase_bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Move files to correct locations
echo "📂 Moving files to correct locations..."
mv slack_supabase_bot.py ~/slack-bot/

# Set up systemd service
echo "🔧 Setting up systemd service..."
sudo mv slack-supabase-bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable slack-supabase-bot
sudo systemctl restart slack-supabase-bot

echo "✅ Setup complete!"
echo "📝 Check logs with: journalctl -u slack-supabase-bot -f" 
#!/bin/bash

# Create project directory
mkdir -p ~/slack_bot
cd ~/slack_bot

# Set up virtual environment
echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install requirements
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Move files to correct locations
mv slack_supabase_bot.py ~/slack_bot/
mv .env ~/slack_bot/ 2>/dev/null || echo "⚠️ Don't forget to create .env file"

# Set up systemd service
echo "🔧 Setting up systemd service..."
sudo mv slack_bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable slack_bot
sudo systemctl restart slack_bot

echo "✅ Setup complete!"
echo "📝 Check logs with: journalctl -u slack_bot -f"

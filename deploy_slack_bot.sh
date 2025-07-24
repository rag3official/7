#!/bin/bash

# Configuration
EC2_HOST="ubuntu@3.15.163.231"
PEM_FILE=~/Downloads/supabase.pem

echo "🚀 Deploying Slack bot to EC2..."

# Ensure PEM file permissions are correct
chmod 400 "$PEM_FILE"

# Create temporary deployment directory
echo "📁 Creating deployment package..."
mkdir -p deploy

# Copy the bot script
cp slack_supabase_bot.py deploy/

# Create requirements.txt
echo "📝 Creating requirements.txt..."
cat > deploy/requirements.txt << EOL
slack-bolt
python-dotenv
supabase
requests
anthropic
python-dotenv
EOL

# Create systemd service file
echo "⚙️ Creating service file..."
cat > deploy/slack_bot.service << EOL
[Unit]
Description=Slack Bot Service with Claude Integration
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/slack_bot
Environment=PATH=/home/ubuntu/slack_bot/venv/bin
EnvironmentFile=/home/ubuntu/slack_bot/.env
ExecStart=/home/ubuntu/slack_bot/venv/bin/python slack_supabase_bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Create setup script
echo "🛠️ Creating setup script..."
cat > deploy/setup.sh << EOL
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
EOL

# Make setup script executable
chmod +x deploy/setup.sh

# Transfer files to EC2
echo "📤 Transferring files to EC2..."
scp -i "$PEM_FILE" -r deploy/* "$EC2_HOST":~/

# Run setup script
echo "🔄 Running setup script..."
ssh -i "$PEM_FILE" "$EC2_HOST" "./setup.sh"

echo "
🎉 Deployment complete! Next steps:

1. SSH into the instance:
   ssh -i ~/Downloads/supabase.pem ubuntu@3.15.163.231

2. Create/update .env file:
   nano ~/slack_bot/.env

   Add these environment variables:
   SUPABASE_URL=your_supabase_url
   SUPABASE_KEY=your_supabase_key
   SLACK_BOT_TOKEN=your_slack_bot_token
   SLACK_APP_TOKEN=your_slack_app_token
   SLACK_SIGNING_SECRET=your_slack_signing_secret
   CLAUDE_API_KEY=your_claude_api_key

3. Restart the bot:
   sudo systemctl restart slack_bot

4. Check the logs:
   journalctl -u slack_bot -f
" 
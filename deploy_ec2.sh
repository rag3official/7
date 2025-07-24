#!/bin/bash

# Configuration
EC2_HOST="3.15.163.231"
EC2_USER="ubuntu"
KEY_FILE="supabase.pem"
REMOTE_DIR="/home/ubuntu/slack-supabase-bot"

# Check if key file exists
if [ ! -f "$KEY_FILE" ]; then
    echo "Error: SSH key file $KEY_FILE not found"
    exit 1
fi

# Ensure key file has correct permissions
chmod 600 "$KEY_FILE"

# Create deployment package
echo "Creating deployment package..."
mkdir -p deploy
cp slack_supabase_bot.py deploy/
cp van_damage_tracker/supabase/migrations/*.sql deploy/

# Create requirements.txt
cat > deploy/requirements.txt << EOL
slack-bolt==1.18.0
supabase==1.0.3
python-dotenv==1.0.0
requests==2.31.0
Pillow==10.0.0
EOL

# Create service file
cat > deploy/slack-supabase-bot.service << EOL
[Unit]
Description=Slack Supabase Bot Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/slack-supabase-bot
Environment=PATH=/home/ubuntu/slack-supabase-bot/venv/bin
ExecStart=/home/ubuntu/slack-supabase-bot/venv/bin/python slack_supabase_bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Create deployment script
cat > deploy/deploy.sh << EOL
#!/bin/bash

# Stop the service
sudo systemctl stop slack-supabase-bot

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

# Activate virtual environment and install requirements
source venv/bin/activate
pip install -r requirements.txt

# Apply database migrations
for migration in *.sql; do
    echo "Applying migration: \$migration"
    PGPASSWORD=\$DB_PASSWORD psql -h \$DB_HOST -U \$DB_USER -d \$DB_NAME -f "\$migration"
done

# Update service file
sudo cp slack-supabase-bot.service /etc/systemd/system/
sudo systemctl daemon-reload

# Start the service
sudo systemctl start slack-supabase-bot
sudo systemctl enable slack-supabase-bot

# Check service status
sudo systemctl status slack-supabase-bot
EOL

# Make deployment script executable
chmod +x deploy/deploy.sh

# Transfer files to EC2
echo "Transferring files to EC2..."
ssh -i "$KEY_FILE" "$EC2_USER@$EC2_HOST" "mkdir -p $REMOTE_DIR"
scp -i "$KEY_FILE" -r deploy/* "$EC2_USER@$EC2_HOST:$REMOTE_DIR/"

# Execute deployment script
echo "Executing deployment script..."
ssh -i "$KEY_FILE" "$EC2_USER@$EC2_HOST" "cd $REMOTE_DIR && bash deploy.sh"

# Cleanup
rm -rf deploy

echo "Deployment completed!" 
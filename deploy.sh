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
cp supabase/migrations/20240321000000_create_van_images_table.sql deploy/

# Create requirements.txt if it doesn't exist
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

# Create image processing utilities
cat > deploy/image_utils.py << EOL
from PIL import Image
import io
import os
from datetime import datetime, timedelta
import hashlib

class ImageProcessor:
    def __init__(self, max_size=(1920, 1080), quality=85):
        self.max_size = max_size
        self.quality = quality

    def process_image(self, image_data):
        # Open image from bytes
        img = Image.open(io.BytesIO(image_data))
        
        # Get original metadata
        metadata = {
            'format': img.format,
            'mode': img.mode,
            'size': img.size,
            'original_size_bytes': len(image_data)
        }
        
        # Resize if needed
        if img.size[0] > self.max_size[0] or img.size[1] > self.max_size[1]:
            img.thumbnail(self.max_size, Image.Resampling.LANCZOS)
        
        # Convert to bytes
        output = io.BytesIO()
        img.save(output, format='JPEG', quality=self.quality)
        processed_data = output.getvalue()
        
        # Add processing metadata
        metadata.update({
            'processed_size': img.size,
            'processed_size_bytes': len(processed_data),
            'compression_ratio': len(processed_data) / len(image_data),
            'processed_at': datetime.now().isoformat()
        })
        
        return processed_data, metadata

    @staticmethod
    def calculate_hash(image_data):
        return hashlib.md5(image_data).hexdigest()

    @staticmethod
    def should_expire(created_at, retention_days=90):
        expiration_date = datetime.now() - timedelta(days=retention_days)
        return created_at < expiration_date
EOL

# Update main bot script with image processing
sed -i '' 's/import hashlib/import hashlib\nfrom image_utils import ImageProcessor/g' deploy/slack_supabase_bot.py
sed -i '' 's/image_hash = hashlib.md5(image_response.content).hexdigest()/processor = ImageProcessor()\nprocessed_image, metadata = processor.process_image(image_response.content)\nimage_hash = processor.calculate_hash(processed_image)/g' deploy/slack_supabase_bot.py

# Create deployment script
cat > deploy/deploy_updates.sh << EOL
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

# Apply database migration
PGPASSWORD=\$DB_PASSWORD psql -h \$DB_HOST -U \$DB_USER -d \$DB_NAME -f 20240321000000_create_van_images_table.sql

# Update service file
sudo cp slack-supabase-bot.service /etc/systemd/system/
sudo systemctl daemon-reload

# Start the service
sudo systemctl start slack-supabase-bot
sudo systemctl enable slack-supabase-bot
EOL

# Make deployment script executable
chmod +x deploy/deploy_updates.sh

# Transfer files to EC2
echo "Transferring files to EC2..."
ssh -i "$KEY_FILE" "$EC2_USER@$EC2_HOST" "mkdir -p $REMOTE_DIR"
scp -i "$KEY_FILE" -r deploy/* "$EC2_USER@$EC2_HOST:$REMOTE_DIR/"

# Execute deployment script
echo "Executing deployment script..."
ssh -i "$KEY_FILE" "$EC2_USER@$EC2_HOST" "cd $REMOTE_DIR && bash deploy_updates.sh"

# Cleanup
rm -rf deploy

echo "Deployment completed!" 
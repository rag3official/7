#!/bin/bash

# Configuration
EC2_HOST="3.15.163.231"
EC2_USER="ubuntu"
KEY_FILE="supabase.pem"
REMOTE_DIR="/home/ubuntu/slack-supabase-bot"

# Function to check if we can connect with a key
check_ssh_connection() {
    local key=$1
    ssh -i "$key" -o "BatchMode=yes" -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" "$EC2_USER@$EC2_HOST" "echo 2>&1" >/dev/null
    return $?
}

# Try to find an existing key that works
for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519 ~/.ssh/id_ecdsa; do
    if [ -f "$key" ] && check_ssh_connection "$key"; then
        echo "Found working key: $key"
        WORKING_KEY="$key"
        break
    fi
done

# Generate new key if needed
if [ ! -f "$KEY_FILE" ]; then
    echo "Generating new SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N ""
    
    if [ -n "$WORKING_KEY" ]; then
        # Use working key to add new key
        echo "Using existing key to add new key..."
        cat "${KEY_FILE}.pub" | ssh -i "$WORKING_KEY" "$EC2_USER@$EC2_HOST" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    else
        echo "Error: No working SSH key found and cannot add new key"
        echo "Please manually add this public key to your EC2 instance:"
        cat "${KEY_FILE}.pub"
        exit 1
    fi
fi

# Ensure key file has correct permissions
chmod 600 "$KEY_FILE"

# Test SSH connection with new key
echo "Testing SSH connection..."
if ! ssh -i "$KEY_FILE" -o "StrictHostKeyChecking=no" "$EC2_USER@$EC2_HOST" "echo 'SSH connection successful'"; then
    echo "Error: Could not establish SSH connection with new key"
    exit 1
fi

# Create update package
echo "Creating update package..."
mkdir -p update
cp slack_supabase_bot.py update/

# Create image processing utilities
cat > update/image_utils.py << EOL
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

# Create update script
cat > update/update.sh << EOL
#!/bin/bash

# Stop the service
sudo systemctl stop slack-supabase-bot

# Install Pillow if not already installed
source venv/bin/activate
pip install Pillow==10.0.0

# Apply database migration
for migration in *.sql; do
    if [ -f "\$migration" ]; then
        echo "Applying migration: \$migration"
        PGPASSWORD=\$DB_PASSWORD psql -h \$DB_HOST -U \$DB_USER -d \$DB_NAME -f "\$migration"
    fi
done

# Update Python files
cp slack_supabase_bot.py /home/ubuntu/slack-supabase-bot/
cp image_utils.py /home/ubuntu/slack-supabase-bot/

# Start the service
sudo systemctl start slack-supabase-bot

# Check service status
sleep 2
sudo systemctl status slack-supabase-bot
EOL

# Make update script executable
chmod +x update/update.sh

# Copy migration files
cp van_damage_tracker/supabase/migrations/20240321000001_add_image_metadata.sql update/

# Transfer files to EC2
echo "Transferring update files to EC2..."
scp -i "$KEY_FILE" -r update/* "$EC2_USER@$EC2_HOST:$REMOTE_DIR/"

# Execute update script
echo "Executing update script..."
ssh -i "$KEY_FILE" "$EC2_USER@$EC2_HOST" "cd $REMOTE_DIR && bash update.sh"

# Cleanup
rm -rf update

echo "Service update completed!" 
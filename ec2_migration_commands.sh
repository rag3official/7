#!/bin/bash

# Stop the bot service
echo "Stopping Slack bot service..."
sudo systemctl stop slack-supabase-bot

# Activate virtual environment
echo "Activating virtual environment..."
source /home/ubuntu/slack-bot/venv/bin/activate

# Apply migration using Python script
echo "Applying database migration..."
if python3 apply_migration.py migrate_driver_profiles.sql; then
    echo "Migration completed successfully!"
else
    echo "Migration failed. Rolling back..."
    sudo systemctl start slack-supabase-bot
    exit 1
fi

# Deactivate virtual environment
deactivate

# Start the bot service
echo "Starting Slack bot service..."
sudo systemctl start slack-supabase-bot

# Check bot service status
echo "Checking bot service status..."
sudo systemctl status slack-supabase-bot

echo "Migration complete! Please verify the bot is working correctly." 
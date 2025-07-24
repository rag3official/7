#!/bin/bash

# Stop both bot services
ssh -i ~/Downloads/supabase.pem ubuntu@3.15.163.231 "sudo systemctl stop slack-supabase-bot.service slack_bot.service"

# Create a backup of the current bot file
ssh -i ~/Downloads/supabase.pem ubuntu@3.15.163.231 "cd /home/ubuntu/slack-bot && cp slack_supabase_bot.py slack_supabase_bot.py.bak-$(date +%Y%m%d-%H%M%S)"

# Copy our updated functions
scp -i ~/Downloads/supabase.pem updated_functions.py ubuntu@3.15.163.231:/home/ubuntu/slack-bot/updated_functions.py

# Update the functions in the bot file
ssh -i ~/Downloads/supabase.pem ubuntu@3.15.163.231 "cd /home/ubuntu/slack-bot && \
  python3 -c '
import re

# Read the current bot file
with open(\"slack_supabase_bot.py\", \"r\") as f:
    content = f.read()

# Read the updated functions
with open(\"updated_functions.py\", \"r\") as f:
    new_functions = f.read()

# Replace the functions in the content
content = re.sub(
    r\"def get_or_create_driver_profile.*?def upload_to_supabase_storage.*?def download_image\",
    new_functions + \"\ndef download_image\",
    content,
    flags=re.DOTALL
)

# Write the updated content back
with open(\"slack_supabase_bot.py\", \"w\") as f:
    f.write(content)
'"

# Clean up the temporary file
ssh -i ~/Downloads/supabase.pem ubuntu@3.15.163.231 "cd /home/ubuntu/slack-bot && rm updated_functions.py"

# Start both bot services
ssh -i ~/Downloads/supabase.pem ubuntu@3.15.163.231 "sudo systemctl start slack-supabase-bot.service slack_bot.service"

# Check both services status
ssh -i ~/Downloads/supabase.pem ubuntu@3.15.163.231 "echo 'Status of slack-supabase-bot:' && \
  sudo systemctl status slack-supabase-bot.service && \
  echo -e '\nStatus of slack_bot:' && \
  sudo systemctl status slack_bot.service" 
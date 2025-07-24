#!/bin/bash

# Deploy Migration Script to Fix Schema Issues
# This script uploads the migration to fix the "van_number column does not exist" error

set -e

SERVER="ubuntu@3.15.163.231"
KEY_FILE="~/Downloads/supabase.pem"
REMOTE_DIR="/home/ubuntu/slack_bot"

echo "🚀 Deploying Migration Script..."

# Upload migration script
echo "📤 Uploading migration script..."
scp -i "$KEY_FILE" migration_script.sql "$SERVER:$REMOTE_DIR/"

echo ""
echo "✅ MIGRATION SCRIPT UPLOADED!"
echo ""
echo "🎯 **CRITICAL: Execute this migration in Supabase SQL Editor:**"
echo ""
echo "1. Go to: https://supabase.com/dashboard/project/lcvbagsksedduygdzsca/sql"
echo "2. Copy and paste the contents of migration_script.sql"
echo "3. Click 'Run' to execute the migration"
echo ""
echo "📋 **What this migration does:**"
echo "   ✅ Backs up existing 'vans' table to 'vans_backup'"
echo "   ✅ Creates new 'driver_profiles' table"
echo "   ✅ Creates new 'van_profiles' table with van_number column"
echo "   ✅ Creates new 'van_images' table with full relationships"
echo "   ✅ Migrates existing van data to new structure"
echo "   ✅ Creates indexes and views for performance"
echo "   ✅ Updates the upload function to work with new schema"
echo ""
echo "🔧 **After running the migration, the bot will work with:**"
echo "   - driver_profiles (auto-created from Slack users)"
echo "   - van_profiles (with van_number column)"
echo "   - van_images (with damage assessment and ratings)"
echo ""
echo "🧪 **Test after migration:**"
echo "   - 'van 123' + image = Should work perfectly"
echo "   - 'van 456 damage: scratched door rating: 2' + image = Full features" 
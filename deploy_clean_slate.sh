#!/bin/bash

# Deploy Clean Slate Migration Script
# This script uploads the clean slate migration to the server

echo "🚀 Deploying Clean Slate Migration..."

# Upload the clean slate migration script
echo "📤 Uploading clean_slate_migration.sql..."
scp -i ~/Downloads/supabase.pem clean_slate_migration.sql ubuntu@3.15.163.231:/home/ubuntu/

echo "✅ Clean slate migration script uploaded to server!"
echo ""
echo "📋 Next Steps:"
echo "1. SSH into the server: ssh -i ~/Downloads/supabase.pem ubuntu@3.15.163.231"
echo "2. Run the migration in Supabase SQL Editor by copying the contents of clean_slate_migration.sql"
echo "3. Or execute it directly: psql [your-supabase-connection-string] -f clean_slate_migration.sql"
echo ""
echo "⚠️  WARNING: This will DELETE ALL existing tables and data!"
echo "   Make sure you have backups if needed."
echo ""
echo "🔧 After migration, the profile-aware bot should work correctly." 
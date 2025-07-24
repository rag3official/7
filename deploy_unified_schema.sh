#!/bin/bash

# Deploy Unified Database Schema for Van Fleet Management
# This script applies the unified schema that works for both Slack bot and Flutter app

set -e

echo "🚀 Deploying Unified Database Schema..."

# Check if required environment variables are set
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "❌ Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables must be set"
    echo "   Please set them in your environment:"
    echo "   export SUPABASE_URL='https://your-project.supabase.co'"
    echo "   export SUPABASE_SERVICE_ROLE_KEY='your-service-role-key'"
    exit 1
fi

echo "✅ Environment variables found"
echo "📡 Supabase URL: $SUPABASE_URL"

# Apply the unified schema
echo "📋 Applying unified database schema..."

psql "$SUPABASE_URL/db" \
  --set=ON_ERROR_STOP=1 \
  --echo-queries \
  --file=unified_database_schema.sql \
  --set=PGPASSWORD="$SUPABASE_SERVICE_ROLE_KEY"

if [ $? -eq 0 ]; then
    echo "✅ Unified database schema applied successfully!"
    echo ""
    echo "🎯 Next Steps:"
    echo "   1. Test the Flutter app: cd van_damage_tracker && flutter run -d chrome"
    echo "   2. Test the Slack bot: python database_only_bot.py"
    echo "   3. Upload an image via Slack to test the integration"
    echo ""
    echo "📊 Schema Summary:"
    echo "   - driver_profiles: User management"
    echo "   - van_profiles: Van fleet management"
    echo "   - van_images: Image storage with base64 support"
    echo "   - van_assignments: Driver-van assignment tracking"
else
    echo "❌ Failed to apply database schema"
    exit 1
fi 
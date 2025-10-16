#!/bin/bash

# Load environment variables
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_KEY" ]; then
  echo "❌ Error: SUPABASE_URL and SUPABASE_KEY must be set in .env file"
  exit 1
fi

echo "🚀 Deploying SQL fix..."

# Deploy the SQL fix
curl -X POST \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  -d @fix_image_display_v6.sql \
  "${SUPABASE_URL}/rest/v1/rpc/exec_sql"

if [ $? -eq 0 ]; then
  echo "✅ SQL fix deployed successfully"
else
  echo "❌ Failed to deploy SQL fix"
  exit 1
fi
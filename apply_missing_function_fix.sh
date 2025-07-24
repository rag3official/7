#!/bin/bash

echo "🔧 Applying missing save_slack_image function to Supabase database..."
echo ""
echo "📋 You'll need to get your database connection details from Supabase Dashboard:"
echo "   1. Go to https://supabase.com/dashboard"
echo "   2. Select your project"
echo "   3. Go to Settings → Database"
echo "   4. Copy the 'Connection string' (URI format)"
echo ""
echo "Or alternatively:"
echo "   1. Go to SQL Editor in Supabase Dashboard"
echo "   2. Paste the content of complete_storage_fix.sql"
echo "   3. Click 'Run'"
echo ""

read -p "Do you have your database connection string? (y/n): " has_connection

if [ "$has_connection" = "y" ] || [ "$has_connection" = "Y" ]; then
    echo ""
    read -p "Enter your database connection string: " db_connection
    
    echo ""
    echo "🚀 Applying SQL fix..."
    
    psql "$db_connection" -f complete_storage_fix.sql
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ SQL script applied successfully!"
        echo "🎯 The save_slack_image function should now be available."
        echo "🔄 Try running your Slack bot again."
    else
        echo ""
        echo "❌ Failed to apply SQL script."
        echo "💡 Try using the Supabase Dashboard SQL Editor instead."
    fi
else
    echo ""
    echo "📖 Manual Instructions:"
    echo "1. Go to https://supabase.com/dashboard"
    echo "2. Select your project (lcvbagsksedduygdzsca)"
    echo "3. Go to SQL Editor"
    echo "4. Create a new query"
    echo "5. Copy and paste the entire content of complete_storage_fix.sql"
    echo "6. Click 'Run'"
    echo ""
    echo "This will create the missing save_slack_image function and fix your error."
fi 
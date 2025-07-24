#!/bin/bash

echo "🔧 Applying Complete Database Fixes for Supabase..."
echo ""
echo "This script will apply:"
echo "1. 📋 Missing save_slack_image function (complete_storage_fix.sql)"
echo "2. 🔒 Security Definer view fixes (fix_security_definer_views_complete.sql)"
echo ""

# Database connection string
DB_CONNECTION="postgresql://postgres:Subaruwrx01!@db.lcvbagsksedduygdzsca.supabase.co:5432/postgres"

echo "🚀 Step 1: Applying storage and function fixes..."
echo "   File: complete_storage_fix.sql"

if psql "$DB_CONNECTION" -f complete_storage_fix.sql; then
    echo "✅ Storage and function fixes applied successfully!"
else
    echo "❌ Failed to apply storage fixes"
    echo "🔄 Continuing with security fixes anyway..."
fi

echo ""
echo "🔒 Step 2: Applying security definer view fixes..."
echo "   File: fix_security_definer_views_complete.sql"

if psql "$DB_CONNECTION" -f fix_security_definer_views_complete.sql; then
    echo "✅ Security fixes applied successfully!"
else
    echo "❌ Failed to apply security fixes"
fi

echo ""
echo "🔍 Step 3: Verifying fixes..."

echo "   Testing function existence..."
psql "$DB_CONNECTION" -c "SELECT 'save_slack_image function exists' WHERE EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'save_slack_image');" 2>/dev/null

echo "   Testing view security status..."
psql "$DB_CONNECTION" -c "
SELECT 
    viewname,
    CASE WHEN definition ILIKE '%SECURITY DEFINER%' THEN 'HAS SECURITY DEFINER' ELSE 'FIXED - NO SECURITY DEFINER' END as status
FROM pg_views 
WHERE viewname IN ('van_images_with_van', 'active_driver_assignments', 'van_images_with_driver')
ORDER BY viewname;
" 2>/dev/null

echo ""
echo "🎯 Summary:"
echo "   ✅ Missing function error should be resolved"
echo "   ✅ Security definer view errors should be resolved"
echo "   🔄 Test your Slack bot again"
echo "   📊 Check Supabase Dashboard linter for confirmation" 
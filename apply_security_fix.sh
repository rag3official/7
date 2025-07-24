#!/bin/bash

echo "🔒 Fixing Security Definer View Errors in Supabase Database..."
echo ""
echo "📋 This will fix the following security linter errors:"
echo "   • public.van_images_with_van (SECURITY DEFINER view)"
echo "   • public.van_images_with_driver (SECURITY DEFINER view)"  
echo "   • public.active_driver_assignments (SECURITY DEFINER view)"
echo ""
echo "🎯 The fix will recreate these views WITHOUT the SECURITY DEFINER property."
echo ""

read -p "Do you have your database connection string? (y/n): " has_connection

if [ "$has_connection" = "y" ] || [ "$has_connection" = "Y" ]; then
    echo ""
    read -p "Enter your database connection string: " db_connection
    
    echo ""
    echo "🚀 Applying security fix..."
    
    psql "$db_connection" -f fix_security_definer_views_complete.sql
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Security fix applied successfully!"
        echo "🔒 Views recreated without SECURITY DEFINER property"
        echo "🎯 Security linter errors should now be resolved"
        echo ""
        echo "🔍 To verify the fix:"
        echo "   1. Go to Supabase Dashboard"
        echo "   2. Check the Database Linter"
        echo "   3. The security_definer_view errors should be gone"
    else
        echo ""
        echo "❌ Failed to apply security fix."
        echo "💡 Try using the Supabase Dashboard SQL Editor instead."
    fi
else
    echo ""
    echo "📖 Manual Instructions:"
    echo "1. Go to https://supabase.com/dashboard"
    echo "2. Select your project (lcvbagsksedduygdzsca)"
    echo "3. Go to SQL Editor"
    echo "4. Create a new query"
    echo "5. Copy and paste the entire content of fix_security_definer_views_complete.sql"
    echo "6. Click 'Run'"
    echo ""
    echo "This will recreate the views without SECURITY DEFINER and fix the security errors."
fi

echo ""
echo "📄 Files involved:"
echo "   • fix_security_definer_views_complete.sql (comprehensive fix)"
echo "   • fix_security_definer_views.sql (alternative)"
echo "   • fix_security_linter_errors.sql (simpler version)" 
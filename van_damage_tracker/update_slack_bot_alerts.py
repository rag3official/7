# Add this code to your EC2 Slack bot after Claude AI analysis
# This will update the van_profiles.alerts field for damage level 2/3

def update_van_alerts(van_id, damage_level):
    """
    Update van alerts based on damage level from Claude AI analysis
    Called after Claude AI gives damage rating
    """
    try:
        # Set alert flag for damage level 2 or 3
        alert_flag = 'yes' if damage_level >= 2 else 'no'
        
        print(f"🚨 Updating alerts for van ID: {van_id}, damage level: {damage_level}")
        
        # Update van_profiles table with alert flag
        response = supabase.table('van_profiles').update({
            'alerts': alert_flag,
            'updated_at': 'now()'
        }).eq('id', van_id).execute()
        
        if response.data:
            if alert_flag == 'yes':
                print(f"🚨 ALERT SET: Van {van_id} flagged for damage level {damage_level}")
            else:
                print(f"✅ Alert cleared for van {van_id} (damage level {damage_level})")
        else:
            print(f"❌ Failed to update alerts for van {van_id}")
            
        return response.data
        
    except Exception as e:
        print(f"❌ Error updating van alerts: {e}")
        return None

# INTEGRATION EXAMPLE - Add this to your existing Slack bot code:

# After Claude AI analysis, in your main processing function:
# Add this after line: "claude_analysis = analyze_with_claude(image_data)"

if claude_analysis and 'van_rating' in claude_analysis:
    damage_level = claude_analysis['van_rating']
    
    # Update van alerts based on damage level
    update_van_alerts(van_id, damage_level)
    
    # Log alert status
    if damage_level >= 2:
        print(f"🚨 HIGH DAMAGE ALERT: Van {van_number} has level {damage_level} damage!")
        # Optional: Send additional Slack notification for critical damage
        # slack_notification_critical_damage(van_number, damage_level)
    else:
        print(f"✅ Van {van_number} damage level {damage_level} - no alert needed")

# Add this to your van profile creation/update section:
# Make sure to include 'alerts' in your database queries

# Example updated van profile query:
"""
van_profiles_query = supabase.table('van_profiles').select('*').eq('van_number', van_number)
# OR when creating new van:
new_van_data = {
    'van_number': van_number,
    'make': 'Rental Van',
    'model': 'Fleet Vehicle',
    'status': 'active',
    'alerts': 'no',  # Default to no alerts
    'created_at': 'now()',
    'updated_at': 'now()'
}
""" 
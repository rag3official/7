# EC2 Slack Bot Integration for Van Alerts

## Step 1: Add the Update Alerts Function

Add this function to your `slack_supabase_bot.py` file (add it near the top after imports):

```python
def update_van_alerts(van_id, damage_level, van_number):
    """Update van alerts based on damage level from Claude AI analysis"""
    try:
        alert_flag = 'yes' if damage_level >= 2 else 'no'
        
        print(f"🚨 Updating alerts for van #{van_number}, damage level: {damage_level}")
        
        response = supabase.table('van_profiles').update({
            'alerts': alert_flag,
            'updated_at': 'now()'
        }).eq('id', van_id).execute()
        
        if response.data:
            if alert_flag == 'yes':
                print(f"🚨 CRITICAL DAMAGE ALERT: Van #{van_number} flagged for level {damage_level}")
            else:
                print(f"✅ Alert cleared for van #{van_number}")
            return True
        return False
        
    except Exception as e:
        print(f"❌ Error updating van alerts: {e}")
        return False
```

## Step 2: Find Your Claude Analysis Section

Look for this pattern in your existing code (around line with "Claude analysis result"):

```python
logger.info(f"🎯 Claude analysis result: {claude_result}")
```

## Step 3: Add Alerts Update After Claude Analysis

**Right after** the Claude analysis result logging, add this code:

```python
# Update van alerts based on damage level
if 'van_rating' in claude_result:
    damage_level = claude_result['van_rating']
    print(f"🎯 Damage level detected: {damage_level}")
    
    # Update alerts in database
    alert_updated = update_van_alerts(van_id, damage_level, van_number)
    
    if alert_updated and damage_level >= 2:
        print(f"🚨 HIGH DAMAGE ALERT: Van {van_number} requires immediate attention!")
```

## Step 4: Update Van Profile Creation

Find where you create new van profiles and make sure to include the alerts field.

**Find this pattern:**
```python
new_van_data = {
    'van_number': van_number,
    'make': 'Rental Van',
    # ... other fields
}
```

**Update it to:**
```python
new_van_data = {
    'van_number': van_number,
    'make': 'Rental Van',
    'model': 'Fleet Vehicle',
    'status': 'active',
    'alerts': 'no',  # Add this line
    'created_at': 'now()',
    'updated_at': 'now()'
}
```

## Step 5: Test the Integration

1. Run the SQL migration first (from `add_alerts_column.sql`)
2. Update your EC2 bot with the new code
3. Restart the bot service
4. Upload an image with damage to test

## Expected Log Output

You should see logs like:
```
🎯 Damage level detected: 2
🚨 Updating alerts for van #215, damage level: 2
🚨 CRITICAL DAMAGE ALERT: Van #215 flagged for level 2
🚨 HIGH DAMAGE ALERT: Van 215 requires immediate attention!
```

## File Locations

- **EC2 Bot File**: `/path/to/your/slack_supabase_bot.py`
- **SQL Migration**: Run `add_alerts_column.sql` in Supabase first
- **Service Restart**: `sudo systemctl restart your-bot-service` 
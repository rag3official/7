# Manual EC2 Slack Bot Update Steps

## Step 1: Connect to EC2
```bash
ssh -i ~/Downloads/supabase.pem ubuntu@3.15.163.231
```

## Step 2: First, run SQL migration in Supabase Dashboard
```sql
ALTER TABLE van_profiles 
ADD COLUMN IF NOT EXISTS alerts TEXT DEFAULT 'no' CHECK (alerts IN ('yes', 'no'));
```

## Step 3: Edit the bot file
```bash
sudo nano slack_supabase_bot.py
```

## Step 4: Add this function (add after imports, around line 50)
```python
def update_van_alerts(van_id, damage_level, van_number):
    """Update van alerts based on damage level from Claude AI analysis"""
    try:
        alert_flag = 'yes' if damage_level >= 2 else 'no'
        
        print(f"🚨 Updating alerts for van #{van_number}, damage level: {damage_level}")
        logger.info(f"🚨 Updating alerts for van #{van_number}, damage level: {damage_level}")
        
        response = supabase.table('van_profiles').update({
            'alerts': alert_flag,
            'updated_at': 'now()'
        }).eq('id', van_id).execute()
        
        if response.data:
            if alert_flag == 'yes':
                print(f"🚨 CRITICAL DAMAGE ALERT: Van #{van_number} flagged for level {damage_level}")
                logger.info(f"🚨 CRITICAL DAMAGE ALERT: Van #{van_number} flagged for level {damage_level}")
            return True
        return False
        
    except Exception as e:
        print(f"❌ Error updating van alerts: {e}")
        logger.error(f"❌ Error updating van alerts: {e}")
        return False
```

## Step 5: Find this line in your bot:
```python
logger.info(f"🎯 Claude analysis result: {claude_result}")
```

## Step 6: Add this code RIGHT AFTER that line:
```python
# Update van alerts based on damage level
if 'van_rating' in claude_result:
    damage_level = claude_result['van_rating']
    print(f"🎯 Damage level detected: {damage_level}")
    
    # Update alerts in database  
    alert_updated = update_van_alerts(van_id, damage_level, van_number)
    
    if alert_updated and damage_level >= 2:
        print(f"🚨 HIGH DAMAGE ALERT: Van {van_number} requires immediate attention!")
        logger.info(f"🚨 HIGH DAMAGE ALERT: Van {van_number} requires immediate attention!")
```

## Step 7: Save and restart
```bash
# Save file (Ctrl+X, Y, Enter)
sudo systemctl restart python3
# Check if running
ps aux | grep python3 | grep slack
```

## Step 8: Test
Upload an image with damage to Slack and check logs:
```bash
sudo journalctl -f | grep python3
```

You should see:
```
🎯 Damage level detected: 2
🚨 Updating alerts for van #215, damage level: 2
🚨 CRITICAL DAMAGE ALERT: Van #215 flagged for level 2
🚨 HIGH DAMAGE ALERT: Van 215 requires immediate attention!
``` 
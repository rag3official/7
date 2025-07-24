# 🤖 Claude AI Integration Setup Guide

## Overview
This guide explains how to integrate Claude AI with your van damage tracker system to automatically analyze uploaded images for:
- **Van Side Detection**: Front, rear, driver side, passenger side, interior, roof, undercarriage
- **Damage Assessment**: Type, severity, rating (0-3), and detailed description
- **Automated Storage**: All analysis results stored in database with base64 images

## 🔧 Prerequisites

### 1. Claude AI API Access
- Sign up at [Anthropic Console](https://console.anthropic.com/)
- Create an API key
- Note: Claude 3.5 Sonnet is recommended for best image analysis

### 2. Database Schema Update
Run the SQL script to add the van_side field:
```sql
-- Add van_side column to van_images table
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS van_side VARCHAR(20) DEFAULT 'unknown';

-- Add constraint for valid van side values
ALTER TABLE van_images ADD CONSTRAINT van_side_check 
CHECK (van_side IN ('front', 'rear', 'driver_side', 'passenger_side', 'interior', 'roof', 'undercarriage', 'unknown'));

-- Create index for faster filtering
CREATE INDEX IF NOT EXISTS idx_van_images_van_side ON van_images(van_side);
```

## 🚀 Bot Setup

### 1. Install Dependencies
```bash
pip install -r claude_bot_requirements.txt
```

### 2. Environment Variables
Copy `claude_bot_env_template.txt` to `.env` and fill in your values:
```env
# Slack Bot Configuration
SLACK_BOT_TOKEN=xoxb-your-bot-token-here
SLACK_APP_TOKEN=xapp-your-app-token-here

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-anon-key-here

# Claude AI Configuration
CLAUDE_API_KEY=sk-ant-your-claude-api-key-here
```

### 3. Run the Enhanced Bot
```bash
python enhanced_claude_slack_bot.py
```

## 📱 Flutter App Updates

### 1. Updated Models
The `VanImage` model now includes:
- `vanSide` field for Claude AI detected van side
- Enhanced damage information display

### 2. Enhanced UI Features
- **Van Side Indicators**: Color-coded badges showing which side of van
- **Damage Type Tags**: Visual indicators for damage classification
- **Severity Ratings**: Updated 0-3 scale with color coding
- **Enhanced Image Viewer**: Shows all Claude AI analysis in detail overlay

### 3. Updated Services
The `EnhancedDriverService` now fetches:
- Van side information
- Damage type and severity
- Claude AI confidence ratings

## 🧠 Claude AI Analysis Features

### Van Side Detection
- **Front**: Blue indicator with car icon
- **Rear**: Green indicator with filled car icon  
- **Driver Side**: Red indicator with left arrow
- **Passenger Side**: Orange indicator with right arrow
- **Interior**: Purple indicator with seat icon
- **Roof**: Teal indicator with up arrow
- **Undercarriage**: Brown indicator with down arrow

### Damage Assessment
- **Type**: scratch, dent, paint_damage, broken_part, wear, none
- **Severity**: none, minor, moderate, major
- **Rating**: 0-3 numerical scale
- **Description**: Detailed AI-generated description
- **Location**: Specific location on van side

### Confidence Tracking
- Each analysis includes confidence level (high, medium, low)
- Stored in `upload_source` field for tracking accuracy

## 🔄 Migration from Existing Bot

### 1. Stop Current Bot
```bash
sudo systemctl stop slack_bot
```

### 2. Backup Current Bot
```bash
cp /home/ubuntu/slack_bot/slack_supabase_bot.py /home/ubuntu/slack_bot/slack_supabase_bot_backup.py
```

### 3. Deploy Enhanced Bot
```bash
# Upload enhanced_claude_slack_bot.py to server
scp enhanced_claude_slack_bot.py ubuntu@your-server:/home/ubuntu/slack_bot/

# Update service file if needed
sudo systemctl edit slack_bot
```

### 4. Update Environment
```bash
# Add Claude API key to environment
echo "CLAUDE_API_KEY=sk-ant-your-key-here" >> /home/ubuntu/slack_bot/.env
```

### 5. Start Enhanced Bot
```bash
sudo systemctl start slack_bot
sudo systemctl status slack_bot
```

## 📊 Database Schema Reference

### Enhanced van_images Table
```sql
CREATE TABLE van_images (
  -- Existing fields...
  van_side VARCHAR(20) DEFAULT 'unknown',
  damage_type VARCHAR(50) DEFAULT 'unknown',
  damage_severity VARCHAR(20) DEFAULT 'minor',
  damage_location VARCHAR(100),
  van_damage TEXT, -- Claude AI description
  van_rating INTEGER CHECK (van_rating >= 0 AND van_rating <= 3),
  -- Constraints...
  CONSTRAINT van_side_check CHECK (
    van_side IN ('front', 'rear', 'driver_side', 'passenger_side', 'interior', 'roof', 'undercarriage', 'unknown')
  )
);
```

## 🧪 Testing the Integration

### 1. Upload Test Image
- Upload van image to Slack channel
- Mention van number (e.g., "van 123")
- Bot should respond with AI analysis

### 2. Check Database
```sql
SELECT van_side, damage_type, damage_severity, van_rating, van_damage 
FROM van_images 
WHERE upload_method = 'claude_ai_slack_bot' 
ORDER BY created_at DESC 
LIMIT 5;
```

### 3. Verify Flutter App
- Open van profile or driver profile
- Check for van side indicators
- Tap image to see enhanced details

## 🎯 Expected Results

### Slack Bot Response
```
🤖 AI Analysis Complete!

🚐 Van: #123
👤 Driver: John Doe
🚗 Van Side: DRIVER SIDE

⚠️ Damage Assessment:
• Type: SCRATCH
• Severity: MINOR
• Rating: 1/3
• Location: door panel
• Description: Minor scratch on driver side door panel

🎯 AI Confidence: HIGH
💾 Storage: Database (Base64 + AI Analysis)
```

### Flutter App Display
- Color-coded van side badges
- Damage type and severity indicators
- Enhanced image viewer with AI details
- Clickable navigation between profiles

## 🔍 Troubleshooting

### Common Issues

1. **Claude API Errors**
   - Check API key validity
   - Verify account has sufficient credits
   - Ensure image format is supported

2. **Database Errors**
   - Run van_side column migration
   - Check constraint violations
   - Verify foreign key relationships

3. **Image Display Issues**
   - Ensure base64 data is properly stored
   - Check content_type field
   - Verify Flutter base64 decoding

### Debugging Commands
```bash
# Check bot logs
sudo journalctl -u slack_bot -f

# Test database connection
python -c "from supabase import create_client; print('DB OK')"

# Test Claude API
python -c "import anthropic; print('Claude OK')"
```

## 🚀 Next Steps

1. **Deploy Enhanced Bot**: Replace existing bot with Claude AI version
2. **Run Database Migration**: Add van_side field and constraints
3. **Update Flutter App**: Deploy enhanced UI with van side display
4. **Monitor Performance**: Track Claude AI accuracy and costs
5. **Gather Feedback**: Collect user feedback on AI analysis quality

## 📈 Performance Metrics

### Tracking Recommendations
- Monitor Claude API usage and costs
- Track analysis accuracy vs manual verification
- Measure user satisfaction with AI descriptions
- Monitor bot response times with AI processing

### Cost Optimization
- Claude 3.5 Sonnet: ~$3 per 1000 images
- Consider image size optimization
- Implement caching for repeated analysis
- Monitor monthly API usage limits

---

🎉 **Your van damage tracker now has AI-powered image analysis!**

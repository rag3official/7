# Van Damage Tracker - Supabase Setup Instructions

## Overview
Complete setup guide for the Van Damage Tracking System with Slack bot integration on a fresh Supabase project.

## Prerequisites
- New Supabase project (Pro plan recommended for full functionality)
- Access to Supabase SQL Editor
- Basic understanding of SQL

## Setup Order (IMPORTANT: Run in this exact order)

### Step 1: Database Schema Setup
**File:** `01_create_database_schema.sql`

1. Go to Supabase Dashboard → SQL Editor
2. Create a new query
3. Copy and paste the entire contents of `01_create_database_schema.sql`
4. Run the query
5. Verify success by checking that 5 tables were created:
   - `vans`
   - `van_images` 
   - `driver_profiles`
   - `driver_van_assignments`
   - `storage_metadata`

**Expected Output:** Sample data should be inserted (5 vans, 4 driver profiles)

### Step 2: Storage Bucket Setup  
**File:** `02_create_storage_bucket.sql`

1. Create a new query in SQL Editor
2. Copy and paste the entire contents of `02_create_storage_bucket.sql`
3. Run the query
4. Verify the `van-images` bucket was created by:
   - Going to Storage → Buckets
   - Confirm `van-images` bucket exists with 50MB file size limit

**Expected Output:** Storage bucket with proper policies and helper functions

### Step 3: Database Functions
**File:** `03_create_functions.sql`

1. Create a new query in SQL Editor
2. Copy and paste the entire contents of `03_create_functions.sql`
3. Run the query
4. Verify functions were created by checking the test results at the bottom

**Expected Output:** 7 functions created including the critical `save_slack_image` function

### Step 4: Database Views
**File:** `04_create_views.sql`

1. Create a new query in SQL Editor
2. Copy and paste the entire contents of `04_create_views.sql`
3. Run the query
4. Verify views were created by checking the verification queries

**Expected Output:** 6 views created for data analysis and reporting

## Verification Steps

### 1. Test Main Function
Run this query to test the Slack bot function:
```sql
SELECT public.save_slack_image(
    'TEST999',
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    'setup_test'
);
```
**Expected:** Should return JSON with `"success": true`

### 2. Verify Tables
```sql
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('vans', 'van_images', 'driver_profiles', 'driver_van_assignments', 'storage_metadata')
ORDER BY table_name;
```
**Expected:** 5 rows returned

### 3. Verify Functions
```sql
SELECT routinename, routinetype 
FROM information_schema.routines 
WHERE routineschema = 'public' 
AND routinename LIKE '%van%' OR routinename LIKE '%slack%'
ORDER BY routinename;
```
**Expected:** Multiple functions including `save_slack_image`

### 4. Test Dashboard Stats
```sql
SELECT public.get_dashboard_stats();
```
**Expected:** JSON with van and image counts

### 5. Verify Storage
```sql
SELECT public.get_storage_bucket_info();
```
**Expected:** JSON showing bucket exists with policies

## Environment Configuration

### Get Your Supabase Credentials
After setup, collect these values from your Supabase Dashboard:

1. **Project URL:** `https://your-project-id.supabase.co`
2. **API Key (anon/public):** From Settings → API
3. **Service Role Key:** From Settings → API (for server-side operations)
4. **Database URL:** From Settings → Database (for direct connections)

### For Slack Bot Integration
Create a `.env` file with:
```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_KEY=your-anon-key-here
SUPABASE_SERVICE_KEY=your-service-role-key-here
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
SLACK_SIGNING_SECRET=your-slack-signing-secret
```

## Troubleshooting

### Common Issues

**Issue:** Tables not created
- **Solution:** Ensure you're in the correct project
- Check the SQL Editor for error messages
- Verify you have sufficient permissions

**Issue:** Storage bucket creation fails  
- **Solution:** Check if you're on the Pro plan (free plan has limitations)
- Ensure storage is enabled in your project

**Issue:** Functions fail to create
- **Solution:** Run the schema setup first (functions depend on tables)
- Check for any syntax errors in the SQL

**Issue:** RLS policies too restrictive
- **Solution:** The setup uses permissive policies for development
- Tighten security in production as needed

### Connection Issues (Free Plan)

If you encounter IPv4/IPv6 connectivity issues on the free plan:

1. Use the **Transaction Pooler** connection string instead of direct connection
2. Find it in: Settings → Database → Connection pooling
3. Format: `aws-0-us-west-1.pooler.supabase.com:6543`

## Security Notes

### Development vs Production

The setup scripts use **permissive RLS policies** for development:
```sql
CREATE POLICY "Allow all access" ON table_name FOR ALL USING (true);
```

**For Production:**
- Replace with restrictive policies based on `auth.uid()`
- Implement proper user authentication
- Review and restrict function permissions
- Use service role key only on secure backend services

### API Keys Security
- Never commit API keys to version control
- Use environment variables
- Rotate keys periodically
- Use service role key only for server-side operations

## Next Steps

After setup completion:

1. **Test the Slack bot** with your new credentials
2. **Import existing data** if migrating from another system
3. **Set up proper authentication** for production use
4. **Configure monitoring and alerts**
5. **Implement backup procedures**

## Support

If you encounter issues:
1. Check the Supabase logs in Dashboard → Logs
2. Review the verification queries results
3. Ensure all scripts ran without errors
4. Test individual functions with sample data

## File Summary

- `01_create_database_schema.sql` - Core tables, indexes, sample data
- `02_create_storage_bucket.sql` - Storage bucket with policies
- `03_create_functions.sql` - All database functions including Slack integration
- `04_create_views.sql` - Analytical views for reporting
- `05_setup_instructions.md` - This guide

**Total Setup Time:** ~10-15 minutes for a clean run 
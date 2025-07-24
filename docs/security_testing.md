# Security Testing Guide

## Storage Security Tests

### File Upload Validation
1. **File Type Tests**
   - ✅ Upload valid JPEG file
   - ✅ Upload valid PNG file
   - ✅ Upload valid WebP file
   - ❌ Upload invalid file type (e.g., PDF)
   - ❌ Upload file without extension
   - ❌ Upload file with modified extension

2. **File Size Tests**
   - ✅ Upload file under 10MB limit
   - ❌ Upload file over 10MB limit
   - ✅ Upload multiple files under limit
   - ❌ Upload multiple files totaling over limit

3. **Path Validation Tests**
   - ✅ Upload to valid van folder (van_123)
   - ❌ Upload to invalid folder name
   - ❌ Upload to nested folders
   - ❌ Upload to root folder

### Rate Limiting Tests
1. **Upload Rate Tests**
   - ✅ Upload 1-10 files within 1 minute
   - ❌ Upload 11+ files within 1 minute
   - ✅ Upload after rate limit window reset
   - ✅ Multiple users uploading simultaneously

2. **Rate Reset Tests**
   - ✅ Verify counter reset after 1 minute
   - ✅ Verify independent counters per user
   - ✅ Test counter persistence across sessions

## Access Control Tests

### User Access Tests
1. **Van Assignment Tests**
   - ✅ Upload to assigned van
   - ❌ Upload to unassigned van
   - ✅ View assigned van images
   - ❌ View unassigned van images
   - ✅ Delete own uploads
   - ❌ Delete others' uploads

2. **Admin Access Tests**
   - ✅ Upload to any van
   - ✅ View all van images
   - ✅ Delete any image
   - ✅ Bypass rate limits
   - ✅ Access audit logs

### RLS Policy Tests
1. **Driver Van Assignment Policy**
   - ✅ Verify assignment check in upload policy
   - ✅ Verify assignment check in read policy
   - ✅ Verify assignment check in delete policy

2. **Admin Policy**
   - ✅ Verify admin override in all policies
   - ✅ Test admin function effectiveness
   - ✅ Verify admin access persistence

## Monitoring and Audit

### Audit Log Tests
1. **Upload Tracking**
   - ✅ Log creation on upload
   - ✅ Capture upload metadata
   - ✅ Track upload user
   - ✅ Record upload timestamp

2. **Access Tracking**
   - ✅ Log file access events
   - ✅ Track access patterns
   - ✅ Monitor failed attempts
   - ✅ Record IP and user agent

## Test Execution Steps

1. **Setup Test Environment**
   ```sql
   -- Create test users
   INSERT INTO auth.users (email) VALUES ('test_user@example.com');
   INSERT INTO auth.users (email) VALUES ('test_admin@example.com');
   
   -- Create test van
   INSERT INTO vans (van_number) VALUES ('999');
   
   -- Create test assignment
   INSERT INTO driver_van_assignments (driver_id, van_id) 
   SELECT u.id, v.id 
   FROM auth.users u, vans v 
   WHERE u.email = 'test_user@example.com' 
   AND v.van_number = '999';
   ```

2. **Run Upload Tests**
   ```typescript
   // Test valid upload
   const { data, error } = await supabase.storage
     .from('van_images')
     .upload('van_999/test.jpg', file);
   
   // Test invalid upload
   const { data, error } = await supabase.storage
     .from('van_images')
     .upload('van_999/test.pdf', file);
   ```

3. **Run Access Tests**
   ```typescript
   // Test read access
   const { data, error } = await supabase.storage
     .from('van_images')
     .list('van_999');
   
   // Test delete access
   const { data, error } = await supabase.storage
     .from('van_images')
     .remove(['van_999/test.jpg']);
   ```

## Common Issues and Solutions

1. **Rate Limit Exceeded**
   - Wait for 1-minute window to reset
   - Check upload_rate_limits table for current count
   - Verify last_reset timestamp

2. **Access Denied**
   - Verify van assignment
   - Check admin status
   - Validate file path format

3. **Invalid File Type**
   - Ensure correct file extension
   - Verify actual file type matches extension
   - Check allowed file types list

## Security Best Practices

1. **File Upload**
   - Always validate file type server-side
   - Implement virus scanning
   - Use signed URLs for uploads
   - Enforce strict naming conventions

2. **Access Control**
   - Regular audit of admin users
   - Review van assignments
   - Monitor access patterns
   - Regular security review

3. **Rate Limiting**
   - Adjust limits based on usage patterns
   - Monitor for abuse
   - Implement IP-based limiting
   - Add request throttling

## Monitoring Setup

1. **Log Analysis**
   ```sql
   -- Check upload patterns
   SELECT 
     date_trunc('hour', upload_timestamp) as hour,
     count(*) as upload_count
   FROM van_images
   GROUP BY 1
   ORDER BY 1 DESC;
   
   -- Check access patterns
   SELECT 
     user_id,
     count(*) as access_count
   FROM data_access_logs
   WHERE accessed_at > now() - interval '24 hours'
   GROUP BY user_id
   ORDER BY access_count DESC;
   ```

2. **Alert Setup**
   - Configure alerts for high upload rates
   - Monitor failed access attempts
   - Track unusual access patterns
   - Alert on policy violations 
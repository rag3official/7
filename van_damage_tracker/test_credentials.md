# Test Credentials for Van Damage Tracker

## Setup Required

1. **First, create the auth users in Supabase Dashboard:**
   - Go to Authentication > Users in your Supabase project
   - Click "Add user" and create these users:

## Test Accounts

### Admin Account (Full Access)
- **Email**: `testadmin@vantracker.com`
- **Password**: `AdminPass123!`
- **Role**: Admin
- **Can**: Add/remove vans, manage drivers, view all statistics

### Crew Account (Maintenance Access)  
- **Email**: `testcrew@vantracker.com`
- **Password**: `CrewPass123!`
- **Role**: Crew
- **Can**: Change van status, add maintenance notes

### Viewer Account (Read-Only)
- **Email**: `testviewer@vantracker.com` 
- **Password**: `ViewerPass123!`
- **Role**: Viewer
- **Can**: View vans and drivers only

## Quick Test

Use the **Admin Account** for full testing:
- Email: `testadmin@vantracker.com`
- Password: `AdminPass123!`

## If You Get "Invalid Credentials" Error

1. **Check if you created the auth users** in Supabase Dashboard
2. **Run the SQL script** `13_corrected_mock_users.sql` to create profiles
3. **Double-check the email/password** (case sensitive)
4. **Make sure your Supabase environment variables** are set correctly in `.env`

## Alternative: Create Your Own Test User

If the above doesn't work, create your own user:
1. Click "Create Account" in the app
2. Use any email/password you want
3. The app will create a "viewer" role by default
4. Manually change the role to "admin" in Supabase if needed 
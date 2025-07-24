# Van Damage Tracker - Database Setup Guide

This guide will help you set up the Supabase database for the Van Damage Tracker application.

## Overview

The application uses three main database migrations to set up the required tables and relationships:

1. **van_images table** - Stores van photos with metadata
2. **drivers table** - Manages driver information  
3. **Security policies** - Row Level Security for data protection

## Step-by-Step Setup

### 1. Access Supabase SQL Editor

1. Go to your Supabase project dashboard
2. Navigate to "SQL Editor" in the left sidebar
3. Click "New Query" to create a new SQL script

### 2. Run Migration 1: Create Van Images Table

Copy and paste the content from `migrations/01_create_van_images_table.sql`:

```sql
-- This creates the van_images table with proper structure
-- Including indexes for performance and sample data for testing
```

**What this migration does:**
- Creates `van_images` table with all required columns
- Sets up indexes for better query performance
- Creates automatic timestamp updating triggers
- Inserts sample images linked to existing vans

### 3. Run Migration 2: Create Drivers Table

Copy and paste the content from `migrations/02_create_drivers_table.sql`:

```sql
-- This creates the drivers table and updates relationships
-- Links drivers to existing vans and images
```

**What this migration does:**
- Creates `drivers` table with employee information
- Adds `driver_id` foreign key to `van_images` table
- Adds `current_driver_id` to `vans` table
- Inserts sample drivers (John Smith, Sarah Johnson, etc.)
- Links existing data based on driver names

### 4. Run Migration 3: Add Security Policies

Copy and paste the content from `migrations/03_add_security_policies.sql`:

```sql
-- This sets up Row Level Security for data protection
-- Creates a view for easy querying with driver information
```

**What this migration does:**
- Enables Row Level Security (RLS) on new tables
- Creates read/write policies for authenticated users
- Creates `van_images_with_driver` view for joined queries
- Grants proper permissions

## Database Schema

### Tables Structure

#### `van_images`
```sql
- id (UUID, Primary Key)
- van_id (UUID, Foreign Key to vans.id)
- image_url (TEXT, Required)
- uploaded_by (TEXT, Driver name for compatibility)
- driver_id (UUID, Foreign Key to drivers.id)
- uploaded_at (TIMESTAMP, Required)
- description (TEXT, Optional)
- damage_type (TEXT, Optional)
- damage_level (INTEGER, 0-5 scale)
- location (TEXT, e.g., 'front', 'rear', 'left', 'right', 'interior')
- created_at (TIMESTAMP, Auto)
- updated_at (TIMESTAMP, Auto)
```

#### `drivers`
```sql
- id (UUID, Primary Key)
- name (TEXT, Required)
- employee_id (TEXT, Unique)
- phone (TEXT, Optional)
- email (TEXT, Optional)
- license_number (TEXT, Optional)
- license_expiry_date (DATE, Optional)
- status (TEXT, Default 'active')
- created_at (TIMESTAMP, Auto)
- updated_at (TIMESTAMP, Auto)
```

#### `vans` (Updated)
```sql
- current_driver_id (UUID, Foreign Key to drivers.id) [NEW COLUMN]
- ... existing columns ...
```

### Views

#### `van_images_with_driver`
A view that joins van_images with drivers table to provide complete information in a single query.

## Sample Data

The migrations include sample data:

### Sample Drivers
- John Smith (EMP001)
- Sarah Johnson (EMP002)  
- Mike Davis (EMP003)
- Alex Wilson (EMP004)
- Emma Brown (EMP005)

### Sample Images
- 6 sample images with various damage levels and locations
- Linked to different drivers and vans
- Different upload times for testing time-based grouping

## App Configuration

### Environment Variables
Make sure your `.env` file contains:
```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### App Features Enabled
After running these migrations, the app will have:

✅ **Real Database Integration**
- Fetches van images from `van_images_with_driver` view
- Shows driver information with employee IDs
- Displays accurate upload times and dates

✅ **Enhanced Driver Display**
- Driver names with employee IDs: "John Smith (EMP001)"
- Driver contact information in image details
- Proper fallback to mock data on macOS

✅ **Improved Image Grouping**
- Groups by upload date and driver
- Sorts by most recent uploads first
- Shows damage levels and image counts

✅ **Error Handling**
- Graceful fallback to mock data if database unavailable
- Network permission handling for macOS

## Testing

### Chrome (Recommended)
```bash
cd van_damage_tracker
flutter run -d chrome
```
This should connect to Supabase and show real data.

### macOS (Limited)
```bash
cd van_damage_tracker  
flutter run -d macos
```
This will show mock data due to network restrictions but tests the UI.

## Troubleshooting

### Common Issues

1. **Column doesn't exist errors**
   - Make sure all migrations ran successfully
   - Check if tables were created properly

2. **No images showing**
   - Verify van_images table has data
   - Check that van IDs match between vans and van_images tables

3. **Driver information missing**
   - Ensure drivers table was created
   - Verify the van_images_with_driver view exists

4. **Network errors on macOS**
   - Use Chrome for testing: `flutter run -d chrome`
   - This is expected due to macOS sandboxing

### SQL Verification Queries

```sql
-- Check if tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('van_images', 'drivers');

-- Check sample data
SELECT COUNT(*) FROM van_images;
SELECT COUNT(*) FROM drivers;

-- Test the view
SELECT * FROM van_images_with_driver LIMIT 5;
```

## Next Steps

After successful setup:
1. Test the app in Chrome browser
2. Verify van detail screens show real images
3. Check that driver information displays correctly
4. Test image detail popups with contact information

The app will now pull real data from your Supabase database and display accurate van profiles with corresponding images, drivers, and upload information! 
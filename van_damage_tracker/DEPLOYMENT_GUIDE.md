# Van Damage Tracker - Deployment Guide

This guide provides step-by-step instructions for deploying the Van Damage Tracker application with Supabase backend.

## 📋 Prerequisites

- Supabase account and project
- Flutter development environment
- macOS for desktop app deployment

## 🗄️ Database Setup

### Version 1: Basic Van Profiles Table (Working Schema)

Run this SQL in your Supabase Dashboard -> SQL Editor:

```sql
-- Create basic van_profiles table with status management
create table public.van_profiles (
  id uuid not null default gen_random_uuid (),
  van_number integer not null,
  make text null,
  model text null,
  year integer null,
  license_plate text null,
  vin text null,
  status text null default 'active'::text,
  current_driver_id uuid null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint van_profiles_pkey primary key (id),
  constraint van_profiles_van_number_key unique (van_number),
  constraint van_profiles_current_driver_id_fkey foreign KEY (current_driver_id) references driver_profiles (id),
  constraint van_profiles_status_check check (
    (
      status = any (
        array[
          'active'::text,
          'maintenance'::text,
          'retired'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

-- Create index for efficient van number lookups
create index IF not exists idx_van_profiles_van_number on public.van_profiles using btree (van_number) TABLESPACE pg_default;
```

### Version 2: Enhanced Status Management (Optional)

If you want full status management with audit logging, run the enhanced setup:

```sql
-- ENHANCED Van Status Management Setup
-- Run this AFTER Version 1 if you want audit logging and triggers

BEGIN;

-- =============================================================================
-- 1. UPDATE STATUS CONSTRAINTS TO MATCH FLUTTER APP
-- =============================================================================

-- Update status constraint to include 'out_of_service' instead of 'retired'
ALTER TABLE van_profiles DROP CONSTRAINT IF EXISTS van_profiles_status_check;
ALTER TABLE van_profiles ADD CONSTRAINT van_profiles_status_check 
    CHECK (status IN ('active', 'maintenance', 'out_of_service'));

-- Add notes column for status change reasons
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'van_profiles' AND column_name = 'notes'
    ) THEN
        ALTER TABLE van_profiles ADD COLUMN notes TEXT;
    END IF;
END $$;

-- =============================================================================
-- 2. CREATE STATUS CHANGE AUDIT LOG TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS van_status_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id UUID REFERENCES van_profiles(id) ON DELETE CASCADE,
    van_number INTEGER NOT NULL,
    old_status TEXT,
    new_status TEXT NOT NULL CHECK (new_status IN ('active', 'maintenance', 'out_of_service')),
    reason TEXT,
    notes TEXT,
    changed_by TEXT DEFAULT 'flutter_app',
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_van_status_log_van_id ON van_status_log(van_id);
CREATE INDEX IF NOT EXISTS idx_van_status_log_van_number ON van_status_log(van_number);
CREATE INDEX IF NOT EXISTS idx_van_status_log_changed_at ON van_status_log(changed_at DESC);

-- =============================================================================
-- 3. CREATE TRIGGER FUNCTIONS
-- =============================================================================

-- Function to log status changes
CREATE OR REPLACE FUNCTION log_van_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Only log if status actually changed
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO van_status_log (
            van_id,
            van_number,
            old_status,
            new_status,
            reason,
            notes,
            changed_by
        ) VALUES (
            NEW.id,
            NEW.van_number,
            OLD.status,
            NEW.status,
            'Status change via app',
            NEW.notes,
            'flutter_app'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_van_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 4. CREATE TRIGGERS
-- =============================================================================

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS van_status_change_trigger ON van_profiles;
DROP TRIGGER IF EXISTS update_van_profiles_updated_at_trigger ON van_profiles;

-- Create status change logging trigger
CREATE TRIGGER van_status_change_trigger
    AFTER UPDATE ON van_profiles
    FOR EACH ROW
    EXECUTE FUNCTION log_van_status_change();

-- Create updated_at timestamp trigger
CREATE TRIGGER update_van_profiles_updated_at_trigger
    BEFORE UPDATE ON van_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_van_profiles_updated_at();

-- =============================================================================
-- 5. CREATE HELPFUL VIEWS
-- =============================================================================

-- View for current van status summary
CREATE OR REPLACE VIEW van_status_summary AS
SELECT 
    status,
    COUNT(*) as van_count,
    ARRAY_AGG(van_number ORDER BY van_number) as van_numbers
FROM van_profiles 
GROUP BY status
ORDER BY 
    CASE status 
        WHEN 'active' THEN 1 
        WHEN 'maintenance' THEN 2 
        WHEN 'out_of_service' THEN 3 
        ELSE 4 
    END;

-- View for recent status changes
CREATE OR REPLACE VIEW recent_status_changes AS
SELECT 
    vsl.van_number,
    vp.make,
    vp.model,
    vsl.old_status,
    vsl.new_status,
    vsl.reason,
    vsl.notes,
    vsl.changed_at
FROM van_status_log vsl
JOIN van_profiles vp ON vsl.van_id = vp.id
ORDER BY vsl.changed_at DESC
LIMIT 50;

-- =============================================================================
-- 6. ENABLE ROW LEVEL SECURITY AND PERMISSIONS
-- =============================================================================

-- Enable RLS for audit table
ALTER TABLE van_status_log ENABLE ROW LEVEL SECURITY;

-- Create policies for van_status_log
DROP POLICY IF EXISTS "Enable all for authenticated users" ON van_status_log;
CREATE POLICY "Enable all for authenticated users" ON van_status_log
    FOR ALL USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

-- Grant permissions
GRANT ALL ON van_status_log TO authenticated;
GRANT ALL ON van_status_summary TO authenticated;
GRANT ALL ON recent_status_changes TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =============================================================================
-- 7. NORMALIZE EXISTING DATA
-- =============================================================================

-- Update any 'retired' status to 'out_of_service' to match Flutter app
UPDATE van_profiles 
SET status = 'out_of_service'
WHERE status = 'retired';

COMMIT;
```

## 🔧 Flutter App Configuration

### 1. Environment Setup

Create or update `lib/config/environment.dart`:

```dart
class Environment {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

### 2. Dependencies

Ensure your `pubspec.yaml` includes:

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0
  # Add other dependencies as needed
```

### 3. Main App Setup

Your `lib/main.dart` should initialize Supabase:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: Environment.supabaseUrl,
    anonKey: Environment.supabaseAnonKey,
  );
  
  runApp(MyApp());
}
```

## 🚀 Deployment Steps

### 1. Database Deployment
1. Log into your Supabase Dashboard
2. Navigate to SQL Editor
3. Run the Version 1 SQL schema first
4. Optionally run Version 2 for enhanced status management
5. Verify tables are created successfully

### 2. Flutter App Deployment

#### For macOS:
```bash
# Navigate to your project directory
cd van_damage_tracker

# Get dependencies
flutter pub get

# Run the app
flutter run -d macos
```

#### For Production Build:
```bash
# Build for macOS
flutter build macos

# The built app will be in build/macos/Build/Products/Release/
```

## 🧪 Testing the Setup

### 1. Database Verification

Run these queries in Supabase SQL Editor to verify setup:

```sql
-- Check van_profiles table structure
\d van_profiles;

-- Check status constraint
SELECT constraint_name, check_clause 
FROM information_schema.check_constraints 
WHERE constraint_name = 'van_profiles_status_check';

-- Test status summary view (if Version 2 was installed)
SELECT * FROM van_status_summary;
```

### 2. Flutter App Testing

1. **Launch the app** and verify it connects to Supabase
2. **Create a test van** with van number and status
3. **Change van status** and verify it updates in database
4. **Check damage rating badges** display correctly (L0, L1, L2, L3)

### 3. Status Management Testing

If you installed Version 2 (Enhanced), test:

1. **Status changes are logged** in `van_status_log` table
2. **Timestamps update** automatically via triggers
3. **Views return data** correctly

## 🔍 Troubleshooting

### Common Issues:

1. **SQL Syntax Errors:**
   - Ensure you run Version 1 first before Version 2
   - Check that `driver_profiles` table exists before creating foreign keys

2. **Flutter Connection Issues:**
   - Verify Supabase URL and keys in environment config
   - Check network connectivity and API access

3. **Status Constraint Violations:**
   - Ensure status values match exactly: 'active', 'maintenance', 'out_of_service'
   - Update any existing invalid status values

4. **Missing main.dart Error:**
   - Ensure you're in the correct project directory
   - Check that `lib/main.dart` exists and is properly configured

### Verification Commands:

```sql
-- Check all van statuses
SELECT van_number, status FROM van_profiles ORDER BY van_number;

-- Check recent status changes (Version 2 only)
SELECT * FROM recent_status_changes LIMIT 10;

-- Verify trigger is working (Version 2 only)
UPDATE van_profiles SET status = 'maintenance' WHERE van_number = 123;
SELECT * FROM van_status_log WHERE van_number = 123;
```

## 📝 Next Steps

After successful deployment:

1. **Add sample data** for testing
2. **Configure user authentication** if needed
3. **Set up production monitoring**
4. **Plan regular database backups**
5. **Document any custom business rules**

## 🛠️ Maintenance

### Regular Tasks:
- Monitor van status change logs
- Clean up old audit logs if needed
- Update Flutter dependencies
- Review and optimize database queries

### Schema Updates:
- Always test schema changes in development first
- Use migrations for production updates
- Keep backups before major changes

---

**✅ Deployment Complete!**

Your Van Damage Tracker should now be fully operational with proper status management, damage rating badges, and real-time updates between the Flutter app and Supabase database. 
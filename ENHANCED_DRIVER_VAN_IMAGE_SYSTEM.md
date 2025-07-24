# Enhanced Driver-Van Image Linking System

## Overview

This enhanced system creates proper relationships between driver profiles, van profiles, and van images, enabling seamless navigation between driver and van profiles through uploaded images.

## Database Schema Enhancements

### 1. Updated `driver_profiles` Table
Your current table structure is perfect:
```sql
create table public.driver_profiles (
  id uuid not null default gen_random_uuid (),
  slack_user_id text not null,
  driver_name text not null,
  email text null,
  phone text null,
  license_number text null,
  hire_date date null,
  status text null default 'active'::text,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  slack_real_name text null,
  slack_display_name text null,
  slack_username text null,
  total_uploads integer null default 0,
  last_upload_date timestamp with time zone null,
  constraint driver_profiles_pkey primary key (id),
  constraint driver_profiles_slack_user_id_key unique (slack_user_id)
);
```

### 2. New `van_profiles` Table
```sql
CREATE TABLE public.van_profiles (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    van_number int UNIQUE NOT NULL,
    make text DEFAULT 'Unknown',
    model text DEFAULT 'Unknown',
    year int,
    license_plate text,
    vin text,
    status text DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'retired')),
    current_driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE SET NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);
```

### 3. Enhanced `van_images` Table
Added columns to link images to drivers:
- `driver_id` - Links to driver_profiles table
- `slack_user_id` - Links to Slack user who uploaded
- `image_data` - Base64 encoded image data (for storage bypass)
- `uploaded_by` - Driver name attribution
- `file_path`, `file_size`, `content_type` - File metadata
- Made `van_number` nullable to fix Slack bot constraint violations

## Key Features

### 1. Driver Profile Navigation
- **View all images uploaded by a driver**
- **Group images by van** for easy organization
- **Navigate directly to van profiles** from driver's uploaded images
- **Display upload statistics** (total uploads, vans photographed, recent activity)

### 2. Van Profile Navigation
- **View all images for a specific van**
- **See which drivers uploaded each image**
- **Navigate to driver profiles** from van images
- **Track van history through driver uploads**

### 3. Automatic Linking
- **Images automatically linked to drivers** based on Slack user ID
- **Upload statistics automatically updated** when images are added/removed
- **Real-time attribution** using driver's actual name instead of 'slack_bot'

## Database Views

### `driver_profile_summary`
Complete driver information with upload statistics:
```sql
SELECT 
    dp.driver_name,
    dp.total_uploads,
    dp.last_upload_date,
    stats.total_images_uploaded,
    stats.vans_photographed,
    stats.uploads_last_30_days,
    stats.avg_damage_rating
FROM driver_profiles dp
LEFT JOIN (upload statistics) stats ON dp.id = stats.driver_id;
```

### `driver_images_with_van_details`
Driver's images with van information for navigation:
```sql
SELECT 
    vi.image_id,
    vi.van_number,
    vi.damage_description,
    dp.driver_name,
    vp.make as van_make,
    vp.model as van_model,
    CONCAT(vp.make, ' ', vp.model, ' (#', vi.van_number, ')') as van_display_name
FROM van_images vi
JOIN driver_profiles dp ON vi.driver_id = dp.id
LEFT JOIN van_profiles vp ON vi.van_id = vp.id;
```

### `van_images_with_driver_details`
Van's images with driver attribution:
```sql
SELECT 
    vi.image_id,
    vi.van_number,
    vi.damage_description,
    dp.driver_name,
    dp.phone as driver_phone,
    vp.make as van_make
FROM van_images vi
LEFT JOIN driver_profiles dp ON vi.driver_id = dp.id
LEFT JOIN van_profiles vp ON vi.van_id = vp.id;
```

## Database Functions

### `get_driver_images_by_van(driver_id, limit_per_van)`
Returns driver's images grouped by van:
```sql
SELECT public.get_driver_images_by_van('driver-uuid', 10);
```

Returns:
```json
[
  {
    "van_id": "uuid",
    "van_number": 99,
    "van_make": "Ford",
    "van_model": "Transit",
    "van_display_name": "Ford Transit (#99)",
    "image_count": 5,
    "latest_upload": "2025-01-18T17:21:15Z",
    "images": [
      {
        "id": "image-uuid",
        "image_url": "https://...",
        "damage_description": "Minor scratch",
        "damage_rating": 2,
        "uploaded_at": "2025-01-18T17:21:15Z"
      }
    ]
  }
]
```

### `link_images_to_drivers()`
Links existing images to driver profiles:
```sql
SELECT public.link_images_to_drivers(); -- Returns count of linked images
```

## Flutter Integration

### Enhanced Driver Service
```dart
class EnhancedDriverService {
  // Get driver profile with statistics
  static Future<Map<String, dynamic>?> getDriverProfile(String driverId) async {
    return await _supabase
        .from('driver_profile_summary')
        .select()
        .eq('driver_id', driverId)
        .single();
  }

  // Get driver's images grouped by van
  static Future<List<Map<String, dynamic>>> getDriverImagesByVan(String driverId) async {
    return await _supabase.rpc('get_driver_images_by_van', params: {
      'p_driver_id': driverId,
      'p_limit_per_van': 10
    });
  }

  // Navigate to van profile from driver page
  static Future<Map<String, dynamic>?> navigateToVanProfile(int vanNumber) async {
    final vanProfile = await _supabase
        .from('van_profiles')
        .select()
        .eq('van_number', vanNumber)
        .single();

    final images = await _supabase
        .from('van_images_with_driver_details')
        .select()
        .eq('van_number', vanNumber)
        .order('uploaded_at', ascending: false);

    return {
      'van_profile': vanProfile,
      'images': images,
      'image_count': images.length,
    };
  }
}
```

### Driver Profile Page Implementation
```dart
class DriverProfilePage extends StatelessWidget {
  final String driverId;

  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        EnhancedDriverService.getDriverProfile(driverId),
        EnhancedDriverService.getDriverImagesByVan(driverId),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final profile = snapshot.data![0];
        final imagesByVan = snapshot.data![1];
        
        return Scaffold(
          appBar: AppBar(title: Text(profile['driver_name'])),
          body: Column(
            children: [
              // Driver statistics
              DriverStatsCard(
                totalUploads: profile['total_images_uploaded'],
                vansPhotographed: profile['vans_photographed'],
                recentUploads: profile['uploads_last_30_days'],
              ),
              
              // Images grouped by van
              Expanded(
                child: ListView.builder(
                  itemCount: imagesByVan.length,
                  itemBuilder: (context, index) {
                    final vanGroup = imagesByVan[index];
                    return VanImageGroupCard(
                      vanDisplayName: vanGroup['van_display_name'],
                      imageCount: vanGroup['image_count'],
                      images: vanGroup['images'],
                      onVanTap: () {
                        // Navigate to van profile
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => VanProfilePage(
                            vanNumber: vanGroup['van_number']
                          )
                        ));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

## SQL Setup Script

Run this script in your Supabase Dashboard to set up the enhanced system:

```sql
-- Run the DRIVER_VAN_IMAGE_ENHANCEMENT.sql script
-- This will:
-- 1. Create van_profiles table
-- 2. Add missing columns to van_images
-- 3. Create navigation views
-- 4. Create helper functions
-- 5. Link existing images to drivers
-- 6. Set up proper permissions
```

## Benefits

1. **Seamless Navigation**: Click on any van from a driver's profile to go directly to that van's profile
2. **Proper Attribution**: Images show actual driver names instead of 'slack_bot'
3. **Upload Statistics**: Track driver activity and engagement
4. **Organized Display**: Images grouped by van for better organization
5. **Bi-directional Linking**: Navigate from driver→van and van→driver
6. **Automatic Updates**: Statistics and links update automatically
7. **Slack Bot Compatibility**: Fixes constraint violations while maintaining functionality

## Usage Examples

### Driver Profile Page
- Shows driver's upload statistics
- Groups images by van
- Click any van group to navigate to van profile
- See driver's activity over time

### Van Profile Page  
- Shows all images for the van
- Displays which driver uploaded each image
- Click driver name to navigate to driver profile
- Track van's history through driver uploads

### Admin Functions
- Link existing images to drivers with one function call
- View system-wide statistics
- Manage driver and van profiles

This enhanced system provides a complete solution for navigating between driver profiles and van profiles through the images they upload, creating a cohesive and intuitive user experience. 
# Enhanced Driver Profile System: Complete Image Tracking & Navigation

## Overview
This document outlines the enhanced driver profile system that links Slack users to their uploaded van images, allowing comprehensive tracking and navigation between driver profiles and van profiles.

## System Architecture

### 1. Driver Profile Creation from Slack
When a user uploads an image via Slack, the system:

```python
def get_or_create_driver_profile(slack_user_id, client):
    """Enhanced driver profile creation using Slack display names"""
    try:
        # Check if driver profile exists
        response = supabase.table("driver_profiles").select("*").eq("slack_user_id", slack_user_id).execute()
        
        if response.data:
            return response.data[0]
        
        # Get user info from Slack API
        user_info = client.users_info(user=slack_user_id)
        user = user_info.get("user", {})
        profile = user.get("profile", {})
        
        # Priority order for driver name:
        # 1. real_name (John Smith)
        # 2. display_name (John S.)  
        # 3. name (john.smith)
        # 4. fallback (Driver_U08HRF3TM24)
        driver_name = (
            profile.get("real_name") or 
            profile.get("display_name") or 
            user.get("name") or 
            f"Driver_{slack_user_id}"
        )
        
        # Create comprehensive driver profile
        driver_data = {
            "slack_user_id": slack_user_id,
            "driver_name": driver_name,
            "email": profile.get("email"),
            "phone": profile.get("phone"), 
            "status": "active",
            "slack_display_name": profile.get("display_name"),
            "slack_real_name": profile.get("real_name"),
            "slack_username": user.get("name"),
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        
        response = supabase.table("driver_profiles").insert(driver_data).execute()
        logger.info(f"✅ Created driver profile: {driver_name}")
        return response.data[0]
        
    except Exception as e:
        logger.error(f"❌ Error creating driver profile: {e}")
        return None
```

### 2. Image Upload Linking
When an image is uploaded, it's linked to both driver and van:

```python
def store_image_with_driver_link(van_profile, driver_profile, image_data, damage_info):
    """Store image with proper driver and van relationships"""
    
    image_record = {
        "van_id": van_profile["id"],
        "van_number": van_profile["van_number"],
        "driver_id": driver_profile["id"],
        "slack_user_id": driver_profile["slack_user_id"],
        
        # Image data (base64 for storage bypass)
        "image_data": image_data["base64"],
        "image_url": f"data:{image_data['content_type']};base64,{image_data['base64']}",
        "file_size": image_data["size"],
        "content_type": image_data["content_type"],
        
        # Damage assessment
        "van_damage": damage_info.get("description", "No damage description"),
        "van_rating": damage_info.get("rating", 0),
        "damage_type": damage_info.get("type", "general"),
        "damage_level": damage_info.get("rating", 0),
        "location": damage_info.get("location", "exterior"),
        
        # Attribution (use driver's actual name, not 'slack_bot')
        "uploaded_by": driver_profile["driver_name"],
        "driver_name": driver_profile["driver_name"],
        "description": damage_info.get("description", ""),
        
        # Metadata
        "upload_method": "slack_bot",
        "slack_channel_id": channel_id,
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat(),
        "uploaded_at": datetime.now().isoformat()
    }
    
    return supabase.table("van_images").insert(image_record).execute()
```

## Database Schema Enhancements

### Enhanced `driver_profiles` Table
```sql
CREATE TABLE driver_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slack_user_id TEXT UNIQUE NOT NULL,
    driver_name TEXT NOT NULL,              -- Primary display name
    slack_real_name TEXT,                   -- John Smith
    slack_display_name TEXT,                -- John S.
    slack_username TEXT,                    -- john.smith
    email TEXT,
    phone TEXT,
    status TEXT DEFAULT 'active',
    total_uploads INTEGER DEFAULT 0,        -- Cached count
    last_upload_date TIMESTAMPTZ,           -- Last image upload
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Enhanced `van_images` Table
```sql
CREATE TABLE van_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Relationships
    van_id UUID REFERENCES van_profiles(id),
    van_number INTEGER NOT NULL,
    driver_id UUID REFERENCES driver_profiles(id),
    slack_user_id TEXT REFERENCES driver_profiles(slack_user_id),
    
    -- Image storage
    image_data TEXT,                        -- Base64 encoded image
    image_url TEXT,                         -- Data URL or storage URL
    file_size BIGINT,
    content_type TEXT DEFAULT 'image/jpeg',
    
    -- Damage assessment
    van_damage TEXT,
    van_rating INTEGER,
    damage_type TEXT,
    damage_level INTEGER,
    location TEXT,
    description TEXT,
    
    -- Attribution (driver's actual name)
    uploaded_by TEXT,                       -- Driver's display name
    driver_name TEXT,                       -- Denormalized for quick access
    
    -- Metadata
    upload_method TEXT DEFAULT 'slack_bot',
    slack_channel_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    uploaded_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Flutter App Enhancements

### 1. Enhanced Driver Profile Screen

```dart
class DriverDetailPage extends StatefulWidget {
  final DriverProfile driver;
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(driver.driverName),
          subtitle: Text('@${driver.slackUsername}'),
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Profile'),
              Tab(icon: Icon(Icons.directions_car), text: 'Van Assignments'),
              Tab(icon: Icon(Icons.photo_camera), text: 'My Uploads'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildProfileTab(),
            _buildAssignmentsTab(),
            _buildUploadsTab(),  // Enhanced uploads tab
          ],
        ),
      ),
    );
  }
}
```

### 2. Enhanced Uploads Tab with Van Navigation

```dart
Widget _buildUploadsTab() {
  return FutureBuilder<Map<String, List<VanImage>>>(
    future: _loadDriverUploadsGroupedByVan(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      final uploadsByVan = snapshot.data ?? {};
      
      if (uploadsByVan.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_camera_outlined, size: 64, color: Colors.grey),
              Text('No uploads yet', style: TextStyle(color: Colors.grey)),
              Text('Upload images via Slack to see them here'),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: uploadsByVan.keys.length,
        itemBuilder: (context, index) {
          final vanNumber = uploadsByVan.keys.elementAt(index);
          final images = uploadsByVan[vanNumber]!;
          
          return _buildVanImageGroup(vanNumber, images);
        },
      );
    },
  );
}

Widget _buildVanImageGroup(String vanNumber, List<VanImage> images) {
  return Card(
    margin: EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Van header with navigation
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue,
            child: Text(vanNumber, style: TextStyle(color: Colors.white)),
          ),
          title: Text('Van #$vanNumber'),
          subtitle: Text('${images.length} upload${images.length != 1 ? 's' : ''}'),
          trailing: Icon(Icons.arrow_forward_ios),
          onTap: () => _navigateToVanProfile(vanNumber),
        ),
        
        // Image grid
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              return _buildImageThumbnail(image);
            },
          ),
        ),
        
        SizedBox(height: 16),
      ],
    ),
  );
}

Widget _buildImageThumbnail(VanImage image) {
  return Container(
    width: 100,
    margin: EdgeInsets.only(right: 8),
    child: Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showImageDetail(image),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                image.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          _formatUploadDate(image.uploadedAt),
          style: TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

void _navigateToVanProfile(String vanNumber) async {
  // Find van by number and navigate to van profile
  final van = await VanService().getVanByNumber(int.parse(vanNumber));
  if (van != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VanProfilePage(van: van),
      ),
    );
  }
}
```

### 3. Van Profile Enhancement with Driver History

```dart
class VanProfilePage extends StatefulWidget {
  final Van van;
  
  Widget _buildDriverHistorySection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Driver Upload History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            FutureBuilder<List<VanImageGroup>>(
              future: _loadVanImagesGroupedByDriver(),
              builder: (context, snapshot) {
                final groups = snapshot.data ?? [];
                
                return Column(
                  children: groups.map((group) => 
                    _buildDriverImageGroup(group)
                  ).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDriverImageGroup(VanImageGroup group) {
    return ExpansionTile(
      leading: CircleAvatar(
        child: Text(group.driverName[0].toUpperCase()),
      ),
      title: Text(group.driverName),
      subtitle: Text('${group.images.length} uploads • Last: ${_formatDate(group.lastUpload)}'),
      children: [
        Container(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: group.images.length,
            itemBuilder: (context, index) {
              final image = group.images[index];
              return GestureDetector(
                onTap: () => _showImageDetail(image),
                child: Container(
                  width: 80,
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(image.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Navigate to driver profile button
        TextButton.icon(
          onPressed: () => _navigateToDriverProfile(group.driverId),
          icon: Icon(Icons.person),
          label: Text('View ${group.driverName}\'s Profile'),
        ),
      ],
    );
  }
  
  void _navigateToDriverProfile(String driverId) async {
    final driver = await DriverService().getDriverById(driverId);
    if (driver != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverDetailPage(driver: driver),
        ),
      );
    }
  }
}
```

## Database Views for Efficient Querying

### Driver Upload Summary View
```sql
CREATE VIEW driver_upload_summary AS
SELECT 
    dp.id as driver_id,
    dp.driver_name,
    dp.slack_user_id,
    COUNT(vi.id) as total_uploads,
    COUNT(DISTINCT vi.van_id) as vans_photographed,
    MAX(vi.uploaded_at) as last_upload_date,
    AVG(vi.van_rating) as avg_damage_rating,
    
    -- Recent uploads by van
    jsonb_agg(
        DISTINCT jsonb_build_object(
            'van_number', vi.van_number,
            'upload_count', (
                SELECT COUNT(*) 
                FROM van_images vi2 
                WHERE vi2.driver_id = dp.id 
                AND vi2.van_number = vi.van_number
            ),
            'last_upload', (
                SELECT MAX(created_at) 
                FROM van_images vi3 
                WHERE vi3.driver_id = dp.id 
                AND vi3.van_number = vi.van_number
            )
        )
    ) as van_upload_summary
    
FROM driver_profiles dp
LEFT JOIN van_images vi ON dp.id = vi.driver_id
GROUP BY dp.id, dp.driver_name, dp.slack_user_id;
```

### Van Driver History View  
```sql
CREATE VIEW van_driver_history AS
SELECT 
    vp.id as van_id,
    vp.van_number,
    dp.id as driver_id,
    dp.driver_name,
    dp.slack_user_id,
    COUNT(vi.id) as upload_count,
    MIN(vi.uploaded_at) as first_upload,
    MAX(vi.uploaded_at) as last_upload,
    AVG(vi.van_rating) as avg_rating,
    
    -- Recent images
    jsonb_agg(
        jsonb_build_object(
            'id', vi.id,
            'image_url', vi.image_url,
            'damage_description', vi.van_damage,
            'rating', vi.van_rating,
            'uploaded_at', vi.uploaded_at
        ) ORDER BY vi.uploaded_at DESC
    ) as recent_images
    
FROM van_profiles vp
JOIN van_images vi ON vp.id = vi.van_id
JOIN driver_profiles dp ON vi.driver_id = dp.id
GROUP BY vp.id, vp.van_number, dp.id, dp.driver_name, dp.slack_user_id
ORDER BY vp.van_number, MAX(vi.uploaded_at) DESC;
```

## API Endpoints for Flutter

### Driver Service Enhancements
```dart
class DriverService {
  
  Future<Map<String, List<VanImage>>> getDriverUploadsGroupedByVan(String driverId) async {
    final response = await supabase
        .from('van_images')
        .select('''
          *,
          van_profiles!inner(van_number, make, model, status)
        ''')
        .eq('driver_id', driverId)
        .order('uploaded_at', ascending: false);
    
    final Map<String, List<VanImage>> groupedUploads = {};
    
    for (final item in response) {
      final vanNumber = item['van_profiles']['van_number'].toString();
      final image = VanImage.fromJson(item);
      
      if (!groupedUploads.containsKey(vanNumber)) {
        groupedUploads[vanNumber] = [];
      }
      groupedUploads[vanNumber]!.add(image);
    }
    
    return groupedUploads;
  }
  
  Future<DriverProfile?> getDriverBySlackUserId(String slackUserId) async {
    final response = await supabase
        .from('driver_profiles')
        .select('*')
        .eq('slack_user_id', slackUserId)
        .single();
    
    return DriverProfile.fromJson(response);
  }
  
  Future<List<DriverProfile>> getDriversWithRecentUploads() async {
    final response = await supabase
        .from('driver_upload_summary')
        .select('*')
        .gte('total_uploads', 1)
        .order('last_upload_date', ascending: false);
    
    return response.map((item) => DriverProfile.fromJson(item)).toList();
  }
}
```

### Van Service Enhancements
```dart
class VanService {
  
  Future<List<VanImageGroup>> getVanImagesGroupedByDriver(String vanId) async {
    final response = await supabase
        .from('van_driver_history')
        .select('*')
        .eq('van_id', vanId)
        .order('last_upload', ascending: false);
    
    return response.map((item) => VanImageGroup.fromJson(item)).toList();
  }
  
  Future<Van?> getVanByNumber(int vanNumber) async {
    final response = await supabase
        .from('van_profiles')
        .select('*')
        .eq('van_number', vanNumber)
        .single();
    
    return Van.fromJson(response);
  }
}
```

## Key Features Summary

### ✅ Driver Profile Creation
- **Automatic creation** from Slack display names
- **Priority system**: real_name → display_name → username → fallback
- **Profile enrichment** with Slack user data

### ✅ Image Attribution
- **Proper attribution** using driver's actual name (not 'slack_bot')
- **Complete linking** between driver, van, and image
- **Metadata preservation** including Slack user info

### ✅ Driver Profile Features
- **Upload history** grouped by van
- **Quick navigation** to van profiles
- **Image thumbnails** with upload dates
- **Upload statistics** and summaries

### ✅ Van Profile Features  
- **Driver history** showing all contributors
- **Upload timeline** by driver
- **Quick navigation** to driver profiles
- **Damage tracking** by contributor

### ✅ Cross-Navigation
- **Driver → Van**: Click van number to view van profile
- **Van → Driver**: Click driver name to view driver profile
- **Bidirectional linking** maintains context

### ✅ Enhanced Data Display
- **Real names** instead of Slack IDs
- **Upload counts** and statistics
- **Recent activity** summaries
- **Visual image** organization

This enhanced system creates a comprehensive tracking and navigation experience where drivers can see all their contributions and easily navigate between their profile and the vans they've documented. 
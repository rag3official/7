# 🔄 Update Flutter App for New Database Schema

## 📋 **Current Status**

✅ **Bot is working perfectly** - Van 99 uploaded successfully with base64 images  
❌ **Flutter app needs updating** - Still looking for old `vans` table

## 🔧 **Solution: Update Flutter App Files**

### **Step 1: Replace SupabaseService**

Replace the content of `lib/services/supabase_service.dart` with the updated version that uses:
- `van_profiles` instead of `vans` table
- `van_images` with base64 support
- `driver_profiles` for driver information

### **Step 2: Update Van Model**

The `lib/models/van.dart` has been updated to support both old and new schema with:
- New fields: `vanNumber`, `make`, `model`, `notes`, `currentDriverId`, `currentDriverName`
- `Van.fromNewSchema()` factory constructor
- `toNewSchemaJson()` method
- Updated `copyWith()` method

### **Step 3: Test the App**

After updating the files, your Flutter app should:
- ✅ Connect to `van_profiles` table
- ✅ Display van information with van numbers
- ✅ Show base64 images from the bot uploads
- ✅ Display driver information linked to vans

## 🖼️ **Image Display**

The app will now display images as **data URLs** like:
```
data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD...
```

Flutter can display these directly using:
```dart
Image.network(imageUrl) // Works with data URLs
```

## 📊 **Database Schema**

The app now works with:
- **van_profiles**: Van information (id, van_number, make, model, status, notes)
- **driver_profiles**: Driver information (id, slack_user_id, driver_name, email)
- **van_images**: Images with base64 data (id, van_id, driver_id, image_url, image_data)

## 🎉 **Expected Result**

After the update:
- ❌ No more "relation 'public.vans' does not exist" error
- ✅ App displays vans from van_profiles table
- ✅ Images appear from bot uploads (Van 99 should be visible)
- ✅ Driver information linked to vans
- ✅ Real-time updates when new images are uploaded via Slack

## 🚀 **Next Steps**

1. Replace the files as shown above
2. Restart your Flutter app
3. Test by uploading another image via Slack
4. Verify the image appears in the Flutter app 
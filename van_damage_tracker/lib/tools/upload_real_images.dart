import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

// Simplified script to upload real test images to Supabase storage
void main() async {
  try {
    print('🚀 Starting test image upload to Supabase...');

    // Your Supabase credentials
    final supabaseUrl = Platform.environment['SUPABASE_URL'] ??
        'https://lcvbagsksedduygdzsca.supabase.co';
    final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'] ??
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY2MTI0OTgsImV4cCI6MjAyMjE4ODQ5OH0.vkGmkfzumkRacnhsHm2zx-YKE8uuDojT4ZcJBGdKrfE';

    print('🔗 Using Supabase URL: $supabaseUrl');

    // Test images to download and upload
    final testImages = [
      {
        'url': 'https://picsum.photos/800/600?random=1',
        'filename': 'damage_front_bumper_20240322_143021.jpg',
        'damageType': 'dent'
      },
      {
        'url': 'https://picsum.photos/800/600?random=2',
        'filename': 'damage_side_panel_20240322_143045.jpg',
        'damageType': 'paint_damage'
      },
      {
        'url': 'https://picsum.photos/800/600?random=3',
        'filename': 'damage_rear_door_20240322_143112.jpg',
        'damageType': 'scratch'
      },
    ];

    final uploadedUrls = <String, String>{};

    // Upload each test image to Supabase storage
    for (int i = 0; i < testImages.length; i++) {
      final image = testImages[i];
      try {
        print(
            '📥 Downloading test image ${i + 1}/${testImages.length}: ${image['filename']}');

        // Download image
        final response = await http.get(Uri.parse(image['url']!));
        if (response.statusCode != 200) {
          print('❌ Failed to download image: ${response.statusCode}');
          continue;
        }

        final imageBytes = response.bodyBytes;
        print('✅ Downloaded ${imageBytes.length} bytes');

        // Upload to Supabase storage in van_92 folder
        final storagePath = 'van_92/${image['filename']}';

        print('📤 Uploading to Supabase storage: $storagePath');

        // Use Supabase Storage API directly
        final uploadResponse = await http.post(
          Uri.parse('$supabaseUrl/storage/v1/object/van-images/$storagePath'),
          headers: {
            'Authorization': 'Bearer $supabaseKey',
            'Content-Type': 'image/jpeg',
          },
          body: imageBytes,
        );

        print('📊 Upload response status: ${uploadResponse.statusCode}');
        print('📊 Upload response body: ${uploadResponse.body}');

        if (uploadResponse.statusCode == 200 ||
            uploadResponse.statusCode == 201) {
          // Construct the public URL
          final publicUrl =
              '$supabaseUrl/storage/v1/object/public/van-images/$storagePath';
          print('🔗 Public URL: $publicUrl');
          uploadedUrls[image['damageType']!] = publicUrl;
        } else {
          print('❌ Upload failed with status: ${uploadResponse.statusCode}');
        }
      } catch (e) {
        print('❌ Error uploading image ${image['filename']}: $e');
      }
    }

    print('\n📝 Uploaded URLs:');
    uploadedUrls.forEach((damageType, url) {
      print('  $damageType: $url');
    });

    // Update database records with real Supabase URLs
    if (uploadedUrls.isNotEmpty) {
      print('\n🔄 Updating database with real Supabase URLs...');

      for (final entry in uploadedUrls.entries) {
        final damageType = entry.key;
        final newUrl = entry.value;

        try {
          // Update van_images table using Supabase REST API
          final updateResponse = await http.patch(
            Uri.parse(
                '$supabaseUrl/rest/v1/van_images?damage_type=eq.$damageType&van_id=eq.8fe28eee-6ee5-4123-9a8d-e7b163500e0c'),
            headers: {
              'Authorization': 'Bearer $supabaseKey',
              'Content-Type': 'application/json',
              'apikey': supabaseKey,
              'Prefer': 'return=representation',
            },
            body: json.encode({'image_url': newUrl}),
          );

          print('📊 Update response status: ${updateResponse.statusCode}');
          print('📊 Update response body: ${updateResponse.body}');

          if (updateResponse.statusCode == 200) {
            print('✅ Updated database records for $damageType');
          } else {
            print(
                '❌ Failed to update database for $damageType: ${updateResponse.statusCode}');
          }
        } catch (e) {
          print('❌ Error updating database for $damageType: $e');
        }
      }
    }

    print('\n🎉 Test image upload completed!');
    print('💡 You should now see real Supabase storage URLs in your app');
    print('🔄 Restart your Flutter app to see the changes');
  } catch (e) {
    print('❌ Error: $e');
  }
}

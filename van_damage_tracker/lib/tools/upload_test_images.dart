import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

// Script to upload real test images to Supabase storage and update database
void main() async {
  try {
    print('🚀 Starting test image upload process...');

    // Load environment variables
    final supabaseUrl = Platform.environment['SUPABASE_URL'];
    final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseKey == null) {
      print('❌ Missing environment variables');
      return;
    }

    // Initialize Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );

    final supabase = Supabase.instance.client;

    print('✅ Supabase initialized');

    // Download test images and upload to storage
    final testImages = [
      {
        'url':
            'https://images.unsplash.com/photo-1570993492881-25240ce854f4?w=800&h=600&fit=crop&auto=format',
        'filename': 'damage_front_bumper_20240322_143021.jpg',
        'damageType': 'dent'
      },
      {
        'url':
            'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&h=600&fit=crop&auto=format',
        'filename': 'damage_side_panel_20240322_143045.jpg',
        'damageType': 'paint_damage'
      },
      {
        'url':
            'https://images.unsplash.com/photo-1586244439413-bc2288941dda?w=800&h=600&fit=crop&auto=format',
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

        // Download image from Unsplash
        final response = await http.get(Uri.parse(image['url']!));
        if (response.statusCode != 200) {
          print('❌ Failed to download image: ${response.statusCode}');
          continue;
        }

        final imageBytes = response.bodyBytes;
        print('✅ Downloaded ${imageBytes.length} bytes');

        // Upload to Supabase storage in van_92 folder to match existing data
        final storagePath = 'van_92/${image['filename']}';

        print('📤 Uploading to Supabase storage: $storagePath');

        final uploadResult = await supabase.storage
            .from('van-images')
            .uploadBinary(storagePath, imageBytes,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                ));

        print('✅ Upload result: $uploadResult');

        // Get the public URL
        final publicUrl =
            supabase.storage.from('van-images').getPublicUrl(storagePath);

        print('🔗 Public URL: $publicUrl');
        uploadedUrls[image['damageType']!] = publicUrl;
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

      // Update records based on damage type
      for (final entry in uploadedUrls.entries) {
        final damageType = entry.key;
        final newUrl = entry.value;

        try {
          final updateResult = await supabase
              .from('van_images')
              .update({'image_url': newUrl})
              .eq('damage_type', damageType)
              .eq('van_id', '8fe28eee-6ee5-4123-9a8d-e7b163500e0c')
              .select();

          print('✅ Updated ${updateResult.length} records for $damageType');
        } catch (e) {
          print('❌ Error updating database for $damageType: $e');
        }
      }
    }

    // Verify the updates
    print('\n🔍 Verifying updated records...');
    final verifyResponse = await supabase
        .from('van_images')
        .select('id, image_url, damage_type, damage_level')
        .eq('van_id', '8fe28eee-6ee5-4123-9a8d-e7b163500e0c')
        .limit(10);

    print('📋 Updated records:');
    for (var record in verifyResponse) {
      final url = record['image_url'] as String;
      final urlPreview = url.length > 80 ? '${url.substring(0, 80)}...' : url;
      print('  ${record['damage_type']}: $urlPreview');
    }

    print('\n🎉 Test image upload completed successfully!');
    print('💡 You should now see real Supabase storage URLs in your app');
  } catch (e) {
    print('❌ Error: $e');
  }
}

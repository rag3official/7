import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

// Script to set up van-images storage bucket and upload test images
void main() async {
  try {
    print('🚀 Setting up van-images storage bucket...');

    // Your Supabase credentials
    final supabaseUrl = Platform.environment['SUPABASE_URL'] ??
        'https://lcvbagsksedduygdzsca.supabase.co';
    final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'] ??
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY2MTI0OTgsImV4cCI6MjAyMjE4ODQ5OH0.vkGmkfzumkRacnhsHm2zx-YKE8uuDojT4ZcJBGdKrfE';

    print('🔗 Using Supabase URL: $supabaseUrl');

    // Step 1: List existing buckets
    print('\n📁 Step 1: Checking existing storage buckets...');
    final bucketsResponse = await http.get(
      Uri.parse('$supabaseUrl/storage/v1/bucket'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    if (bucketsResponse.statusCode == 200) {
      final List<dynamic> buckets = json.decode(bucketsResponse.body);
      print('✅ Found ${buckets.length} existing buckets:');
      for (var bucket in buckets) {
        print(
            '   - ${bucket['name']} (${bucket['public'] ? 'public' : 'private'})');
      }
    }

    // Step 2: Create van-images bucket if it doesn't exist
    print('\n🗂️ Step 2: Creating van-images bucket...');
    final createBucketResponse = await http.post(
      Uri.parse('$supabaseUrl/storage/v1/bucket'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey,',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'id': 'van-images',
        'name': 'van-images',
        'public': true,
        'file_size_limit': 52428800, // 50MB
        'allowed_mime_types': [
          'image/jpeg',
          'image/jpg',
          'image/png',
          'image/webp'
        ],
      }),
    );

    if (createBucketResponse.statusCode == 200) {
      print('✅ Successfully created van-images bucket');
    } else if (createBucketResponse.statusCode == 409) {
      print('✅ van-images bucket already exists');
    } else {
      print('❌ Failed to create bucket: ${createBucketResponse.statusCode}');
      print('Response: ${createBucketResponse.body}');
    }

    // Step 3: Download and upload test images
    print('\n📷 Step 3: Uploading test images to van folders...');

    // Test images for different vans
    final Map<String, List<Map<String, String>>> testImages = {
      'van_92': [
        {
          'fileName': 'damage_front_bumper_20240322_143021.jpg',
          'url':
              'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=800&h=600&fit=crop',
        },
        {
          'fileName': 'damage_side_panel_20240322_143045.jpg',
          'url':
              'https://images.unsplash.com/photo-1570993492881-25240ce854f4?w=800&h=600&fit=crop',
        },
        {
          'fileName': 'damage_rear_door_20240322_143112.jpg',
          'url':
              'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&h=600&fit=crop',
        },
      ],
      'van_87': [
        {
          'fileName': 'inspection_front_view_20240322_140030.jpg',
          'url':
              'https://images.unsplash.com/photo-1586244439413-bc2288941dda?w=800&h=600&fit=crop',
        },
        {
          'fileName': 'damage_scratch_left_20240322_140115.jpg',
          'url':
              'https://images.unsplash.com/photo-1560473354-208d3fdcf7ae?w=800&h=600&fit=crop',
        },
      ],
      'van_45': [
        {
          'fileName': 'damage_dent_front_20240322_135045.jpg',
          'url':
              'https://images.unsplash.com/photo-1517524008697-84bbe3c3fd98?w=800&h=600&fit=crop',
        },
      ],
    };

    for (var vanEntry in testImages.entries) {
      final String vanFolder = vanEntry.key;
      final List<Map<String, String>> images = vanEntry.value;

      print('\n📁 Uploading images for $vanFolder...');

      for (var image in images) {
        final String fileName = image['fileName']!;
        final String imageUrl = image['url']!;
        final String storagePath = '$vanFolder/$fileName';

        try {
          // Download the image
          print('   📥 Downloading: $fileName');
          final imageResponse = await http.get(Uri.parse(imageUrl));

          if (imageResponse.statusCode != 200) {
            print(
                '   ❌ Failed to download $fileName: ${imageResponse.statusCode}');
            continue;
          }

          // Upload to Supabase storage
          print('   📤 Uploading: $storagePath');
          final uploadResponse = await http.post(
            Uri.parse('$supabaseUrl/storage/v1/object/van-images/$storagePath'),
            headers: {
              'apikey': supabaseKey,
              'Authorization': 'Bearer $supabaseKey',
              'Content-Type': 'image/jpeg',
              'Cache-Control': '3600',
            },
            body: imageResponse.bodyBytes,
          );

          if (uploadResponse.statusCode == 200) {
            print('   ✅ Successfully uploaded: $storagePath');
          } else {
            print(
                '   ❌ Failed to upload $storagePath: ${uploadResponse.statusCode}');
            print('   Response: ${uploadResponse.body}');
          }
        } catch (e) {
          print('   ❌ Error processing $fileName: $e');
        }
      }
    }

    // Step 4: Verify uploads
    print('\n🔍 Step 4: Verifying uploaded files...');
    final listResponse = await http.get(
      Uri.parse('$supabaseUrl/storage/v1/object/list/van-images'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    if (listResponse.statusCode == 200) {
      final List<dynamic> files = json.decode(listResponse.body);
      print('✅ Successfully uploaded ${files.length} files:');
      for (var file in files) {
        final String fileName = file['name'];
        final String publicUrl =
            '$supabaseUrl/storage/v1/object/public/van-images/$fileName';
        print('   📷 $fileName');
        print('      🔗 $publicUrl');
      }
    } else {
      print('❌ Failed to list files: ${listResponse.statusCode}');
    }

    print('\n🎉 Storage bucket setup completed!');
    print('🔄 Now you can run the sync script to update the database');
  } catch (e) {
    print('❌ Error during setup: $e');
  }
}

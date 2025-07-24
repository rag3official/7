import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

// Simple direct check of the storage bucket
void main() async {
  try {
    print('🔍 Checking van-images storage bucket directly...');

    // Your Supabase credentials
    final supabaseUrl = Platform.environment['SUPABASE_URL'] ??
        'https://lcvbagsksedduygdzsca.supabase.co';
    final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'] ??
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY2MTI0OTgsImV4cCI6MjAyMjE4ODQ5OH0.vkGmkfzumkRacnhsHm2zx-YKE8uuDojT4ZcJBGdKrfE';

    print('🔗 Supabase URL: $supabaseUrl');
    print('🔑 Using API key: ${supabaseKey.substring(0, 20)}...');

    // Step 1: Try to list the specific van-images bucket
    print('\n📁 Step 1: Checking van-images bucket specifically...');
    final vanImagesResponse = await http.get(
      Uri.parse('$supabaseUrl/storage/v1/object/list/van-images'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    print('Response status: ${vanImagesResponse.statusCode}');
    print('Response body: ${vanImagesResponse.body}');

    if (vanImagesResponse.statusCode == 200) {
      final List<dynamic> files = json.decode(vanImagesResponse.body);
      print('✅ van-images bucket exists with ${files.length} items');

      // Show some examples
      for (int i = 0; i < files.length && i < 5; i++) {
        final file = files[i];
        print('   📄 ${file['name']} (${file['updated_at']})');
      }

      if (files.length > 5) {
        print('   ... and ${files.length - 5} more files');
      }
    } else if (vanImagesResponse.statusCode == 404) {
      print('❌ van-images bucket does not exist');
      print('📝 You need to create it first');
    } else {
      print(
          '❌ Error accessing van-images bucket: ${vanImagesResponse.statusCode}');
      print('📝 Response: ${vanImagesResponse.body}');
    }

    // Step 2: List all buckets to see what exists
    print('\n📁 Step 2: Listing all available buckets...');
    final bucketsResponse = await http.get(
      Uri.parse('$supabaseUrl/storage/v1/bucket'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    print('Buckets response status: ${bucketsResponse.statusCode}');
    if (bucketsResponse.statusCode == 200) {
      final List<dynamic> buckets = json.decode(bucketsResponse.body);
      print('✅ Found ${buckets.length} total buckets:');

      for (var bucket in buckets) {
        final bucketName = bucket['name'];
        final isPublic = bucket['public'] ?? false;
        print('   📦 $bucketName (${isPublic ? 'public' : 'private'})');
      }
    } else {
      print('❌ Error listing buckets: ${bucketsResponse.statusCode}');
      print('📝 Response: ${bucketsResponse.body}');
    }

    // Step 3: Check database van_images table
    print('\n🗄️ Step 3: Checking van_images database table...');
    final dbResponse = await http.get(
      Uri.parse(
          '$supabaseUrl/rest/v1/van_images?select=id,van_id,image_url&limit=5'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Content-Type': 'application/json',
      },
    );

    print('Database response status: ${dbResponse.statusCode}');
    if (dbResponse.statusCode == 200) {
      final List<dynamic> records = json.decode(dbResponse.body);
      print('✅ Found ${records.length} records in van_images table');

      for (var record in records) {
        print(
            '   🗃️ ID: ${record['id']}, Van: ${record['van_id']}, URL: ${record['image_url']}');
      }
    } else {
      print('❌ Error accessing van_images table: ${dbResponse.statusCode}');
      print('📝 Response: ${dbResponse.body}');
    }

    print('\n✅ Direct storage check completed!');
  } catch (e) {
    print('❌ Error during direct check: $e');
  }
}

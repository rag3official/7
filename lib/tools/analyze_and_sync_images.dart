import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    print('🔍 Analyzing van_images table and storage bucket...');

    const supabaseUrl = 'https://lcvbagsksedduygdzsca.supabase.co';
    const supabaseKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY2MTI0OTgsImV4cCI6MjAyMjE4ODQ5OH0.vkGmkfzumkRacnhsHm2zx-YKE8uuDojT4ZcJBGdKrfE';

    // Step 1: Analyze current van_images table
    print('\n📊 Step 1: Analyzing current van_images table...');
    final dbResponse = await http.get(
      Uri.parse(
          '$supabaseUrl/rest/v1/van_images?select=id,van_id,image_url&order=created_at.desc'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Content-Type': 'application/json',
      },
    );

    if (dbResponse.statusCode == 200) {
      final List<dynamic> records = json.decode(dbResponse.body);
      print('✅ Found ${records.length} records in van_images table');

      int storageUrls = 0;
      int unsplashUrls = 0;
      int otherUrls = 0;

      print('\n🔍 URL Analysis:');
      for (var record in records) {
        final url = record['image_url'] as String;
        if (url.contains(
            'lcvbagsksedduygdzsca.supabase.co/storage/v1/object/public/van-images')) {
          storageUrls++;
          print('   ✅ STORAGE: ${url.substring(0, 80)}...');
        } else if (url.contains('images.unsplash.com')) {
          unsplashUrls++;
          print('   ❌ UNSPLASH: ${url.substring(0, 80)}...');
        } else {
          otherUrls++;
          print('   ⚠️ OTHER: ${url.substring(0, 80)}...');
        }
      }

      print('\n📈 Summary:');
      print('   ✅ Storage bucket URLs: $storageUrls');
      print('   ❌ Unsplash placeholder URLs: $unsplashUrls');
      print('   ⚠️ Other URLs: $otherUrls');

      if (unsplashUrls > 0 || otherUrls > 0) {
        print(
            '\n⚠️ ISSUE: You have ${unsplashUrls + otherUrls} records not pointing to your storage bucket!');
      }
    }

    // Step 2: Check what's actually in the storage bucket
    print('\n📁 Step 2: Checking van-images storage bucket...');
    final storageResponse = await http.get(
      Uri.parse('$supabaseUrl/storage/v1/object/list/van-images'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    if (storageResponse.statusCode == 200) {
      final List<dynamic> files = json.decode(storageResponse.body);
      print('✅ Found ${files.length} files in van-images storage bucket');

      // Organize by van folder
      Map<String, List<String>> vanFolders = {};
      for (var file in files) {
        final fileName = file['name'] as String;
        if (fileName.contains('/')) {
          final folderName = fileName.split('/')[0];
          if (!vanFolders.containsKey(folderName)) {
            vanFolders[folderName] = [];
          }
          vanFolders[folderName]!.add(fileName);
        }
      }

      print('📂 Storage bucket structure:');
      vanFolders.forEach((folder, files) {
        print('   📁 $folder/ (${files.length} files)');
        for (var file in files.take(2)) {
          print('      - $file');
        }
        if (files.length > 2) {
          print('      ... and ${files.length - 2} more');
        }
      });

      // Step 3: Recommendation
      print('\n💡 Step 3: Recommendations');
      if (vanFolders.isNotEmpty) {
        print(
            '✅ Your van-images storage bucket has ${vanFolders.length} van folders with images');
        print(
            '🔄 You should sync this storage content to your van_images table');
        print('');
        print('Options:');
        print('1. 🧹 Clear van_images table and repopulate from storage');
        print('2. 🔄 Update existing records to point to storage URLs');
        print('3. ➕ Add missing storage images to van_images table');
        print('');
        print(
            'Would you like me to create a sync script for any of these options?');
      } else {
        print('❌ Your van-images storage bucket appears to be empty');
        print('📤 You need to upload images to the storage bucket first');
      }
    } else {
      print(
          '❌ Failed to access van-images storage bucket: ${storageResponse.statusCode}');
      print('Response: ${storageResponse.body}');
    }

    print('\n✅ Analysis completed!');
  } catch (e) {
    print('❌ Error during analysis: $e');
  }
}

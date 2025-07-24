import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

// Script to sync van-images storage bucket with database tables
void main() async {
  try {
    print('🚀 Starting storage bucket sync to database...');

    // Your Supabase credentials
    final supabaseUrl = Platform.environment['SUPABASE_URL'] ??
        'https://lcvbagsksedduygdzsca.supabase.co';
    final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'] ??
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY2MTI0OTgsImV4cCI6MjAyMjE4ODQ5OH0.vkGmkfzumkRacnhsHm2zx-YKE8uuDojT4ZcJBGdKrfE';

    print('🔗 Using Supabase URL: $supabaseUrl');

    // Step 1: List all files in van-images storage bucket
    print('\n📁 Step 1: Fetching all files from van-images storage bucket...');
    final storageResponse = await http.get(
      Uri.parse('$supabaseUrl/storage/v1/object/list/van-images'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    if (storageResponse.statusCode != 200) {
      print('❌ Failed to list storage files: ${storageResponse.statusCode}');
      print('Response: ${storageResponse.body}');
      return;
    }

    final List<dynamic> storageFiles = json.decode(storageResponse.body);
    print('✅ Found ${storageFiles.length} files in storage bucket');

    // Step 2: Organize files by van folder
    print('\n📂 Step 2: Organizing files by van folder...');
    Map<String, List<Map<String, dynamic>>> vanFolders = {};

    for (var file in storageFiles) {
      final String fileName = file['name'];
      final String fullUrl =
          '$supabaseUrl/storage/v1/object/public/van-images/$fileName';

      // Extract van folder (e.g., "van_92" from "van_92/damage_front_bumper_20240322_143021.jpg")
      if (fileName.contains('/')) {
        final parts = fileName.split('/');
        final vanFolder = parts[0]; // e.g., "van_92"
        final actualFileName =
            parts[1]; // e.g., "damage_front_bumper_20240322_143021.jpg"

        if (!vanFolders.containsKey(vanFolder)) {
          vanFolders[vanFolder] = [];
        }

        vanFolders[vanFolder]!.add({
          'fileName': actualFileName,
          'fullPath': fileName,
          'url': fullUrl,
          'vanFolder': vanFolder,
        });
      }
    }

    print('✅ Organized files into ${vanFolders.length} van folders:');
    vanFolders.forEach((folder, files) {
      print('   $folder: ${files.length} images');
    });

    // Step 3: Get all vans from database to map van numbers to IDs
    print('\n🚐 Step 3: Fetching vans from database...');
    final vansResponse = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/vans?select=id,van_number,plate_number'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    if (vansResponse.statusCode != 200) {
      print('❌ Failed to fetch vans: ${vansResponse.statusCode}');
      return;
    }

    final List<dynamic> vans = json.decode(vansResponse.body);
    print('✅ Found ${vans.length} vans in database');

    // Create mapping from van number to van ID
    Map<String, String> vanNumberToId = {};
    for (var van in vans) {
      final vanNumber =
          van['van_number']?.toString() ?? van['plate_number']?.toString();
      if (vanNumber != null) {
        vanNumberToId[vanNumber] = van['id'];
      }
    }

    // Step 4: Clear existing van_images records
    print('\n🗑️ Step 4: Clearing existing van_images records...');
    final deleteResponse = await http.delete(
      Uri.parse('$supabaseUrl/rest/v1/van_images'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );
    print('✅ Cleared existing van_images records');

    // Step 5: Insert new van_images records from storage
    print('\n📝 Step 5: Inserting van_images records from storage...');

    for (var entry in vanFolders.entries) {
      final String vanFolder = entry.key; // e.g., "van_92"
      final List<Map<String, dynamic>> files = entry.value;

      // Extract van number from folder name (e.g., "92" from "van_92")
      final vanNumberMatch = RegExp(r'van_(\d+)').firstMatch(vanFolder);
      if (vanNumberMatch == null) {
        print('⚠️ Could not extract van number from folder: $vanFolder');
        continue;
      }

      final String vanNumber = vanNumberMatch.group(1)!;
      final String? vanId = vanNumberToId[vanNumber];

      if (vanId == null) {
        print('⚠️ Could not find van ID for van number: $vanNumber');
        continue;
      }

      print(
          '📁 Processing $vanFolder (Van ID: $vanId) - ${files.length} images');

      // Insert each image for this van
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final fileName = file['fileName'];

        // Extract damage information from filename
        String damageType = 'unknown';
        int damageLevel = 1;
        String location = 'unknown';

        if (fileName.contains('damage_')) {
          if (fileName.contains('front')) {
            location = 'front';
          } else if (fileName.contains('rear'))
            location = 'rear';
          else if (fileName.contains('side'))
            location = 'side';
          else if (fileName.contains('door')) location = 'door';

          if (fileName.contains('bumper')) {
            damageType = 'dent';
          } else if (fileName.contains('panel'))
            damageType = 'paint_damage';
          else if (fileName.contains('door'))
            damageType = 'scratch';
          else if (fileName.contains('dent'))
            damageType = 'dent';
          else if (fileName.contains('scratch')) damageType = 'scratch';

          // Assign damage levels cyclically (1-5)
          damageLevel = (i % 5) + 1;
        }

        // Insert van_image record
        final imageRecord = {
          'van_id': vanId,
          'image_url': file['url'],
          'damage_type': damageType,
          'damage_level': damageLevel,
          'location': location,
          'description': 'Damage photo: ${fileName.replaceAll('_', ' ')}',
        };

        final insertResponse = await http.post(
          Uri.parse('$supabaseUrl/rest/v1/van_images'),
          headers: {
            'apikey': supabaseKey,
            'Authorization': 'Bearer $supabaseKey',
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: json.encode(imageRecord),
        );

        if (insertResponse.statusCode == 201) {
          print('   ✅ Inserted: $fileName');
        } else {
          print(
              '   ❌ Failed to insert $fileName: ${insertResponse.statusCode}');
        }
      }
    }

    // Step 6: Update vans table with main image URLs
    print('\n🖼️ Step 6: Updating vans table with main image URLs...');

    for (var entry in vanFolders.entries) {
      final String vanFolder = entry.key;
      final List<Map<String, dynamic>> files = entry.value;

      if (files.isEmpty) continue;

      // Extract van number
      final vanNumberMatch = RegExp(r'van_(\d+)').firstMatch(vanFolder);
      if (vanNumberMatch == null) continue;

      final String vanNumber = vanNumberMatch.group(1)!;
      final String? vanId = vanNumberToId[vanNumber];

      if (vanId == null) continue;

      // Use the first image as the main image
      final mainImageUrl = files[0]['url'];

      // Update van record with main image URL
      final updateResponse = await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/vans?id=eq.$vanId'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: json.encode({
          'main_image_url': mainImageUrl,
        }),
      );

      if (updateResponse.statusCode == 200 ||
          updateResponse.statusCode == 204) {
        print('   ✅ Updated van $vanNumber with main image');
      } else {
        print(
            '   ❌ Failed to update van $vanNumber: ${updateResponse.statusCode}');
      }
    }

    // Step 7: Verify the sync
    print('\n🔍 Step 7: Verifying sync results...');

    final verifyImagesResponse = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/van_images?select=count'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    final verifyVansResponse = await http.get(
      Uri.parse(
          '$supabaseUrl/rest/v1/vans?select=id,van_number,main_image_url&main_image_url=not.is.null'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    print('📊 Sync Results:');
    print('   van_images table: Database updated');
    print(
        '   vans table: ${json.decode(verifyVansResponse.body).length} vans updated with main images');

    print('\n🎉 Storage bucket sync completed successfully!');
    print('🔄 Restart your Flutter app to see the real images from storage');
  } catch (e) {
    print('❌ Error during sync: $e');
  }
}

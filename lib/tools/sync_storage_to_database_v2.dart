import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    print('🔄 COMPREHENSIVE SYNC: van-images storage ↔ van_images table');
    print('🎯 Goal: Update existing URLs + Add missing images from storage\n');

    const supabaseUrl = 'https://lcvbagsksedduygdzsca.supabase.co';
    const supabaseKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY2MTI0OTgsImV4cCI6MjAyMjE4ODQ5OH0.vkGmkfzumkRacnhsHm2zx-YKE8uuDojT4ZcJBGdKrfE';

    // =============================================================================
    // STEP 1: Analyze van-images storage bucket
    // =============================================================================
    print('📁 STEP 1: Analyzing van-images storage bucket...');
    final storageResponse = await http.get(
      Uri.parse('$supabaseUrl/storage/v1/object/list/van-images'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    if (storageResponse.statusCode != 200) {
      print(
          '❌ Failed to access van-images storage: ${storageResponse.statusCode}');
      print('Response: ${storageResponse.body}');
      return;
    }

    final List<dynamic> storageFiles = json.decode(storageResponse.body);
    print('✅ Found ${storageFiles.length} files in van-images storage bucket');

    // Organize storage files by van folder
    Map<String, List<Map<String, dynamic>>> storageByVan = {};
    for (var file in storageFiles) {
      final fileName = file['name'] as String;
      if (fileName.contains('/') && !fileName.endsWith('/')) {
        final parts = fileName.split('/');
        final vanFolder = parts[0]; // e.g., "van_92"
        final actualFileName = parts[1]; // e.g., "damage_front_bumper.jpg"

        if (!storageByVan.containsKey(vanFolder)) {
          storageByVan[vanFolder] = [];
        }
        storageByVan[vanFolder]!.add({
          'full_path': fileName,
          'file_name': actualFileName,
          'storage_url':
              '$supabaseUrl/storage/v1/object/public/van-images/$fileName',
          'created_at': file['created_at'],
          'updated_at': file['updated_at'],
        });
      }
    }

    print('📂 Storage structure:');
    storageByVan.forEach((vanFolder, files) {
      print('   📁 $vanFolder/ → ${files.length} images');
    });

    // =============================================================================
    // STEP 2: Get van number to ID mapping
    // =============================================================================
    print('\n🗺️  STEP 2: Mapping van numbers to database IDs...');
    final vansResponse = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/vans?select=id,van_number'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    if (vansResponse.statusCode != 200) {
      print('❌ Failed to fetch vans: ${vansResponse.statusCode}');
      return;
    }

    final List<dynamic> vansData = json.decode(vansResponse.body);
    Map<String, String> vanNumberToId = {};
    Map<String, String> vanIdToNumber = {};

    for (var van in vansData) {
      final vanNumber = van['van_number']?.toString() ?? '';
      final vanId = van['id'] as String;
      if (vanNumber.isNotEmpty) {
        vanNumberToId['van_$vanNumber'] = vanId;
        vanIdToNumber[vanId] = vanNumber;
      }
    }

    print('✅ Mapped ${vanNumberToId.length} van numbers to database IDs');
    vanNumberToId.forEach((folder, id) {
      print('   📍 $folder → $id');
    });

    // =============================================================================
    // STEP 3: Analyze current van_images table
    // =============================================================================
    print('\n📊 STEP 3: Analyzing current van_images table...');
    final dbResponse = await http.get(
      Uri.parse(
          '$supabaseUrl/rest/v1/van_images?select=id,van_id,image_url,damage_type,damage_level,location,description'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    if (dbResponse.statusCode != 200) {
      print('❌ Failed to fetch van_images: ${dbResponse.statusCode}');
      return;
    }

    final List<dynamic> existingRecords = json.decode(dbResponse.body);
    print(
        '✅ Found ${existingRecords.length} existing records in van_images table');

    // Categorize existing records
    List<Map<String, dynamic>> storageRecords = [];
    List<Map<String, dynamic>> placeholderRecords = [];

    for (var record in existingRecords) {
      final url = record['image_url'] as String;
      if (url.contains(
          'lcvbagsksedduygdzsca.supabase.co/storage/v1/object/public/van-images')) {
        storageRecords.add(record);
      } else {
        placeholderRecords.add(record);
      }
    }

    print('   ✅ Storage URLs: ${storageRecords.length}');
    print('   ❌ Placeholder URLs: ${placeholderRecords.length}');

    // =============================================================================
    // STEP 4: Sync Plan
    // =============================================================================
    print('\n📋 STEP 4: Creating sync plan...');

    int toUpdate = 0;
    int toAdd = 0;
    List<Map<String, dynamic>> updateActions = [];
    List<Map<String, dynamic>> addActions = [];

    // For each van folder in storage, check what needs to be done
    storageByVan.forEach((vanFolder, storageFiles) {
      final vanId = vanNumberToId[vanFolder];
      if (vanId == null) {
        print('   ⚠️  Skipping $vanFolder - no matching van in database');
        return;
      }

      print('   🔍 Processing $vanFolder (van_id: $vanId)...');

      // Get existing records for this van
      final existingForVan =
          existingRecords.where((r) => r['van_id'] == vanId).toList();

      // Check each storage file
      for (var storageFile in storageFiles) {
        final storageUrl = storageFile['storage_url'];

        // Check if this storage URL already exists in database
        final existingWithSameUrl = existingForVan
            .where(
              (r) => r['image_url'] == storageUrl,
            )
            .isNotEmpty;

        if (existingWithSameUrl) {
          print('     ✅ Already exists: ${storageFile['file_name']}');
        } else {
          // Check if we have a placeholder record we can update
          final placeholderForVan = existingForVan
              .where(
                (r) => !r['image_url']
                    .toString()
                    .contains('lcvbagsksedduygdzsca.supabase.co/storage'),
              )
              .toList();

          if (placeholderForVan.isNotEmpty) {
            // Update existing placeholder record
            final recordToUpdate = placeholderForVan.first;
            updateActions.add({
              'action': 'update',
              'record_id': recordToUpdate['id'],
              'van_id': vanId,
              'old_url': recordToUpdate['image_url'],
              'new_url': storageUrl,
              'file_name': storageFile['file_name'],
            });
            toUpdate++;
            print('     🔄 Will update: ${storageFile['file_name']}');

            // Remove from existing list so we don't try to update it again
            existingForVan.remove(recordToUpdate);
          } else {
            // Add new record
            addActions.add({
              'action': 'add',
              'van_id': vanId,
              'van_number': vanIdToNumber[vanId],
              'image_url': storageUrl,
              'file_name': storageFile['file_name'],
              'damage_type': _guessDamageType(storageFile['file_name']),
              'damage_level': 2, // Default to moderate
              'location': _guessLocation(storageFile['file_name']),
            });
            toAdd++;
            print('     ➕ Will add: ${storageFile['file_name']}');
          }
        }
      }
    });

    print('\n📈 SYNC SUMMARY:');
    print('   🔄 Records to update: $toUpdate');
    print('   ➕ Records to add: $toAdd');
    print('   ✅ Total actions: ${toUpdate + toAdd}');

    if (toUpdate == 0 && toAdd == 0) {
      print('\n🎉 Everything is already in sync! No changes needed.');
      return;
    }

    // =============================================================================
    // STEP 5: Execute sync
    // =============================================================================
    print('\n🚀 STEP 5: Executing sync...');

    int updated = 0;
    int added = 0;

    // Execute updates
    for (var action in updateActions) {
      try {
        final updateResponse = await http.patch(
          Uri.parse(
              '$supabaseUrl/rest/v1/van_images?id=eq.${action['record_id']}'),
          headers: {
            'apikey': supabaseKey,
            'Authorization': 'Bearer $supabaseKey',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'image_url': action['new_url'],
            'updated_at': DateTime.now().toIso8601String(),
          }),
        );

        if (updateResponse.statusCode == 204) {
          updated++;
          print('   ✅ Updated: ${action['file_name']}');
        } else {
          print(
              '   ❌ Update failed for ${action['file_name']}: ${updateResponse.statusCode}');
        }
      } catch (e) {
        print('   ❌ Update error for ${action['file_name']}: $e');
      }
    }

    // Execute additions
    for (var action in addActions) {
      try {
        final addResponse = await http.post(
          Uri.parse('$supabaseUrl/rest/v1/van_images'),
          headers: {
            'apikey': supabaseKey,
            'Authorization': 'Bearer $supabaseKey',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'van_id': action['van_id'],
            'image_url': action['image_url'],
            'damage_type': action['damage_type'],
            'damage_level': action['damage_level'],
            'location': action['location'],
            'description': 'Synced from van-images storage bucket',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }),
        );

        if (addResponse.statusCode == 201) {
          added++;
          print(
              '   ✅ Added: ${action['file_name']} to van ${action['van_number']}');
        } else {
          print(
              '   ❌ Add failed for ${action['file_name']}: ${addResponse.statusCode}');
          print('   Response: ${addResponse.body}');
        }
      } catch (e) {
        print('   ❌ Add error for ${action['file_name']}: $e');
      }
    }

    // =============================================================================
    // STEP 6: Final verification
    // =============================================================================
    print('\n🔍 STEP 6: Final verification...');

    final finalResponse = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/van_images?select=id,van_id,image_url'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    if (finalResponse.statusCode == 200) {
      final finalRecords = json.decode(finalResponse.body) as List;
      final finalStorageUrls = finalRecords
          .where((r) => r['image_url'].toString().contains(
              'lcvbagsksedduygdzsca.supabase.co/storage/v1/object/public/van-images'))
          .length;
      final finalPlaceholderUrls = finalRecords.length - finalStorageUrls;

      print('✅ Final state:');
      print('   📊 Total records: ${finalRecords.length}');
      print('   ✅ Storage URLs: $finalStorageUrls');
      print('   ❌ Placeholder URLs: $finalPlaceholderUrls');
    }

    print('\n🎉 SYNC COMPLETED!');
    print('   ✅ Updated: $updated records');
    print('   ✅ Added: $added records');
    print(
        '   🔄 Your van_images table is now synced with van-images storage bucket!');
  } catch (e) {
    print('❌ Error during sync: $e');
  }
}

String _guessDamageType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.contains('dent')) return 'dent';
  if (lower.contains('scratch')) return 'scratch';
  if (lower.contains('paint')) return 'paint_damage';
  if (lower.contains('crack')) return 'crack';
  if (lower.contains('rust')) return 'rust';
  if (lower.contains('bumper')) return 'dent';
  if (lower.contains('panel')) return 'dent';
  return 'other';
}

String _guessLocation(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.contains('front')) return 'front';
  if (lower.contains('rear') || lower.contains('back')) return 'rear';
  if (lower.contains('side')) return 'side';
  if (lower.contains('door')) return 'side';
  if (lower.contains('bumper')) {
    return lower.contains('front') ? 'front' : 'rear';
  }
  return 'unknown';
}

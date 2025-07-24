import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    print('🧹 Cleaning van_images table...');
    print('🎯 Goal: Remove Unsplash URLs, keep only storage bucket URLs');

    const supabaseUrl = 'https://lcvbagsksedduygdzsca.supabase.co';
    const supabaseKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY2MTI0OTgsImV4cCI6MjAyMjE4ODQ5OH0.vkGmkfzumkRacnhsHm2zx-YKE8uuDojT4ZcJBGdKrfE';

    // Step 1: Analyze current van_images table
    print('\n📊 Step 1: Analyzing current van_images table...');
    final analysisResponse = await http.get(
      Uri.parse(
          '$supabaseUrl/rest/v1/van_images?select=id,van_id,image_url&order=created_at.desc'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Content-Type': 'application/json',
      },
    );

    if (analysisResponse.statusCode != 200) {
      print('❌ Failed to fetch van_images: ${analysisResponse.statusCode}');
      print('Response: ${analysisResponse.body}');
      return;
    }

    final List<dynamic> records = json.decode(analysisResponse.body);
    print('✅ Found ${records.length} records in van_images table');

    List<String> idsToDelete = [];
    int storageUrls = 0;
    int unsplashUrls = 0;

    print('\n🔍 Analyzing URLs...');
    for (var record in records) {
      final id = record['id'] as String;
      final url = record['image_url'] as String;
      final vanId = record['van_id'] as String;

      if (url.contains(
          'lcvbagsksedduygdzsca.supabase.co/storage/v1/object/public/van-images')) {
        storageUrls++;
        print('   ✅ KEEP: $id - Storage URL');
      } else if (url.contains('images.unsplash.com')) {
        unsplashUrls++;
        idsToDelete.add(id);
        print('   ❌ DELETE: $id - Unsplash URL (van: $vanId)');
      } else {
        idsToDelete.add(id);
        print('   ❌ DELETE: $id - Other URL (van: $vanId)');
      }
    }

    print('\n📈 Summary:');
    print('   ✅ Valid storage URLs to keep: $storageUrls');
    print('   ❌ Invalid URLs to delete: ${idsToDelete.length}');

    if (idsToDelete.isEmpty) {
      print('\n🎉 Great! All URLs already point to your storage bucket!');
      return;
    }

    // Step 2: Ask for confirmation
    print('\n⚠️ CONFIRMATION REQUIRED:');
    print(
        'This will DELETE ${idsToDelete.length} records with non-storage URLs.');
    print('Only records with van-images storage bucket URLs will remain.');
    print('');
    print('Records to be deleted:');
    for (var id in idsToDelete.take(5)) {
      print('   - $id');
    }
    if (idsToDelete.length > 5) {
      print('   ... and ${idsToDelete.length - 5} more');
    }
    print('');
    print(
        '💡 NOTE: This is SAFER than a full resync since we keep known good data');
    print('');
    print('🚨 TYPE "DELETE" to proceed (anything else will cancel):');

    // For automation, let's run a dry-run first
    print('🔍 DRY RUN: Would delete ${idsToDelete.length} records');
    print('✅ Run completed in dry-run mode');
    print('');
    print('To actually perform the cleanup:');
    print('1. Uncomment the deletion code in this script');
    print('2. Re-run the script');

    // Uncomment the code below to actually perform the deletion:
    /*
    print('\n🗑️ Step 3: Deleting invalid records...');
    int deleted = 0;
    
    for (var id in idsToDelete) {
      try {
        final deleteResponse = await http.delete(
          Uri.parse('$supabaseUrl/rest/v1/van_images?id=eq.$id'),
          headers: {
            'apikey': supabaseKey,
            'Authorization': 'Bearer $supabaseKey',
            'Content-Type': 'application/json',
          },
        );
        
        if (deleteResponse.statusCode == 204) {
          deleted++;
          print('   ✅ Deleted record $id');
        } else {
          print('   ❌ Failed to delete $id: ${deleteResponse.statusCode}');
        }
      } catch (e) {
        print('   ❌ Error deleting $id: $e');
      }
    }
    
    print('\n🎉 Cleanup completed!');
    print('   ✅ Deleted: $deleted records');
    print('   ✅ Remaining: $storageUrls storage bucket URLs');
    */
  } catch (e) {
    print('❌ Error during cleanup: $e');
  }
}

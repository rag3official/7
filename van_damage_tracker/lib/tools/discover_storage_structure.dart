import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

// Script to discover existing storage buckets and their structure
void main() async {
  try {
    print('🔍 Discovering existing Supabase storage structure...');

    // Your Supabase credentials
    final supabaseUrl = Platform.environment['SUPABASE_URL'] ??
        'https://lcvbagsksedduygdzsca.supabase.co';
    final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'] ??
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY2MTI0OTgsImV4cCI6MjAyMjE4ODQ5OH0.vkGmkfzumkRacnhsHm2zx-YKE8uuDojT4ZcJBGdKrfE';

    print('🔗 Using Supabase URL: $supabaseUrl');

    // Step 1: List all storage buckets
    print('\n📁 Step 1: Discovering all storage buckets...');
    final bucketsResponse = await http.get(
      Uri.parse('$supabaseUrl/storage/v1/bucket'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    if (bucketsResponse.statusCode != 200) {
      print('❌ Failed to list storage buckets: ${bucketsResponse.statusCode}');
      print('Response: ${bucketsResponse.body}');
      return;
    }

    final List<dynamic> buckets = json.decode(bucketsResponse.body);
    print('✅ Found ${buckets.length} storage buckets:');

    if (buckets.isEmpty) {
      print(
          '❌ No storage buckets found. You need to create a bucket and upload images first.');
      return;
    }

    for (var bucket in buckets) {
      final bucketName = bucket['name'];
      final isPublic = bucket['public'] ?? false;
      print('   📦 $bucketName (${isPublic ? 'public' : 'private'})');
    }

    // Step 2: Examine each bucket for van-related content
    print('\n🔍 Step 2: Examining bucket contents for van images...');

    for (var bucket in buckets) {
      final bucketName = bucket['name'];
      print('\n📂 Examining bucket: $bucketName');

      // List files in this bucket
      final filesResponse = await http.get(
        Uri.parse('$supabaseUrl/storage/v1/object/list/$bucketName'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
        },
      );

      if (filesResponse.statusCode == 200) {
        final List<dynamic> files = json.decode(filesResponse.body);
        print('   📄 Found ${files.length} items in $bucketName');

        if (files.isEmpty) {
          print('   ⚠️ Bucket is empty');
          continue;
        }

        // Analyze file structure
        Map<String, List<String>> folderStructure = {};
        List<String> rootFiles = [];

        for (var file in files) {
          final fileName = file['name'];

          if (fileName.contains('/')) {
            // File is in a folder
            final parts = fileName.split('/');
            final folderName = parts[0];
            final actualFileName = parts.sublist(1).join('/');

            if (!folderStructure.containsKey(folderName)) {
              folderStructure[folderName] = [];
            }
            folderStructure[folderName]!.add(actualFileName);
          } else {
            // File is in root
            rootFiles.add(fileName);
          }
        }

        // Display structure
        if (rootFiles.isNotEmpty) {
          print('   📄 Root files (${rootFiles.length}):');
          for (var file in rootFiles.take(5)) {
            print('      - $file');
          }
          if (rootFiles.length > 5) {
            print('      ... and ${rootFiles.length - 5} more files');
          }
        }

        if (folderStructure.isNotEmpty) {
          print('   📁 Folder structure:');
          folderStructure.forEach((folder, files) {
            print('      📂 $folder/ (${files.length} files)');

            // Check if this looks like a van folder
            final looksLikeVan = folder.toLowerCase().contains('van') ||
                RegExp(r'\d+').hasMatch(folder);

            if (looksLikeVan) {
              print('         🚐 ← Looks like a van folder!');
            }

            // Show first few files as examples
            for (var file in files.take(3)) {
              final fullUrl =
                  '$supabaseUrl/storage/v1/object/public/$bucketName/$folder/$file';
              print('         - $file');
              print('           🔗 $fullUrl');
            }
            if (files.length > 3) {
              print('         ... and ${files.length - 3} more files');
            }
          });
        }

        // Recommendations
        print('   💡 Analysis:');
        if (bucketName.toLowerCase().contains('van') ||
            folderStructure.keys
                .any((folder) => folder.toLowerCase().contains('van'))) {
          print('      ✅ This bucket appears to contain van-related images');
          print('      📝 Recommended for van damage tracking');
        } else {
          print('      ⚠️ This bucket may not contain van images');
        }
      } else {
        print(
            '   ❌ Failed to list files in $bucketName: ${filesResponse.statusCode}');
      }
    }

    // Step 3: Provide recommendations
    print('\n🎯 Step 3: Recommendations');
    print('Based on the analysis above:');
    print('1. 📦 Choose the bucket that contains your van images');
    print('2. 📁 Note the folder structure (van_XX/ or similar)');
    print('3. 🔧 I can modify the sync script to use your specific structure');
    print('');
    print('Please tell me:');
    print('- Which bucket contains your van images?');
    print(
        '- What folder naming pattern do you use? (e.g., van_92/, vehicle_001/, etc.)');
    print('');
  } catch (e) {
    print('❌ Error during discovery: $e');
  }
}

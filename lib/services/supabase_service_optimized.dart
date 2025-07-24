import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/van.dart';

class SupabaseServiceOptimized {
  final _client = Supabase.instance.client;
  StreamSubscription<List<Van>>? _vanSubscription;

  // Initialize the database
  Future<bool> initializeDatabase() async {
    try {
      debugPrint('🔍 Attempting to connect to Supabase...');
      debugPrint('🌐 Running on: ${kIsWeb ? 'web' : 'mobile'}');

      // Check if we can connect to Supabase using van_profiles table
      await _client
          .from('van_profiles')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 10));
      debugPrint('✅ Successfully connected to van_profiles table');
      return true;
    } catch (e) {
      debugPrint('❌ Error initializing database: $e');
      debugPrint('🔧 Error type: ${e.runtimeType}');
      return false;
    }
  }

  // Subscribe to van updates using new schema
  void subscribeToVans(Function(List<Van>) onVansUpdated) {
    debugPrint('Setting up van subscription...');

    // Unsubscribe from any existing subscription
    _vanSubscription?.cancel();

    // Set up new subscription using stream for van_profiles table (without images to prevent timeout)
    _vanSubscription = _client
        .from('van_profiles')
        .stream(primaryKey: ['id'])
        .map((data) => data.map((json) => Van.fromNewSchema(json)).toList())
        .listen(
          onVansUpdated,
          onError: (error) {
            debugPrint('Error in van subscription: $error');
          },
        );
  }

  // Unsubscribe from van updates
  void unsubscribeFromVans() {
    _vanSubscription?.cancel();
    _vanSubscription = null;
  }

  // Optimized fetch that prevents timeouts by fetching data in stages
  Future<List<Van>> fetchVans({bool forceRefresh = false}) async {
    try {
      debugPrint('🔍 Attempting to fetch vans from Supabase...');
      debugPrint('🌐 Running on: ${kIsWeb ? 'web' : 'mobile'}');

      // First, fetch van profiles without images to avoid timeout - with timeout protection
      final response = await _client
          .from('van_profiles')
          .select(
              'id, van_number, make, model, year, license_plate, vin, status, current_driver_id, created_at, updated_at')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15)); // 15 second timeout

      debugPrint(
          '✅ Successfully fetched ${response.length} van profiles from database');

      if (response.isNotEmpty) {
        // Safely convert van_number to string
        final firstVan = response[0];
        final vanNumber = firstVan['van_number']?.toString() ?? 'Unknown';
        final make = firstVan['make']?.toString() ?? 'Unknown';
        debugPrint('📝 First van: $vanNumber ($make)');
      }

      List<Van> vans = [];

      // Process each van and fetch images separately to avoid timeouts
      for (var vanData in response) {
        try {
          // Create van without images first
          Van van = Van.fromNewSchema(vanData);

          // Fetch images for this van separately with timeout protection
          try {
            debugPrint('🖼️ Attempting to fetch images for van ${van.id}...');

            final imageResponse = await _client
                .from('van_images')
                .select('image_url, van_number')
                .eq('van_id', van.id)
                .limit(5) // Limit to 5 images to prevent large queries
                .timeout(const Duration(seconds: 10)); // 10 second timeout for images

            debugPrint(
                '✅ Successfully fetched ${imageResponse.length} images for van ${van.id}');

            List<String> imageUrls = [];
            for (var img in imageResponse) {
              final imageUrl = img['image_url'] as String?;
              if (imageUrl != null) {
                debugPrint(
                    '📷 Image ${imageResponse.indexOf(img) + 1}: ${imageUrl.substring(0, 50)}...');

                // Handle base64 images
                if (imageUrl.startsWith('data:image/')) {
                  // For base64 images, we'll process them for display
                  try {
                    // Extract the base64 part
                    final base64Data = imageUrl.split(',')[1];
                    final contentType = imageUrl.split(';')[0].split(':')[1];
                    final vanNumber = img['van_number']
                        ?.toString(); // Convert to string safely

                    debugPrint('🖼️ Processing base64 image:');
                    debugPrint('  - image_data length: ${base64Data.length}');
                    debugPrint('  - content_type: $contentType');
                    debugPrint('  - van_number: $vanNumber');

                    // Decode base64 to verify it's valid
                    final imageBytes =
                        Uri.parse(imageUrl).data!.contentAsBytes();
                    debugPrint(
                        '  ✅ Successfully decoded base64 image (${imageBytes.length} bytes)');

                    imageUrls.add(imageUrl);
                  } catch (e) {
                    debugPrint('❌ Error processing base64 image: $e');
                  }
                } else {
                  imageUrls.add(imageUrl);
                }
              }
            }

            // Update van with images
            van = van.copyWith(imageUrls: imageUrls);
          } catch (imageError) {
            debugPrint(
                '⚠️ Error fetching images for van ${van.id}: $imageError');
            // Continue without images rather than failing completely
          }

          vans.add(van);
          debugPrint('✅ Processed van: ${van.vanNumber}');
        } catch (vanError) {
          debugPrint(
              '❌ Error processing van ${vanData['van_number']}: $vanError');
          continue; // Skip this van and continue with others
        }
      }

      debugPrint('✅ Successfully processed ${vans.length} vans');
      return vans;
    } catch (e) {
      debugPrint('❌ Error fetching vans: $e');
      debugPrint('🔧 Error type: ${e.runtimeType}');

      // Handle timeout specifically
      if (e is TimeoutException) {
        throw Exception(
            'Request timed out - database may be overloaded. Please try again.');
      }

      throw Exception('Failed to fetch vans: ${e.toString()}');
    }
  }

  Future<List<Van>> getVans() async {
    return fetchVans();
  }

  Future<Van?> getVan(String id) async {
    try {
      final response = await _client.from('van_profiles').select('''
            *,
            van_images(*),
            driver_profiles!van_profiles_current_driver_id_fkey(*)
          ''').eq('id', id).single().timeout(const Duration(seconds: 10));

      return Van.fromNewSchema(response);
    } catch (e) {
      debugPrint('Error getting van: $e');
      rethrow;
    }
  }

  Future<Van> createVan(
      String name, String status, String? maintenanceNotes) async {
    try {
      final van = {
        'van_number': name, // Assuming name is van_number
        'status': status,
        'make': 'Unknown',
        'model': 'Unknown',
      };

      final response =
          await _client.from('van_profiles').insert(van).select().single();

      return Van.fromNewSchema(response);
    } catch (e) {
      debugPrint('Error creating van: $e');
      rethrow;
    }
  }

  Future<Van> updateVan(String id, Map<String, dynamic> data) async {
    try {
      final response = await _client
          .from('van_profiles')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return Van.fromNewSchema(response);
    } catch (e) {
      debugPrint('Error updating van: $e');
      rethrow;
    }
  }

  Future<Van> saveVan(Van van) async {
    try {
      final data = van.toNewSchemaJson();
      final response =
          await _client.from('van_profiles').upsert(data).select().single();

      return Van.fromNewSchema(response);
    } catch (e) {
      debugPrint('Error saving van: $e');
      rethrow;
    }
  }

  Future<void> deleteVan(String vanId) async {
    try {
      await _client.from('van_profiles').delete().eq('id', vanId);
    } catch (e) {
      debugPrint('Error deleting van: $e');
      rethrow;
    }
  }

  Future<String> uploadImage(String vanId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = 'van_images/$vanId/$fileName';

      // Note: This will still fail due to storage constraints
      // The bot handles image uploads differently by storing base64 in database
      await _client.storage.from('van-images').upload(filePath, imageFile);

      final imageUrl =
          _client.storage.from('van-images').getPublicUrl(filePath);

      await _client.from('van_images').insert({
        'van_id': vanId,
        'image_url': imageUrl,
        'file_path': filePath,
      });

      return imageUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  Future<void> deleteImage(String vanId, String imageUrl) async {
    try {
      await _client.from('van_images').delete().eq('image_url', imageUrl);
    } catch (e) {
      debugPrint('Error deleting image: $e');
      rethrow;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnhancedDriverService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Van Status Management
  static const List<String> availableStatuses = [
    'active',
    'maintenance',
    'out_of_service'
  ];

  static const Map<String, Map<String, dynamic>> statusConfig = {
    'active': {
      'label': 'Active',
      'color': 'green',
      'icon': 'check_circle',
      'description': 'Van is operational and available for use'
    },
    'maintenance': {
      'label': 'Maintenance',
      'color': 'orange',
      'icon': 'build',
      'description': 'Van is currently undergoing maintenance or repairs'
    },
    'out_of_service': {
      'label': 'Out of Service',
      'color': 'red',
      'icon': 'warning',
      'description': 'Van is not operational and not available for use'
    },
  };

  // Update van status - SIMPLIFIED VERSION WITH DEBUGGING
  static Future<bool> updateVanStatus(int vanNumber, String newStatus,
      {String? reason, String? notes}) async {
    try {
      print('🔄 Starting status update for van #$vanNumber to: $newStatus');
      debugPrint(
          '🔄 Starting status update for van #$vanNumber to: $newStatus');

      if (!availableStatuses.contains(newStatus)) {
        print('❌ Invalid status: $newStatus');
        throw Exception('Invalid status: $newStatus');
      }

      // First, let's check what the current status is
      print('📋 Getting current van data...');
      final currentVan = await _supabase
          .from('van_profiles')
          .select('van_number, status, id')
          .eq('van_number', vanNumber)
          .maybeSingle();

      if (currentVan == null) {
        print('❌ Van #$vanNumber not found in database');
        debugPrint('❌ Van #$vanNumber not found in database');
        throw Exception('Van #$vanNumber not found');
      }

      print('📋 Current van data: $currentVan');
      print('📋 Current status: ${currentVan['status']}');
      print('📋 Van ID: ${currentVan['id']}');
      debugPrint('📋 Current van data: $currentVan');
      debugPrint('📋 Current status: ${currentVan['status']}');
      debugPrint('📋 Van ID: ${currentVan['id']}');

      // Try updating by ID instead of van_number for more reliability
      print('🔄 Attempting database update...');
      final response = await _supabase
          .from('van_profiles')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', currentVan['id'])
          .select('van_number, status, updated_at');

      print('🔄 Update response: $response');
      debugPrint('🔄 Update response: $response');

      if (response.isEmpty) {
        print('❌ Update failed - no rows returned');
        debugPrint('❌ Update failed - no rows returned');
        throw Exception('Update failed - no rows affected');
      }

      final updatedVan = response.first;
      print('✅ Update successful!');
      print('📋 New status: ${updatedVan['status']}');
      print('📋 Updated at: ${updatedVan['updated_at']}');
      debugPrint('✅ Update successful!');
      debugPrint('📋 New status: ${updatedVan['status']}');
      debugPrint('📋 Updated at: ${updatedVan['updated_at']}');

      // Verify the update actually happened
      print('🔍 Verifying update with fresh database query...');
      final verifyResponse = await _supabase
          .from('van_profiles')
          .select('van_number, status, updated_at')
          .eq('van_number', vanNumber)
          .single();

      print('🔍 Verification check: $verifyResponse');
      debugPrint('🔍 Verification check: $verifyResponse');

      if (verifyResponse['status'] != newStatus) {
        print(
            '❌ Verification failed! Status is still: ${verifyResponse['status']}');
        debugPrint(
            '❌ Verification failed! Status is still: ${verifyResponse['status']}');
        throw Exception('Status update verification failed');
      }

      print(
          '✅ Successfully updated and verified van #$vanNumber status to: $newStatus');
      debugPrint(
          '✅ Successfully updated and verified van #$vanNumber status to: $newStatus');
      return true;
    } catch (e) {
      print('❌ Error updating van status: $e');
      debugPrint('❌ Error updating van status: $e');
      rethrow;
    }
  }

  // Get van status with details
  static Future<Map<String, dynamic>?> getVanStatus(int vanNumber) async {
    try {
      final response = await _supabase
          .from('van_profiles')
          .select('id, van_number, status, updated_at, notes')
          .eq('van_number', vanNumber)
          .single();

      final status = response['status']?.toString() ?? 'active';
      final config = statusConfig[status] ?? statusConfig['active']!;

      return {
        ...response,
        'status_config': config,
        'status_label': config['label'],
        'status_color': config['color'],
        'status_icon': config['icon'],
        'status_description': config['description'],
      };
    } catch (e) {
      debugPrint('❌ Error getting van status: $e');
      return null;
    }
  }

  // Get all vans with their status
  static Future<List<Map<String, dynamic>>> getVansWithStatus() async {
    try {
      final response = await _supabase
          .from('van_profiles')
          .select('id, van_number, make, model, status, updated_at, notes')
          .order('van_number');

      return response.map<Map<String, dynamic>>((van) {
        final status = van['status']?.toString() ?? 'active';
        final config = statusConfig[status] ?? statusConfig['active']!;

        return {
          ...van,
          'status_config': config,
          'status_label': config['label'],
          'status_color': config['color'],
          'status_icon': config['icon'],
          'status_description': config['description'],
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting vans with status: $e');
      return [];
    }
  }

  // Get driver profile with upload statistics
  static Future<Map<String, dynamic>?> getDriverProfile(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_profiles')
          .select()
          .eq('id', driverId)
          .single();

      return response;
    } catch (e) {
      debugPrint('Error fetching driver profile: $e');
      return null;
    }
  }

  // Get driver's images grouped by van for driver profile page
  static Future<List<Map<String, dynamic>>> getDriverImagesByVan(
      String driverId) async {
    try {
      debugPrint('🔍 Fetching images for driver: $driverId');

      // Get all images by this driver with van details
      final response = await _supabase.from('van_images').select('''
            id,
            van_number,
            van_id,
            image_data,
            image_url,
            van_damage,
            van_rating,
            van_side,
            damage_type,
            damage_severity,
            damage_location,
            created_at,
            uploaded_by,
            file_size,
            content_type,
            van_profiles!van_images_van_id_fkey (
              id,
              van_number,
              make,
              model,
              status
            )
          ''').eq('driver_id', driverId).order('created_at', ascending: false);

      debugPrint('📊 Found ${response.length} images for driver $driverId');

      // Group images by van number with deduplication
      Map<int, List<Map<String, dynamic>>> groupedImages = {};

      for (final image in response) {
        final vanNumber = image['van_number'] as int? ??
            image['van_profiles']?['van_number'] as int? ??
            0;

        debugPrint(
            '📷 Processing image: van_number=$vanNumber, has_image_data=${image['image_data'] != null}');
        debugPrint(
            '    Image data preview: ${image['image_data']?.toString().substring(0, 50) ?? 'null'}...');
        debugPrint('    Image URL: ${image['image_url']}');
        debugPrint('    Content type: ${image['content_type']}');
        debugPrint('    File size: ${image['file_size']}');
        debugPrint('    Van profile: ${image['van_profiles']}');

        if (vanNumber > 0) {
          if (!groupedImages.containsKey(vanNumber)) {
            groupedImages[vanNumber] = [];
          }

          // Check for duplicates based on file size and content type
          final fileSize = image['file_size'] as int? ?? 0;
          final contentType = image['content_type']?.toString() ?? '';
          final createdAt = image['created_at']?.toString() ?? '';

          bool isDuplicate = false;
          for (final existingImage in groupedImages[vanNumber]!) {
            final existingFileSize = existingImage['file_size'] as int? ?? 0;
            final existingContentType =
                existingImage['content_type']?.toString() ?? '';
            final existingCreatedAt =
                existingImage['created_at']?.toString() ?? '';

            // Consider it a duplicate if file size, content type match and created within 1 minute
            if (fileSize == existingFileSize &&
                contentType == existingContentType &&
                fileSize > 0) {
              final timeDiff = DateTime.tryParse(createdAt)
                      ?.difference(DateTime.tryParse(existingCreatedAt) ??
                          DateTime.now())
                      ?.inMinutes
                      ?.abs() ??
                  999;
              if (timeDiff <= 1) {
                isDuplicate = true;
                debugPrint(
                    '🔄 Duplicate image detected: size=$fileSize, type=$contentType, time_diff=${timeDiff}min');
                break;
              }
            }
          }

          if (!isDuplicate) {
            groupedImages[vanNumber]!.add(image);
          } else {
            debugPrint('⚠️ Skipping duplicate image for van $vanNumber');
          }
        }
      }

      // Convert to list format expected by UI
      List<Map<String, dynamic>> result = [];
      groupedImages.forEach((vanNumber, images) {
        final firstImage = images.first;
        final vanProfile = firstImage['van_profiles'];

        debugPrint(
            '🚐 Van $vanNumber: ${images.length} images, make=${vanProfile?['make']}');

        result.add({
          'van_number': vanNumber,
          'van_make': vanProfile?['make'] ?? 'Unknown',
          'van_model': vanProfile?['model'] ?? 'Unknown',
          'image_count': images.length,
          'images': images,
          'latest_image': images.first,
        });
      });

      debugPrint(
          '✅ Returning ${result.length} van groups for driver $driverId');
      return result;
    } catch (e) {
      debugPrint('❌ Error fetching driver images by van: $e');
      return [];
    }
  }

  // Get all images uploaded by a driver with van details
  static Future<List<Map<String, dynamic>>> getDriverImagesWithVanDetails(
      String driverId) async {
    try {
      final response = await _supabase.from('van_images').select('''
            *,
            van_profiles!van_images_van_id_fkey (
              id,
              van_number,
              make,
              model,
              status
            )
          ''').eq('driver_id', driverId).order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching driver images with van details: $e');
      return [];
    }
  }

  // Get van profile with images and driver information
  static Future<Map<String, dynamic>?> getVanProfileWithImages(
      int vanNumber) async {
    try {
      // Get van profile
      final vanProfile = await _supabase
          .from('van_profiles')
          .select()
          .eq('van_number', vanNumber)
          .single();

      // Get images for this van with driver details
      final images = await _supabase
          .from('van_images')
          .select('''
            id,
            van_number,
            image_url,
            image_data,
            van_damage,
            van_rating,
            van_side,
            damage_type,
            damage_severity,
            damage_location,
            created_at,
            uploaded_by,
            file_size,
            content_type,
            driver_profiles!van_images_driver_id_fkey(
              id,
              driver_name,
              slack_real_name,
              slack_display_name,
              phone,
              email
            )
          ''')
          .eq('van_number', vanNumber)
          .order('created_at', ascending: false);

      return {
        // Flatten van profile data with correct field names for Flutter
        'van_make': vanProfile['make'] ?? 'Unknown',
        'van_model': vanProfile['model'] ?? 'Unknown',
        'van_year': vanProfile['year'] ?? 'Unknown',
        'van_number': vanProfile['van_number'],
        'van_status': vanProfile['status'] ?? 'active',
        'status':
            vanProfile['status'] ?? 'active', // Add this for UI compatibility
        'alerts':
            vanProfile['alerts'] ?? 'no', // Alert flag for damage level 2/3
        'updated_at': vanProfile['updated_at'],
        'notes': vanProfile['notes'],
        'van_id': vanProfile['id'],
        // Keep nested structure for backward compatibility
        'van_profile': vanProfile,
        'images': images,
        'image_count': images.length,
      };
    } catch (e) {
      debugPrint('Error fetching van profile with images: $e');
      return null;
    }
  }

  // Get all drivers with their upload statistics
  static Future<List<Map<String, dynamic>>> getAllDriverProfiles() async {
    try {
      final response = await _supabase
          .from('driver_profiles')
          .select()
          .order('total_uploads', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all driver profiles: $e');
      return [];
    }
  }

  // Get recent uploads across all drivers
  static Future<List<Map<String, dynamic>>> getRecentUploads(
      {int limit = 20}) async {
    try {
      final response = await _supabase.from('van_images').select('''
            *,
            driver_profiles!van_images_driver_id_fkey (
              id,
              driver_name,
              slack_real_name
            ),
            van_profiles!van_images_van_id_fkey (
              id,
              van_number,
              make,
              model
            )
          ''').order('created_at', ascending: false).limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching recent uploads: $e');
      return [];
    }
  }

  // Link existing images to drivers (admin function)
  static Future<int> linkImagesToDrivers() async {
    try {
      final response = await _supabase.rpc('link_images_to_drivers');
      return response as int? ?? 0;
    } catch (e) {
      debugPrint('Error linking images to drivers: $e');
      return 0;
    }
  }

  // Get driver statistics
  static Future<Map<String, dynamic>> getDriverStatistics(
      String driverId) async {
    try {
      final profile = await getDriverProfile(driverId);
      if (profile == null) return {};

      final imagesByVan = await getDriverImagesByVan(driverId);

      return {
        'total_uploads': profile['total_uploads'] ?? 0,
        'last_upload_date': profile['last_upload_date'],
        'van_breakdown': imagesByVan,
        'member_since': profile['created_at'],
        'driver_name': profile['driver_name'],
        'slack_real_name': profile['slack_real_name'],
        'slack_display_name': profile['slack_display_name'],
        'phone': profile['phone'],
        'email': profile['email'],
      };
    } catch (e) {
      debugPrint('Error getting driver statistics: $e');
      return {};
    }
  }
}

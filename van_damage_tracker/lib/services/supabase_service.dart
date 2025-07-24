import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/van.dart';
import '../models/maintenance_record.dart';
import '../main.dart';
import '../config/environment.dart';
import '../models/van_image.dart';
import 'package:crypto/crypto.dart';

// Get the Supabase client instance
final supabase = Supabase.instance.client;

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;

  late final SupabaseClient _client;

  // For clients that use a service role key
  late final SupabaseClient? _effectiveClient;

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      if (value is num || (value is String && double.tryParse(value) != null)) {
        // Handle Unix timestamp (convert to milliseconds if in seconds)
        final timestamp = double.parse(value.toString());
        if (timestamp < 1e12) {
          // If timestamp is in seconds
          return DateTime.fromMillisecondsSinceEpoch(
              (timestamp * 1000).round());
        } else {
          // If timestamp is in milliseconds
          return DateTime.fromMillisecondsSinceEpoch(timestamp.round());
        }
      }

      // Try parsing as ISO 8601
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        // Not ISO 8601, try other formats
      }

      // Try parsing as MM/dd/yyyy HH:mm:ss
      final parts = value.toString().split(' ');
      if (parts.length == 2) {
        final dateParts = parts[0].split('/');
        final timeParts = parts[1].split(':');
        if (dateParts.length == 3 && timeParts.length == 3) {
          return DateTime(
            int.parse(dateParts[2]), // year
            int.parse(dateParts[0]), // month
            int.parse(dateParts[1]), // day
            int.parse(timeParts[0]), // hour
            int.parse(timeParts[1]), // minute
            int.parse(timeParts[2]), // second
          );
        }
      }

      // Try parsing as MM/dd/yyyy
      final dateParts = value.toString().split('/');
      if (dateParts.length == 3) {
        return DateTime(
          int.parse(dateParts[2]), // year
          int.parse(dateParts[0]), // month
          int.parse(dateParts[1]), // day
        );
      }

      debugPrint('Failed to parse date: ${value.toString()}');
      return DateTime.now();
    } catch (e) {
      debugPrint('Error parsing date: $e');
      debugPrint('Value was: $value');
      return DateTime.now();
    }
  }

  // Standard constructor using the default client
  SupabaseService._internal() {
    _client = SupabaseClient(
      Environment.supabaseUrl,
      Environment.supabaseAnonKey,
    );
    _effectiveClient = _client;
    debugPrint('SupabaseService initialized with standard client');
  }

  // Initialize with service role for admin operations
  Future<void> initializeWithServiceRole(
    String url,
    String serviceRoleKey,
  ) async {
    if (serviceRoleKey.isNotEmpty) {
      _effectiveClient = SupabaseClient(url, serviceRoleKey);
      debugPrint('SupabaseService initialized with service role key');
    }
  }

  void _log(String message) {
    debugPrint('[SupabaseService] $message');
  }

  // Fetch all vans from the new schema (van_profiles table)
  Future<List<Van>> fetchVans({bool forceRefresh = false}) async {
    try {
      _log('🔍 Attempting to fetch vans from Supabase...');
      _log('🌐 Running on: ${kIsWeb ? 'web' : Platform.operatingSystem}');

      // Query van_profiles with related data
      final response = await _client.from('van_profiles').select('''
            *,
            driver_profiles!van_profiles_current_driver_id_fkey (
              id,
              driver_name,
              email,
              slack_user_id
            ),
            van_images!van_images_van_id_fkey (
              id,
              image_url,
              image_data,
              van_damage,
              van_rating,
              file_size,
              content_type,
              created_at
            )
          ''').order('created_at');

      _log('✅ Successfully fetched ${response.length} van profiles');

      List<Van> vans = [];
      for (var item in response) {
        try {
          // Parse van profile data
          final vanProfile = item;
          final driverProfile = vanProfile['driver_profiles'];
          final vanImages = vanProfile['van_images'] as List? ?? [];

          // Convert van images to VanImage objects and URLs
          List<VanImage> vanImageObjects = [];
          List<String> imageUrls = [];

          for (var imageData in vanImages) {
            final createdAt = _parseDateTime(imageData['created_at']);

            // Create VanImage object
            final vanImage = VanImage(
              id: imageData['id']?.toString() ?? '',
              vanId: vanProfile['id']?.toString() ?? '',
              imageUrl: imageData['image_url']?.toString() ?? '',
              uploadedAt: createdAt,
              damageLevel: imageData['van_rating'] as int? ?? 0,
              damageType: imageData['van_damage']?.toString(),
              createdAt: createdAt,
              updatedAt: createdAt,
            );
            vanImageObjects.add(vanImage);

            // Handle image URL
            if (imageData['image_data'] != null) {
              // Base64 image stored in database
              final base64Data = imageData['image_data'] as String;
              if (base64Data.startsWith('data:')) {
                imageUrls.add(base64Data);
              } else {
                // Add data URL prefix if missing
                final contentType = imageData['content_type'] ?? 'image/jpeg';
                imageUrls.add('data:$contentType;base64,$base64Data');
              }
            } else if (imageData['image_url'] != null) {
              // Traditional URL
              imageUrls.add(imageData['image_url'] as String);
            }
          }

          // Create Van object with new schema data
          final van = Van(
            id: vanProfile['id']?.toString() ?? '',
            plateNumber: vanProfile['van_number']?.toString() ?? '',
            model: vanProfile['make']?.toString() ?? 'Unknown',
            year: vanProfile['model']?.toString() ?? 'Unknown',
            status: vanProfile['status']?.toString() ?? 'Active',
            lastInspection: _parseDateTime(vanProfile['created_at']),
            notes: vanProfile['notes']?.toString() ?? '',
            url: imageUrls.isNotEmpty ? imageUrls.first : '',
            driverName: driverProfile?['driver_name']?.toString() ?? '',
            damage: _getLatestDamageDescription(vanImages),
            damageDescription: _getLatestDamageDescription(vanImages),
            rating: _getLatestRating(vanImages).toString(),
            images: vanImageObjects,
            maintenanceHistory: [], // TODO: Add maintenance records if needed
          );

          vans.add(van);
          _log('✅ Processed van: ${van.plateNumber}');
        } catch (e) {
          _log('❌ Error processing van profile: $e');
          debugPrint('Van profile data: $item');
        }
      }

      _log('✅ Successfully processed ${vans.length} vans');
      return vans;
    } catch (e) {
      _log('❌ Error fetching vans: $e');
      _log('🔧 Error type: ${e.runtimeType}');

      // If it's a PostgrestException, provide more details
      if (e is PostgrestException) {
        _log('📋 PostgrestException details:');
        _log('   Message: ${e.message}');
        _log('   Code: ${e.code}');
        _log('   Details: ${e.details}');
        _log('   Hint: ${e.hint}');
      }

      throw Exception('Failed to fetch vans: $e');
    }
  }

  // Helper method to get latest damage description from images
  String _getLatestDamageDescription(List vanImages) {
    if (vanImages.isEmpty) return '';

    try {
      // Sort by created_at and get the latest
      final sortedImages = List.from(vanImages);
      sortedImages.sort((a, b) {
        final aDate = _parseDateTime(a['created_at']);
        final bDate = _parseDateTime(b['created_at']);
        return bDate.compareTo(aDate); // Descending order
      });

      final latestImage = sortedImages.first;
      return latestImage['van_damage']?.toString() ?? 'No damage description';
    } catch (e) {
      return 'No damage description';
    }
  }

  // Helper method to get latest rating from images
  double _getLatestRating(List vanImages) {
    if (vanImages.isEmpty) return 0.0;

    try {
      // Sort by created_at and get the latest
      final sortedImages = List.from(vanImages);
      sortedImages.sort((a, b) {
        final aDate = _parseDateTime(a['created_at']);
        final bDate = _parseDateTime(b['created_at']);
        return bDate.compareTo(aDate); // Descending order
      });

      final latestImage = sortedImages.first;
      final rating = latestImage['van_rating'];
      if (rating is num) {
        return rating.toDouble();
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // Save or update a van in the new schema
  Future<String> saveVan(Van van) async {
    try {
      final now = DateTime.now();

      // Prepare van profile data
      final vanProfileData = {
        'van_number': int.tryParse(van.plateNumber) ?? 0,
        'make': van.model,
        'model': van.year,
        'status': van.status,
        'notes': van.notes,
        'updated_at': now.toIso8601String(),
      };

      if (van.id.isEmpty) {
        // Create new van profile
        vanProfileData['created_at'] = now.toIso8601String();
      }

      final response = await _client
          .from('van_profiles')
          .upsert(vanProfileData, onConflict: 'van_number')
          .select()
          .single();

      final vanId = response['id'] as String;
      _log('✅ Saved van profile: $vanId');

      return vanId;
    } catch (e) {
      debugPrint('Error saving van: $e');
      throw Exception('Failed to save van: ${e.toString()}');
    }
  }

  // Delete a van and its related records
  Future<void> deleteVan(String vanId) async {
    try {
      // Delete van images first (cascade should handle this, but being explicit)
      await _client.from('van_images').delete().eq('van_id', vanId);

      // Delete van assignments
      await _client.from('van_assignments').delete().eq('van_id', vanId);

      // Delete the van profile
      await _client.from('van_profiles').delete().eq('id', vanId);

      _log('✅ Deleted van: $vanId');
    } catch (e) {
      debugPrint('Error deleting van: $e');
      throw Exception('Failed to delete van');
    }
  }

  // Get van by ID from new schema
  Future<Van?> getVanById(String vanId) async {
    try {
      final response = await _client.from('van_profiles').select('''
            *,
            driver_profiles!van_profiles_current_driver_id_fkey (
              id,
              driver_name,
              email,
              slack_user_id
            ),
            van_images!van_images_van_id_fkey (
              id,
              image_url,
              image_data,
              van_damage,
              van_rating,
              file_size,
              content_type,
              created_at
            )
          ''').eq('id', vanId).single();

      final driverProfile = response['driver_profiles'];
      final vanImages = response['van_images'] as List? ?? [];

      // Convert van images to VanImage objects and URLs
      List<VanImage> vanImageObjects = [];
      List<String> imageUrls = [];

      for (var imageData in vanImages) {
        final createdAt = _parseDateTime(imageData['created_at']);

        // Create VanImage object
        final vanImage = VanImage(
          id: imageData['id']?.toString() ?? '',
          vanId: response['id']?.toString() ?? '',
          imageUrl: imageData['image_url']?.toString() ?? '',
          uploadedAt: createdAt,
          damageLevel: imageData['van_rating'] as int? ?? 0,
          damageType: imageData['van_damage']?.toString(),
          createdAt: createdAt,
          updatedAt: createdAt,
        );
        vanImageObjects.add(vanImage);

        // Handle image URL
        if (imageData['image_data'] != null) {
          final base64Data = imageData['image_data'] as String;
          if (base64Data.startsWith('data:')) {
            imageUrls.add(base64Data);
          } else {
            final contentType = imageData['content_type'] ?? 'image/jpeg';
            imageUrls.add('data:$contentType;base64,$base64Data');
          }
        } else if (imageData['image_url'] != null) {
          imageUrls.add(imageData['image_url'] as String);
        }
      }

      return Van(
        id: response['id']?.toString() ?? '',
        plateNumber: response['van_number']?.toString() ?? '',
        model: response['make']?.toString() ?? 'Unknown',
        year: response['model']?.toString() ?? 'Unknown',
        status: response['status']?.toString() ?? 'Active',
        lastInspection: _parseDateTime(response['created_at']),
        notes: response['notes']?.toString() ?? '',
        url: imageUrls.isNotEmpty ? imageUrls.first : '',
        driverName: driverProfile?['driver_name']?.toString() ?? '',
        damage: _getLatestDamageDescription(vanImages),
        damageDescription: _getLatestDamageDescription(vanImages),
        rating: _getLatestRating(vanImages).toString(),
        images: vanImageObjects,
        maintenanceHistory: [],
      );
    } catch (e) {
      debugPrint('Error fetching van: $e');
      return null;
    }
  }

  // Upload van image (stores as base64 in database)
  Future<String> uploadVanImage(String vanId, File imageFile) async {
    try {
      // Read image file and convert to base64
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      const contentType = 'image/jpeg'; // Assume JPEG for now

      // Create data URL
      final dataUrl = 'data:$contentType;base64,$base64String';

      // Calculate file path for reference
      final fileName = '${vanId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'van_$vanId/$fileName';

      // Get van number for the foreign key
      final vanResponse = await _client
          .from('van_profiles')
          .select('van_number')
          .eq('id', vanId)
          .single();

      final vanNumber = vanResponse['van_number'] as int;

      // Insert image record into van_images table
      final imageData = {
        'van_id': vanId,
        'van_number': vanNumber,
        'image_url': dataUrl, // Store data URL
        'image_data': base64String, // Store raw base64
        'file_path': filePath,
        'file_size': bytes.length,
        'content_type': contentType,
        'van_damage': 'No damage description',
        'van_rating': 0,
        'upload_method': 'flutter_app',
        'created_at': DateTime.now().toIso8601String(),
      };

      await _client.from('van_images').insert(imageData);

      _log('✅ Uploaded image for van: $vanId');
      return dataUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return '';
    }
  }

  // Bulk import vans to new schema
  Future<Map<String, dynamic>> bulkImportVans(List<Van> vans) async {
    try {
      int successCount = 0;
      int errorCount = 0;

      for (var van in vans) {
        try {
          final vanId = await saveVan(van);
          if (vanId.isNotEmpty) {
            successCount++;
          } else {
            errorCount++;
          }
        } catch (e) {
          debugPrint('Error importing van ${van.plateNumber}: $e');
          errorCount++;
        }
      }

      return {
        'success': successCount > 0,
        'message':
            'Import completed: $successCount successful, $errorCount failed',
        'importedCount': successCount,
        'failedCount': errorCount,
      };
    } catch (e) {
      debugPrint('Error in bulk import: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'importedCount': 0,
        'failedCount': vans.length,
      };
    }
  }

  // Maintenance record methods (keeping existing functionality)
  Future<List<MaintenanceRecord>> _fetchMaintenanceRecordsForVan(
      String vanId) async {
    try {
      final response = await _client
          .from('maintenance_records')
          .select()
          .eq('van_id', vanId)
          .order('date', ascending: false);

      return response.map<MaintenanceRecord>((item) {
        try {
          return MaintenanceRecord(
            id: item['id']?.toString() ?? '',
            description: item['description']?.toString() ?? '',
            date: _parseDateTime(
                item['date'] ?? DateTime.now().toIso8601String()),
            type: item['type']?.toString() ?? 'Service',
            vanId: vanId,
            createdAt: _parseDateTime(
                item['created_at'] ?? DateTime.now().toIso8601String()),
          );
        } catch (e) {
          debugPrint('Error parsing maintenance record: $e');
          return MaintenanceRecord(
            id: item['id']?.toString() ?? '',
            description: item['description']?.toString() ?? '',
            date: _parseDateTime(
                item['date'] ?? DateTime.now().toIso8601String()),
            type: item['type']?.toString() ?? 'Service',
            vanId: vanId,
            createdAt: _parseDateTime(
                item['created_at'] ?? DateTime.now().toIso8601String()),
          );
        }
      }).toList();
    } catch (e) {
      debugPrint('Error fetching maintenance records: $e');
      return [];
    }
  }

  Future<String> createMaintenanceRecord(
      String vanId, MaintenanceRecord record) async {
    try {
      final response = await _client
          .from('maintenance_records')
          .insert({
            'van_id': vanId,
            'description': record.description,
            'date': record.date.toIso8601String(),
            'type': record.type,
            'technician': record.technician,
            'cost': record.cost,
            'status': record.status,
            'created_at': record.createdAt.toIso8601String(),
          })
          .select()
          .single();

      return response['id'];
    } catch (e) {
      debugPrint('Error creating maintenance record: $e');
      throw Exception('Failed to create maintenance record');
    }
  }

  Future<bool> updateMaintenanceRecord(MaintenanceRecord record) async {
    try {
      await _client
          .from('maintenance_records')
          .update(record.toJson())
          .eq('id', record.id);

      return true;
    } catch (e) {
      debugPrint('Error updating maintenance record: $e');
      return false;
    }
  }

  Future<bool> deleteMaintenanceRecord(String recordId) async {
    try {
      await _client.from('maintenance_records').delete().eq('id', recordId);
      return true;
    } catch (e) {
      debugPrint('Error deleting maintenance record: $e');
      return false;
    }
  }

  // Driver profile methods for new schema
  Future<Map<String, dynamic>> getOrCreateDriverProfile(
      String slackUserId, String driverName) async {
    try {
      // Try to find existing driver
      final existingResponse = await _client
          .from('driver_profiles')
          .select()
          .eq('slack_user_id', slackUserId)
          .maybeSingle();

      if (existingResponse != null) {
        return {
          'success': true,
          'action': 'found',
          'driver_id': existingResponse['id'],
          'driver_name': existingResponse['driver_name'],
        };
      }

      // Create new driver profile
      final newDriverResponse = await _client
          .from('driver_profiles')
          .insert({
            'slack_user_id': slackUserId,
            'driver_name': driverName,
            'status': 'active',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return {
        'success': true,
        'action': 'created',
        'driver_id': newDriverResponse['id'],
        'driver_name': newDriverResponse['driver_name'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get dashboard statistics for new schema
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final vanProfilesResponse =
          await _client.from('van_profiles').select('id, status');
      final vanImagesResponse =
          await _client.from('van_images').select('id, created_at');
      final driverProfilesResponse =
          await _client.from('driver_profiles').select('id, status');

      final totalVans = vanProfilesResponse.length;
      final activeVans =
          vanProfilesResponse.where((v) => v['status'] == 'active').length;
      final totalImages = vanImagesResponse.length;
      final totalDrivers = driverProfilesResponse.length;
      final activeDrivers =
          driverProfilesResponse.where((d) => d['status'] == 'active').length;

      // Calculate images uploaded today
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final imagesToday = vanImagesResponse.where((img) {
        final createdAt = _parseDateTime(img['created_at']);
        return createdAt.isAfter(todayStart);
      }).length;

      return {
        'total_vans': totalVans,
        'active_vans': activeVans,
        'total_images': totalImages,
        'images_today': imagesToday,
        'total_drivers': totalDrivers,
        'active_drivers': activeDrivers,
        'vans_with_images':
            vanImagesResponse.map((img) => img['van_id']).toSet().length,
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'generated_at': DateTime.now().toIso8601String(),
      };
    }
  }
}

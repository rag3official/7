import 'package:supabase_flutter/supabase_flutter.dart';

class EnhancedDriverService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get driver profile with upload statistics
  static Future<Map<String, dynamic>?> getDriverProfile(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_profile_summary')
          .select()
          .eq('driver_id', driverId)
          .single();

      return response;
    } catch (e) {
      print('Error fetching driver profile: $e');
      return null;
    }
  }

  // Get driver's images grouped by van for driver profile page
  static Future<List<Map<String, dynamic>>> getDriverImagesByVan(
      String driverId) async {
    try {
      final response = await _supabase.rpc('get_driver_images_by_van',
          params: {'p_driver_id': driverId, 'p_limit_per_van': 10});

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching driver images by van: $e');
      return [];
    }
  }

  // Get all images uploaded by a driver with van details
  static Future<List<Map<String, dynamic>>> getDriverImagesWithVanDetails(
      String driverId) async {
    try {
      final response = await _supabase
          .from('driver_images_with_van_details')
          .select()
          .eq('driver_id', driverId)
          .order('uploaded_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching driver images with van details: $e');
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
          .from('van_images_with_driver_details')
          .select()
          .eq('van_number', vanNumber)
          .order('uploaded_at', ascending: false);

      return {
        'van_profile': vanProfile,
        'images': images,
        'image_count': images.length,
      };
    } catch (e) {
      print('Error fetching van profile with images: $e');
      return null;
    }
  }

  // Navigate from driver profile to van profile
  static Future<Map<String, dynamic>?> navigateToVanProfile(
      int vanNumber) async {
    return await getVanProfileWithImages(vanNumber);
  }

  // Get all drivers with their upload statistics
  static Future<List<Map<String, dynamic>>> getAllDriverProfiles() async {
    try {
      final response = await _supabase
          .from('driver_profile_summary')
          .select()
          .order('total_images_uploaded', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching all driver profiles: $e');
      return [];
    }
  }

  // Search drivers by name
  static Future<List<Map<String, dynamic>>> searchDrivers(String query) async {
    try {
      final response = await _supabase
          .from('driver_profile_summary')
          .select()
          .or('driver_name.ilike.%$query%,slack_real_name.ilike.%$query%,slack_display_name.ilike.%$query%')
          .order('driver_name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error searching drivers: $e');
      return [];
    }
  }

  // Get recent uploads across all drivers
  static Future<List<Map<String, dynamic>>> getRecentUploads(
      {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('driver_images_with_van_details')
          .select()
          .order('uploaded_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching recent uploads: $e');
      return [];
    }
  }

  // Link existing images to drivers (admin function)
  static Future<int> linkImagesToDrivers() async {
    try {
      final response = await _supabase.rpc('link_images_to_drivers');
      return response as int;
    } catch (e) {
      print('Error linking images to drivers: $e');
      return 0;
    }
  }

  // Create or update driver profile
  static Future<bool> createOrUpdateDriverProfile({
    required String slackUserId,
    required String driverName,
    String? email,
    String? phone,
    String? licenseNumber,
    DateTime? hireDate,
    String? slackRealName,
    String? slackDisplayName,
    String? slackUsername,
  }) async {
    try {
      final data = {
        'slack_user_id': slackUserId,
        'driver_name': driverName,
        'email': email,
        'phone': phone,
        'license_number': licenseNumber,
        'hire_date': hireDate?.toIso8601String(),
        'slack_real_name': slackRealName,
        'slack_display_name': slackDisplayName,
        'slack_username': slackUsername,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('driver_profiles')
          .upsert(data, onConflict: 'slack_user_id');

      return true;
    } catch (e) {
      print('Error creating/updating driver profile: $e');
      return false;
    }
  }

  // Create or update van profile
  static Future<bool> createOrUpdateVanProfile({
    required int vanNumber,
    String? make,
    String? model,
    int? year,
    String? licensePlate,
    String? vin,
    String? status,
    String? currentDriverId,
    String? notes,
  }) async {
    try {
      final data = {
        'van_number': vanNumber,
        'make': make ?? 'Unknown',
        'model': model ?? 'Unknown',
        'year': year,
        'license_plate': licensePlate,
        'vin': vin,
        'status': status ?? 'active',
        'current_driver_id': currentDriverId,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('van_profiles')
          .upsert(data, onConflict: 'van_number');

      return true;
    } catch (e) {
      print('Error creating/updating van profile: $e');
      return false;
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
        'total_uploads': profile['total_images_uploaded'] ?? 0,
        'vans_photographed': profile['vans_photographed'] ?? 0,
        'uploads_last_30_days': profile['uploads_last_30_days'] ?? 0,
        'avg_damage_rating': profile['avg_damage_rating'] ?? 0.0,
        'last_upload': profile['last_image_upload'],
        'van_breakdown': imagesByVan,
        'member_since': profile['member_since'],
      };
    } catch (e) {
      print('Error getting driver statistics: $e');
      return {};
    }
  }
}

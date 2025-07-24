import 'package:supabase_flutter/supabase_flutter.dart';

class EnhancedDriverService {
  static final SupabaseClient _supabase = Supabase.instance.client;

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
      print('Error fetching driver profile: $e');
      return null;
    }
  }

  // Get driver's images grouped by van for driver profile page
  static Future<List<Map<String, dynamic>>> getDriverImagesByVan(String driverId) async {
    try {
      final response = await _supabase
          .rpc('get_driver_images_by_van', params: {
            'p_driver_id': driverId,
            'p_limit_per_van': 10
          });
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching driver images by van: $e');
      return [];
    }
  }

  // Get all images uploaded by a driver with van details
  static Future<List<Map<String, dynamic>>> getDriverImagesWithVanDetails(String driverId) async {
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
  static Future<Map<String, dynamic>?> getVanProfileWithImages(int vanNumber) async {
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
            created_at,
            driver_profiles!inner(
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
  static Future<Map<String, dynamic>?> navigateToVanProfile(int vanNumber) async {
    return await getVanProfileWithImages(vanNumber);
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
      print('Error fetching all driver profiles: $e');
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
}

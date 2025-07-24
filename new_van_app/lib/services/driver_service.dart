import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_profile.dart';

class DriverService {
  final SupabaseClient _supabase;

  DriverService(this._supabase);

  Future<List<DriverProfile>> getAllDrivers() async {
    try {
      final response = await _supabase
          .from('driver_profiles')
          .select()
          .order('created_at', ascending: false);

      print('Drivers response: $response');

      return response.map((json) => DriverProfile.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching drivers: $e'); // Debug print
      throw 'Failed to fetch drivers: $e';
    }
  }

  Future<List<Map<String, dynamic>>> getDriverAssignments(
      String driverId) async {
    try {
      final response = await _supabase
          .from('driver_van_assignments')
          .select('''
            *,
            vans (
              van_number,
              status
            )
          ''')
          .eq('driver_id', driverId)
          .order('assignment_date', ascending: false);

      print('Assignments response: $response');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching driver assignments: $e'); // Debug print
      throw 'Failed to fetch driver assignments: $e';
    }
  }

  Future<List<Map<String, dynamic>>> getDriverUploads(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_uploads')
          .select('''
            *,
            van_images (
              image_url,
              damage_level,
              damage_description
            )
          ''')
          .eq('driver_id', driverId)
          .order('upload_timestamp', ascending: false);

      print('Uploads response: $response');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching driver uploads: $e'); // Debug print
      throw 'Failed to fetch driver uploads: $e';
    }
  }

  Future<void> updateDriverProfile(DriverProfile profile) async {
    try {
      await _supabase
          .from('driver_profiles')
          .update(profile.toJson())
          .eq('id', profile.id);
    } catch (e) {
      print('Error updating driver profile: $e'); // Debug print
      throw 'Failed to update driver profile: $e';
    }
  }
}

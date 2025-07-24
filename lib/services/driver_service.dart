import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_profile.dart';
import 'package:logger/logger.dart';

class DriverService {
  final _logger = Logger();
  final _client = Supabase.instance.client;
  StreamSubscription<List<DriverProfile>>? _driverSubscription;
  static const String _tableName = 'driver_profiles';

  // Initialize the database
  Future<bool> initializeDatabase() async {
    try {
      await _client.from(_tableName).select().limit(1);
      return true;
    } catch (e) {
      _logger.e('Error initializing driver database: $e');
      return false;
    }
  }

  // Fetch all drivers
  Future<List<DriverProfile>> getDrivers() async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .order('name', ascending: true);

      return (response as List)
          .map((json) => DriverProfile.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching drivers: $e');
      rethrow;
    }
  }

  // Get a single driver by ID
  Future<DriverProfile?> getDriver(String id) async {
    try {
      final response =
          await _client.from(_tableName).select().eq('id', id).single();

      return DriverProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching driver: $e');
      rethrow;
    }
  }

  // Get current user profile
  Future<DriverProfile?> getCurrentUserProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('user_id', user.id)
          .single();

      return DriverProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching current user profile: $e');
      return null;
    }
  }

  // Create a new driver
  Future<DriverProfile> createDriver(DriverProfile driver) async {
    try {
      // Ensure the user_id is set to the current user
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      final driverData = driver.toJson();
      driverData['user_id'] = user.id;

      final response =
          await _client.from(_tableName).insert(driverData).select().single();

      return DriverProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error creating driver: $e');
      rethrow;
    }
  }

  // Update an existing driver
  Future<DriverProfile> updateDriver(
      String id, Map<String, dynamic> data) async {
    try {
      // Ensure we can't update the user_id
      data.remove('user_id');

      final response = await _client
          .from(_tableName)
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return DriverProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error updating driver: $e');
      rethrow;
    }
  }

  // Delete a driver
  Future<void> deleteDriver(String id) async {
    try {
      await _client.from(_tableName).delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting driver: $e');
      rethrow;
    }
  }

  // Subscribe to driver updates
  Stream<List<DriverProfile>> subscribeToDrivers() {
    return _client
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .order('name')
        .map((list) =>
            list.map((json) => DriverProfile.fromJson(json)).toList());
  }

  // Subscribe to current user profile
  Stream<DriverProfile?> subscribeToCurrentUserProfile() {
    final user = _client.auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _client
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .map((list) =>
            list.isNotEmpty ? DriverProfile.fromJson(list.first) : null);
  }

  Future<List<Map<String, dynamic>>> getDriverAssignments(
      String driverId) async {
    try {
      final response = await _client
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
      final response = await _client
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
      await _client
          .from(_tableName)
          .update(profile.toJson())
          .eq('id', profile.id);
    } catch (e) {
      print('Error updating driver profile: $e'); // Debug print
      throw 'Failed to update driver profile: $e';
    }
  }
}

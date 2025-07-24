import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_profile.dart';

class DriverService {
  final SupabaseClient _client;
  static const String _tableName = 'driver_profiles';

  DriverService() : _client = Supabase.instance.client;

  Future<bool> initializeDatabase() async {
    try {
      await _client.from(_tableName).select().limit(1);
      return true;
    } catch (e) {
      debugPrint('Error initializing driver database: $e');
      return false;
    }
  }

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

  Future<DriverProfile?> getCurrentUserProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      final response =
          await _client
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

  Future<DriverProfile> createDriver(DriverProfile driver) async {
    try {
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

  Future<DriverProfile> updateDriver(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      data.remove('user_id'); // Prevent updating user_id

      final response =
          await _client
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

  Future<void> deleteDriver(String id) async {
    try {
      await _client.from(_tableName).delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting driver: $e');
      rethrow;
    }
  }

  Stream<List<DriverProfile>> subscribeToDrivers() {
    return _client
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .order('name')
        .map(
          (list) => list.map((json) => DriverProfile.fromJson(json)).toList(),
        );
  }

  Stream<DriverProfile?> subscribeToCurrentUserProfile() {
    final user = _client.auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _client
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .map(
          (list) => list.isNotEmpty ? DriverProfile.fromJson(list.first) : null,
        );
  }
}

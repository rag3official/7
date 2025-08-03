import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_profile.dart';

class DriverService {
  final SupabaseClient _client;
  static const String _tableName = 'driver_profiles';

  // Cache for driver data
  List<DriverProfile>? _cachedDrivers;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

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
      // Check cache first
      if (_cachedDrivers != null && _lastCacheTime != null) {
        final timeSinceCache = DateTime.now().difference(_lastCacheTime!);
        if (timeSinceCache < _cacheValidDuration) {
          print(
              '📦 Returning cached drivers (${_cachedDrivers!.length} drivers)');
          return _cachedDrivers!;
        }
      }

      print('🔍 Fetching drivers from Supabase...');

      // Use a conservative query with only essential columns
      final response = await _client.from(_tableName).select('''
            id,
            driver_name,
            email,
            phone,
            status,
            created_at,
            updated_at
          ''').order('driver_name', ascending: true).limit(100);

      final drivers = (response as List)
          .map((json) => DriverProfile.fromJson(json))
          .toList();

      // Cache the results
      _cachedDrivers = drivers;
      _lastCacheTime = DateTime.now();

      print('✅ Successfully loaded ${drivers.length} drivers');
      print('📊 Cache updated with ${drivers.length} drivers');

      return drivers;
    } catch (e) {
      debugPrint('Error fetching drivers: $e');

      // Return cached data if available and error is network-related
      if (_cachedDrivers != null &&
          (e.toString().contains('timeout') ||
              e.toString().contains('network') ||
              e.toString().contains('connection'))) {
        print('⏱️ Network error detected - returning cached drivers');
        return _cachedDrivers!;
      }

      rethrow;
    }
  }

  // Clear cache when data is updated
  void clearCache() {
    _cachedDrivers = null;
    _lastCacheTime = null;
    print('🗑️ Driver cache cleared');
  }

  Future<DriverProfile?> getCurrentUserProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      final response = await _client.from(_tableName).select('''
            id,
            driver_name,
            email,
            phone,
            status,
            created_at,
            updated_at
          ''').eq('user_id', user.id).single();

      return DriverProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching current user profile: $e');
      return null;
    }
  }

  Future<DriverProfile?> getDriver(String id) async {
    try {
      final response = await _client.from(_tableName).select('''
            id,
            driver_name,
            email,
            phone,
            status,
            created_at,
            updated_at
          ''').eq('id', id).single();

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

      // Only include essential fields that are guaranteed to exist
      final driverData = {
        'driver_name': driver.driverName,
        'email': driver.email,
        'phone': driver.phone,
        'status': driver.status,
        'user_id': user.id,
      };

      final response =
          await _client.from(_tableName).insert(driverData).select('''
            id,
            driver_name,
            email,
            phone,
            status,
            created_at,
            updated_at
          ''').single();

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
      // Only allow updating essential fields
      final safeData = <String, dynamic>{};
      if (data['driver_name'] != null)
        safeData['driver_name'] = data['driver_name'];
      if (data['email'] != null) safeData['email'] = data['email'];
      if (data['phone'] != null) safeData['phone'] = data['phone'];
      if (data['status'] != null) safeData['status'] = data['status'];

      final response = await _client
          .from(_tableName)
          .update(safeData)
          .eq('id', id)
          .select('''
            id,
            driver_name,
            email,
            phone,
            status,
            created_at,
            updated_at
          ''').single();

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
        .order('driver_name')
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

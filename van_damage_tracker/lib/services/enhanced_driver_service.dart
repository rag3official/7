import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_profile.dart';
import '../models/van_assignment.dart';

class EnhancedDriverService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get driver by ID
  Future<DriverProfile?> getDriverById(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_profiles')
          .select('*')
          .eq('id', driverId)
          .single();

      return DriverProfile.fromJson(response);
    } catch (e) {
      print('Error fetching driver by ID: $e');
      return null;
    }
  }

  /// Get driver by Slack user ID
  Future<DriverProfile?> getDriverBySlackId(String slackUserId) async {
    try {
      final response = await _supabase
          .from('driver_profiles')
          .select('*')
          .eq('slack_user_id', slackUserId)
          .single();

      return DriverProfile.fromJson(response);
    } catch (e) {
      print('Error fetching driver by Slack ID: $e');
      return null;
    }
  }

  /// Get all drivers
  Future<List<DriverProfile>> getAllDrivers() async {
    try {
      final response = await _supabase
          .from('driver_profiles')
          .select('*')
          .order('driver_name');

      return response.map((json) => DriverProfile.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching all drivers: $e');
      return [];
    }
  }

  /// Create or update driver profile
  Future<DriverProfile?> createOrUpdateDriver(DriverProfile driver) async {
    try {
      final response = await _supabase
          .from('driver_profiles')
          .upsert(driver.toJson())
          .select()
          .single();

      return DriverProfile.fromJson(response);
    } catch (e) {
      print('Error creating/updating driver: $e');
      return null;
    }
  }

  /// Get driver's van assignments
  Future<List<VanAssignment>> getDriverVanAssignments(String driverId) async {
    try {
      final response = await _supabase
          .rpc('get_driver_van_assignments', params: {
            'driver_slack_user_id': driverId,
          });

      return response.map((json) => VanAssignment.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching driver van assignments: $e');
      return [];
    }
  }

  /// Assign van to driver
  Future<bool> assignVanToDriver({
    required String driverId,
    required int vanNumber,
    String? vanMake,
    String? vanModel,
    String? notes,
  }) async {
    try {
      await _supabase
          .from('van_assignments')
          .insert({
            'driver_id': driverId,
            'van_number': vanNumber,
            'van_make': vanMake ?? 'Unknown',
            'van_model': vanModel ?? 'Unknown',
            'notes': notes,
            'assignment_status': 'active',
          });

      return true;
    } catch (e) {
      print('Error assigning van to driver: $e');
      return false;
    }
  }

  /// Complete van assignment
  Future<bool> completeVanAssignment(String assignmentId) async {
    try {
      await _supabase
          .from('van_assignments')
          .update({
            'assignment_status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', assignmentId);

      return true;
    } catch (e) {
      print('Error completing van assignment: $e');
      return false;
    }
  }

  /// Cancel van assignment
  Future<bool> cancelVanAssignment(String assignmentId) async {
    try {
      await _supabase
          .from('van_assignments')
          .update({
            'assignment_status': 'cancelled',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', assignmentId);

      return true;
    } catch (e) {
      print('Error cancelling van assignment: $e');
      return false;
    }
  }

  /// Get driver's active assignments
  Future<List<VanAssignment>> getDriverActiveAssignments(String driverId) async {
    try {
      final response = await _supabase
          .from('van_assignments')
          .select('*')
          .eq('driver_id', driverId)
          .eq('assignment_status', 'active')
          .order('assigned_at', ascending: false);

      return response.map((json) => VanAssignment.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching driver active assignments: $e');
      return [];
    }
  }

  /// Get driver's completed assignments
  Future<List<VanAssignment>> getDriverCompletedAssignments(String driverId) async {
    try {
      final response = await _supabase
          .from('van_assignments')
          .select('*')
          .eq('driver_id', driverId)
          .eq('assignment_status', 'completed')
          .order('completed_at', ascending: false);

      return response.map((json) => VanAssignment.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching driver completed assignments: $e');
      return [];
    }
  }

  /// Get all van assignments (admin only)
  Future<List<VanAssignment>> getAllVanAssignments() async {
    try {
      final response = await _supabase
          .from('van_assignments')
          .select('''
            *,
            driver_profiles!inner(driver_name, slack_user_id)
          ''')
          .order('assigned_at', ascending: false);

      return response.map((json) {
        final driverData = json['driver_profiles'];
        json['driver_name'] = driverData['driver_name'];
        return VanAssignment.fromJson(json);
      }).toList();
    } catch (e) {
      print('Error fetching all van assignments: $e');
      return [];
    }
  }

  /// Get drivers with their assignment counts
  Future<List<Map<String, dynamic>>> getDriversWithAssignmentCounts() async {
    try {
      final response = await _supabase
          .rpc('get_drivers_with_assignment_counts');

      return response;
    } catch (e) {
      print('Error fetching drivers with assignment counts: $e');
      return [];
    }
  }

  /// Update driver status
  Future<bool> updateDriverStatus(String driverId, String status) async {
    try {
      await _supabase
          .from('driver_profiles')
          .update({'status': status})
          .eq('id', driverId);

      return true;
    } catch (e) {
      print('Error updating driver status: $e');
      return false;
    }
  }

  /// Get driver statistics
  Future<Map<String, dynamic>> getDriverStatistics(String driverId) async {
    try {
      final activeAssignments = await getDriverActiveAssignments(driverId);
      final completedAssignments = await getDriverCompletedAssignments(driverId);
      
      return {
        'active_assignments': activeAssignments.length,
        'completed_assignments': completedAssignments.length,
        'total_assignments': activeAssignments.length + completedAssignments.length,
        'last_assignment': activeAssignments.isNotEmpty 
            ? activeAssignments.first.assignedAt 
            : null,
      };
    } catch (e) {
      print('Error fetching driver statistics: $e');
      return {};
    }
  }

  /// Search drivers by name
  Future<List<DriverProfile>> searchDrivers(String searchTerm) async {
    try {
      final response = await _supabase
          .from('driver_profiles')
          .select('*')
          .or('driver_name.ilike.%$searchTerm%,slack_user_id.ilike.%$searchTerm%')
          .order('driver_name');

      return response.map((json) => DriverProfile.fromJson(json)).toList();
    } catch (e) {
      print('Error searching drivers: $e');
      return [];
    }
  }

  /// Get drivers by status
  Future<List<DriverProfile>> getDriversByStatus(String status) async {
    try {
      final response = await _supabase
          .from('driver_profiles')
          .select('*')
          .eq('status', status)
          .order('driver_name');

      return response.map((json) => DriverProfile.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching drivers by status: $e');
      return [];
    }
  }
}

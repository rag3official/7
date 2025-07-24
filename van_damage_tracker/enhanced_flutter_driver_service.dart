// Enhanced Driver Service for Van Damage Tracker
// Supports driver-van image tracking with navigation

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_profile.dart';
import '../models/van_image.dart';
import '../models/van.dart';

class EnhancedDriverService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =============================================================================
  // DRIVER PROFILE MANAGEMENT
  // =============================================================================

  /// Get all driver profiles with upload statistics
  Future<List<DriverProfile>> getAllDriversWithStats() async {
    try {
      final response = await _supabase
          .from('driver_upload_summary')
          .select('*')
          .order('last_upload_date', ascending: false);

      return response.map((json) => DriverProfile.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching drivers with stats: $e');
      throw 'Failed to fetch driver profiles: $e';
    }
  }

  /// Get driver profile by ID
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

  /// Get driver profile by Slack user ID
  Future<DriverProfile?> getDriverBySlackUserId(String slackUserId) async {
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

  // =============================================================================
  // DRIVER UPLOAD TRACKING
  // =============================================================================

  /// Get driver's uploads grouped by van (for driver profile page)
  Future<Map<String, DriverVanUploads>> getDriverUploadsGroupedByVan(
      String driverId) async {
    try {
      // Get driver's Slack user ID first
      final driver = await getDriverById(driverId);
      if (driver?.slackUserId == null) {
        throw 'Driver not found or missing Slack user ID';
      }

      final response = await _supabase.rpc('get_driver_uploads_by_van',
          params: {
            'driver_slack_user_id': driver!.slackUserId!,
            'limit_per_van': 50
          });

      final Map<String, DriverVanUploads> groupedUploads = {};

      for (final item in response) {
        final vanNumber = item['van_number'].toString();
        final uploads = DriverVanUploads.fromJson(item);
        groupedUploads[vanNumber] = uploads;
      }

      return groupedUploads;
    } catch (e) {
      print('Error fetching driver uploads by van: $e');
      throw 'Failed to fetch driver uploads: $e';
    }
  }

  /// Get driver's recent uploads (simplified for quick display)
  Future<List<VanImage>> getDriverRecentUploads(String driverId,
      {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('van_images')
          .select('''
            *,
            van_profiles!inner(van_number, make, model, status)
          ''')
          .eq('driver_id', driverId)
          .order('uploaded_at', ascending: false)
          .limit(limit);

      return response.map((json) {
        // Merge van profile data into the image data
        final vanData = json['van_profiles'];
        json['van_number'] = vanData['van_number'].toString();
        json['van_model'] = '${vanData['make']} ${vanData['model']}';
        json['van_status'] = vanData['status'];

        return VanImage.fromJson(json);
      }).toList();
    } catch (e) {
      print('Error fetching driver recent uploads: $e');
      throw 'Failed to fetch recent uploads: $e';
    }
  }

  /// Get driver's upload statistics
  Future<DriverUploadStats> getDriverUploadStats(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_upload_summary')
          .select('*')
          .eq('driver_id', driverId)
          .single();

      return DriverUploadStats.fromJson(response);
    } catch (e) {
      print('Error fetching driver upload stats: $e');
      throw 'Failed to fetch upload statistics: $e';
    }
  }

  // =============================================================================
  // VAN-DRIVER RELATIONSHIPS
  // =============================================================================

  /// Get van's images grouped by driver (for van profile page)
  Future<List<VanDriverGroup>> getVanImagesGroupedByDriver(String vanId) async {
    try {
      // First get the van number
      final vanResponse = await _supabase
          .from('van_profiles')
          .select('van_number')
          .eq('id', vanId)
          .single();

      final vanNumber = vanResponse['van_number'] as int;

      final response = await _supabase.rpc('get_van_images_by_driver',
          params: {'target_van_number': vanNumber, 'image_limit': 100});

      return response.map((json) => VanDriverGroup.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching van images by driver: $e');
      throw 'Failed to fetch van driver groups: $e';
    }
  }

  /// Get drivers who have uploaded images for a specific van
  Future<List<DriverProfile>> getVanContributors(String vanId) async {
    try {
      final response = await _supabase.from('van_images').select('''
            driver_profiles!inner(*)
          ''').eq('van_id', vanId);

      // Extract unique drivers
      final Set<String> driverIds = {};
      final List<DriverProfile> drivers = [];

      for (final item in response) {
        final driverData = item['driver_profiles'];
        final driverId = driverData['id'];

        if (!driverIds.contains(driverId)) {
          driverIds.add(driverId);
          drivers.add(DriverProfile.fromJson(driverData));
        }
      }

      return drivers;
    } catch (e) {
      print('Error fetching van contributors: $e');
      throw 'Failed to fetch van contributors: $e';
    }
  }

  // =============================================================================
  // DRIVER PROFILE UPDATES
  // =============================================================================

  /// Update driver profile information
  Future<void> updateDriverProfile(DriverProfile profile) async {
    try {
      await _supabase
          .from('driver_profiles')
          .update(profile.toJson())
          .eq('id', profile.id);
    } catch (e) {
      print('Error updating driver profile: $e');
      throw 'Failed to update driver profile: $e';
    }
  }

  /// Update driver's Slack information (when bot gets new data)
  Future<void> updateDriverSlackInfo(
    String driverId, {
    String? slackRealName,
    String? slackDisplayName,
    String? slackUsername,
    String? email,
    String? phone,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (slackRealName != null) updates['slack_real_name'] = slackRealName;
      if (slackDisplayName != null) {
        updates['slack_display_name'] = slackDisplayName;
      }
      if (slackUsername != null) updates['slack_username'] = slackUsername;
      if (email != null) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;

      await _supabase
          .from('driver_profiles')
          .update(updates)
          .eq('id', driverId);
    } catch (e) {
      print('Error updating driver Slack info: $e');
      throw 'Failed to update driver Slack information: $e';
    }
  }

  // =============================================================================
  // SEARCH AND FILTERING
  // =============================================================================

  /// Search drivers by name or Slack username
  Future<List<DriverProfile>> searchDrivers(String query) async {
    try {
      final response = await _supabase
          .from('driver_profiles')
          .select('*')
          .or('driver_name.ilike.%$query%,slack_username.ilike.%$query%,slack_real_name.ilike.%$query%')
          .order('driver_name');

      return response.map((json) => DriverProfile.fromJson(json)).toList();
    } catch (e) {
      print('Error searching drivers: $e');
      throw 'Failed to search drivers: $e';
    }
  }

  /// Get active drivers (those who have uploaded recently)
  Future<List<DriverProfile>> getActiveDrivers({int daysSince = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysSince));

      final response = await _supabase
          .from('driver_upload_summary')
          .select('*')
          .gte('last_upload_date', cutoffDate.toIso8601String())
          .order('last_upload_date', ascending: false);

      return response.map((json) => DriverProfile.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching active drivers: $e');
      throw 'Failed to fetch active drivers: $e';
    }
  }
}

// =============================================================================
// SUPPORTING DATA MODELS
// =============================================================================

class DriverVanUploads {
  final String vanId;
  final int vanNumber;
  final String vanMake;
  final String vanModel;
  final int uploadCount;
  final DateTime lastUpload;
  final List<VanImage> images;

  DriverVanUploads({
    required this.vanId,
    required this.vanNumber,
    required this.vanMake,
    required this.vanModel,
    required this.uploadCount,
    required this.lastUpload,
    required this.images,
  });

  factory DriverVanUploads.fromJson(Map<String, dynamic> json) {
    final imagesList = json['images'] as List<dynamic>? ?? [];

    return DriverVanUploads(
      vanId: json['van_id'],
      vanNumber: json['van_number'],
      vanMake: json['van_make'] ?? 'Unknown',
      vanModel: json['van_model'] ?? 'Unknown',
      uploadCount: json['upload_count'] ?? 0,
      lastUpload: DateTime.parse(json['last_upload']),
      images: imagesList.map((img) => VanImage.fromJson(img)).toList(),
    );
  }
}

class VanDriverGroup {
  final String driverId;
  final String driverName;
  final String? slackUserId;
  final String? driverEmail;
  final int uploadCount;
  final DateTime firstUpload;
  final DateTime lastUpload;
  final double avgRating;
  final List<VanImage> images;

  VanDriverGroup({
    required this.driverId,
    required this.driverName,
    this.slackUserId,
    this.driverEmail,
    required this.uploadCount,
    required this.firstUpload,
    required this.lastUpload,
    required this.avgRating,
    required this.images,
  });

  factory VanDriverGroup.fromJson(Map<String, dynamic> json) {
    final imagesList = json['images'] as List<dynamic>? ?? [];

    return VanDriverGroup(
      driverId: json['driver_id'],
      driverName: json['driver_name'],
      slackUserId: json['slack_user_id'],
      driverEmail: json['driver_email'],
      uploadCount: json['upload_count'] ?? 0,
      firstUpload: DateTime.parse(json['first_upload']),
      lastUpload: DateTime.parse(json['last_upload']),
      avgRating: (json['avg_rating'] ?? 0.0).toDouble(),
      images: imagesList.map((img) => VanImage.fromJson(img)).toList(),
    );
  }
}

class DriverUploadStats {
  final String driverId;
  final String driverName;
  final int totalUploads;
  final int vansPhotographed;
  final DateTime? lastUploadDate;
  final double avgDamageRating;
  final List<VanUploadSummary> vanSummaries;

  DriverUploadStats({
    required this.driverId,
    required this.driverName,
    required this.totalUploads,
    required this.vansPhotographed,
    this.lastUploadDate,
    required this.avgDamageRating,
    required this.vanSummaries,
  });

  factory DriverUploadStats.fromJson(Map<String, dynamic> json) {
    final summaryList = json['van_upload_summary'] as List<dynamic>? ?? [];

    return DriverUploadStats(
      driverId: json['driver_id'],
      driverName: json['driver_name'],
      totalUploads: json['total_uploads'] ?? 0,
      vansPhotographed: json['vans_photographed'] ?? 0,
      lastUploadDate: json['last_upload_date'] != null
          ? DateTime.parse(json['last_upload_date'])
          : null,
      avgDamageRating: (json['avg_damage_rating'] ?? 0.0).toDouble(),
      vanSummaries: summaryList
          .map((summary) => VanUploadSummary.fromJson(summary))
          .toList(),
    );
  }
}

class VanUploadSummary {
  final int vanNumber;
  final String vanMake;
  final String vanModel;
  final int uploadCount;
  final DateTime lastUpload;
  final double avgRating;

  VanUploadSummary({
    required this.vanNumber,
    required this.vanMake,
    required this.vanModel,
    required this.uploadCount,
    required this.lastUpload,
    required this.avgRating,
  });

  factory VanUploadSummary.fromJson(Map<String, dynamic> json) {
    return VanUploadSummary(
      vanNumber: json['van_number'],
      vanMake: json['van_make'] ?? 'Unknown',
      vanModel: json['van_model'] ?? 'Unknown',
      uploadCount: json['upload_count'] ?? 0,
      lastUpload: DateTime.parse(json['last_upload']),
      avgRating: (json['avg_rating'] ?? 0.0).toDouble(),
    );
  }
}

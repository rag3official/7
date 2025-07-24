import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/van.dart';
import '../models/van_image.dart';
import '../models/driver.dart';

class VanService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get all vans from the database using optimized queries
  Future<List<Van>> getAllVans() async {
    try {
      print('🔍 Attempting to fetch vans from Supabase...');
      print('🌐 Running on: ${kIsWeb ? 'web' : Platform.operatingSystem}');

      // First, get just the basic van profiles without complex joins
      final response = await _supabase
          .from('van_profiles')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50); // Limit to prevent excessive data

      print(
          '✅ Successfully fetched ${response.length} van profiles from database');

      if (response.isNotEmpty) {
        print(
            '📝 First van: ${response.first['van_number']} (${response.first['make']})');
      }

      // Convert van_profiles data to Van objects
      List<Van> vans = [];
      for (final item in response) {
        try {
          final vanProfile = item;

          final van = Van(
            id: vanProfile['id']?.toString() ?? '',
            plateNumber: vanProfile['van_number']?.toString() ?? '',
            model: vanProfile['make']?.toString() ?? 'Unknown',
            year: vanProfile['model']?.toString() ?? 'Unknown',
            status: vanProfile['status']?.toString() ?? 'Active',
            lastInspection:
                DateTime.tryParse(vanProfile['created_at']?.toString() ?? '') ??
                    DateTime.now(),
            notes: vanProfile['notes']?.toString() ?? '',
            url: '', // Will be populated later if needed
            driverName: 'Loading...', // Will be populated separately
            damage: 'No damage reported',
            damageDescription: 'No damage reported',
            rating: '0',
            images: [], // Will be populated when needed
            maintenanceHistory: [],
          );

          vans.add(van);
          print('✅ Processed van: ${van.plateNumber}');
        } catch (e) {
          print('❌ Error processing van profile: $e');
        }
      }

      print('✅ Successfully processed ${vans.length} vans');
      return vans;
    } catch (e) {
      print('❌ Error fetching vans: $e');
      print('🔧 Error type: ${e.runtimeType}');

      // Check if this is a timeout or connection error
      if (e.toString().contains('timeout') ||
          e.toString().contains('57014') ||
          e.toString().contains('canceling statement')) {
        print('⏱️ Database timeout detected - returning simplified data');
        return _getSimplifiedVans();
      }

      // Check if this is a network/permission error on macOS
      if (!kIsWeb &&
          Platform.isMacOS &&
          e.toString().contains('Operation not permitted')) {
        print('🚫 macOS network blocked - try running in Chrome instead');
        print('💡 Run: flutter run -d chrome');
        return _getMockVans();
      }

      rethrow;
    }
  }

  // Simplified method to get basic van data when complex queries timeout
  Future<List<Van>> _getSimplifiedVans() async {
    try {
      print('🔄 Attempting simplified van query...');

      // Use the simplest possible query
      final response = await _supabase
          .from('van_profiles')
          .select('id, van_number, make, model, status, created_at')
          .limit(20);

      print('✅ Simplified query returned ${response.length} vans');

      return response.map<Van>((item) {
        return Van(
          id: item['id']?.toString() ?? '',
          plateNumber: item['van_number']?.toString() ?? 'Unknown',
          model: item['make']?.toString() ?? 'Unknown',
          year: item['model']?.toString() ?? 'Unknown',
          status: item['status']?.toString() ?? 'Active',
          lastInspection:
              DateTime.tryParse(item['created_at']?.toString() ?? '') ??
                  DateTime.now(),
          notes: 'Basic van profile',
          url: '',
          driverName: 'Not loaded',
          damage: 'Status unknown',
          damageDescription: 'Status unknown',
          rating: '0',
          images: [],
          maintenanceHistory: [],
        );
      }).toList();
    } catch (e) {
      print('❌ Even simplified query failed: $e');
      return _getMockVans();
    }
  }

  // Helper method to get latest damage description from images
  String _getLatestDamageDescription(List<dynamic> vanImages) {
    if (vanImages.isEmpty) return '';

    try {
      // Sort by created_at and get the latest
      final sortedImages = List.from(vanImages);
      sortedImages.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime(1970);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime(1970);
        return bDate.compareTo(aDate);
      });

      return sortedImages.first['van_damage']?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  // Helper method to get latest rating from images
  int _getLatestRating(List<dynamic> vanImages) {
    if (vanImages.isEmpty) return 0;

    try {
      // Sort by created_at and get the latest
      final sortedImages = List.from(vanImages);
      sortedImages.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime(1970);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime(1970);
        return bDate.compareTo(aDate);
      });

      return int.tryParse(
              sortedImages.first['van_rating']?.toString() ?? '0') ??
          0;
    } catch (e) {
      return 0;
    }
  }

  // Get van images with driver information from the database
  Future<List<VanImage>> getVanImages(String vanId) async {
    try {
      print('🖼️ Attempting to fetch images for van $vanId...');

      // Query van_images with correct column names (using updated_at instead of uploaded_at)
      final response = await _supabase
          .from('van_images')
          .select(
              'id, van_id, image_url, driver_id, damage_type, damage_level, location, created_at, updated_at, description, uploaded_by, driver_name')
          .eq('van_id', vanId)
          .order('updated_at', ascending: false);

      print('✅ Successfully fetched ${response.length} images for van $vanId');

      // Debug: Print the image data
      for (int i = 0; i < response.length; i++) {
        final imageData = response[i];
        print(
            '📷 Image ${i + 1}: ${imageData['image_url']?.substring(0, 50)}...');
      }

      return response.map<VanImage>((imageData) {
        return VanImage(
          id: imageData['id'] ?? '',
          vanId: imageData['van_id'] ?? vanId,
          imageUrl: imageData['image_url'] ?? '',
          driverId: imageData['driver_id'],
          damageType: imageData['damage_type'],
          damageLevel: imageData['damage_level'] ?? 0,
          location: imageData['location'],
          uploadedAt: DateTime.tryParse(imageData['updated_at'] ?? '') ??
              DateTime.now(),
          createdAt: DateTime.tryParse(imageData['created_at'] ?? '') ??
              DateTime.now(),
          updatedAt: DateTime.tryParse(imageData['updated_at'] ?? '') ??
              DateTime.now(),
          description: imageData['description'],
          uploadedBy: imageData['uploaded_by'],
          driverName: imageData['driver_name'],
        );
      }).toList();
    } catch (error) {
      print('❌ Error fetching van images: $error');

      // Return mock data for testing when there's an error
      print('🌐 Returning mock image data for testing');
      return [
        VanImage(
          id: 'mock-1',
          vanId: vanId,
          imageUrl:
              'https://via.placeholder.com/400x300/FF5722/FFFFFF?text=Mock+Damage+1',
          driverId: 'mock-driver-1',
          damageType: 'Scratch',
          damageLevel: 2,
          location: 'Front bumper',
          uploadedAt: DateTime.now().subtract(const Duration(days: 1)),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          description: 'Minor scratch on front bumper',
          uploadedBy: 'Test Driver',
          driverName: 'John Doe',
        ),
        VanImage(
          id: 'mock-2',
          vanId: vanId,
          imageUrl:
              'https://via.placeholder.com/400x300/F44336/FFFFFF?text=Mock+Damage+2',
          driverId: 'mock-driver-2',
          damageType: 'Dent',
          damageLevel: 3,
          location: 'Side panel',
          uploadedAt: DateTime.now().subtract(const Duration(hours: 6)),
          createdAt: DateTime.now().subtract(const Duration(hours: 6)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
          description: 'Dent on passenger side panel',
          uploadedBy: 'Test Driver 2',
          driverName: 'Jane Smith',
        ),
      ];
    }
  }

  // Get all drivers from the database
  Future<List<Driver>> getAllDrivers() async {
    try {
      print('👥 Attempting to fetch drivers from Supabase...');

      final response = await _supabase
          .from('driver_profiles')
          .select('*')
          .eq('status', 'active')
          .order('driver_name', ascending: true);

      print('✅ Successfully fetched ${response.length} drivers from database');

      return response.map((json) => Driver.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error fetching drivers: $e');

      // Fallback to mock data for testing
      if (!kIsWeb && Platform.isMacOS) {
        print('🌐 Returning mock driver data for testing');
        return _getMockDrivers();
      }

      rethrow;
    }
  }

  // Get driver by ID
  Future<Driver?> getDriverById(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_profiles')
          .select('*')
          .eq('id', driverId)
          .single();

      return Driver.fromJson(response);
    } catch (e) {
      print('❌ Error fetching driver $driverId: $e');
      return null;
    }
  }

  // Delete a van
  Future<bool> deleteVan(String vanId) async {
    try {
      // Delete from van_profiles table instead of vans
      await _supabase.from('van_profiles').delete().eq('id', vanId);
      return true;
    } catch (e) {
      print('❌ Error deleting van: $e');
      return false;
    }
  }

  // Upload a new van image
  Future<VanImage?> uploadVanImage({
    required String vanId,
    required String imageUrl,
    required String driverId,
    String? description,
    String? damageType,
    int? damageLevel,
    String? location,
  }) async {
    try {
      final response = await _supabase
          .from('van_images')
          .insert({
            'van_id': vanId,
            'image_url': imageUrl,
            'driver_id': driverId,
            'description': description,
            'damage_type': damageType,
            'damage_level': damageLevel,
            'location': location,
          })
          .select('*')
          .single();

      return VanImage.fromJson(response);
    } catch (e) {
      print('❌ Error uploading van image: $e');
      return null;
    }
  }

  // Mock data for testing when network is restricted
  List<Van> _getMockVans() {
    return [
      Van(
        id: 'mock-1',
        plateNumber: '92',
        model: 'Ford Transit',
        status: 'Active',
        year: '2022',
        mileage: 15000,
        lastInspection: DateTime.now().subtract(const Duration(days: 30)),
        driverName: 'John Smith',
        rating: '2',
        damage: 'Minor scratch',
        damageDescription: 'Small scratch on left door',
        notes: 'Regular maintenance due next month',
        url:
            'https://images.unsplash.com/photo-1570993492881-25240ce854f4?w=800',
      ),
      // Add more mock vans...
    ];
  }

  List<VanImage> _getMockVanImages(String vanId) {
    final now = DateTime.now();
    return [
      VanImage(
        id: 'mock-img-1',
        vanId: vanId,
        imageUrl:
            'https://images.unsplash.com/photo-1570993492881-25240ce854f4?w=800',
        uploadedBy: 'John Smith',
        driverId: 'mock-driver-1',
        uploadedAt: now.subtract(const Duration(hours: 2)),
        description: 'Minor scratch on left side door',
        damageType: 'Scratch',
        damageLevel: 2,
        location: 'left',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        driverName: 'John Smith',
        driverEmployeeId: 'EMP001',
        driverPhone: '+1-555-0101',
        driverEmail: 'john.smith@company.com',
      ),
      VanImage(
        id: 'mock-img-2',
        vanId: vanId,
        imageUrl:
            'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800',
        uploadedBy: 'Sarah Johnson',
        driverId: 'mock-driver-2',
        uploadedAt: now.subtract(const Duration(days: 1)),
        description: 'Front bumper inspection',
        damageType: 'Dent',
        damageLevel: 3,
        location: 'front',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
        driverName: 'Sarah Johnson',
        driverEmployeeId: 'EMP002',
        driverPhone: '+1-555-0102',
        driverEmail: 'sarah.johnson@company.com',
      ),
      VanImage(
        id: 'mock-img-3',
        vanId: vanId,
        imageUrl:
            'https://images.unsplash.com/photo-1586244439413-bc2288941dda?w=800',
        uploadedBy: 'Mike Davis',
        driverId: 'mock-driver-3',
        uploadedAt: now.subtract(const Duration(days: 2)),
        description: 'Interior condition check',
        damageType: 'Wear',
        damageLevel: 1,
        location: 'interior',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
        driverName: 'Mike Davis',
        driverEmployeeId: 'EMP003',
        driverPhone: '+1-555-0103',
        driverEmail: 'mike.davis@company.com',
      ),
      VanImage(
        id: 'mock-img-4',
        vanId: vanId,
        imageUrl:
            'https://images.unsplash.com/photo-1560473354-208d3fdcf7ae?w=800',
        uploadedBy: 'John Smith',
        driverId: 'mock-driver-1',
        uploadedAt: now.subtract(const Duration(hours: 1)),
        description: 'Close-up of damage area',
        damageType: 'Scratch',
        damageLevel: 2,
        location: 'left',
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
        driverName: 'John Smith',
        driverEmployeeId: 'EMP001',
        driverPhone: '+1-555-0101',
        driverEmail: 'john.smith@company.com',
      ),
      VanImage(
        id: 'mock-img-5',
        vanId: vanId,
        imageUrl:
            'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=800',
        uploadedBy: 'Alex Wilson',
        driverId: 'mock-driver-4',
        uploadedAt: now.subtract(const Duration(days: 3)),
        description: 'Weekly inspection photo',
        damageType: null,
        damageLevel: 0,
        location: 'exterior',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
        driverName: 'Alex Wilson',
        driverEmployeeId: 'EMP004',
        driverPhone: '+1-555-0104',
        driverEmail: 'alex.wilson@company.com',
      ),
      VanImage(
        id: 'mock-img-6',
        vanId: vanId,
        imageUrl:
            'https://images.unsplash.com/photo-1517524008697-84bbe3c3fd98?w=800',
        uploadedBy: 'Sarah Johnson',
        driverId: 'mock-driver-2',
        uploadedAt: now.subtract(const Duration(hours: 6)),
        description: 'Follow-up damage assessment',
        damageType: 'Dent',
        damageLevel: 3,
        location: 'front',
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedAt: now.subtract(const Duration(hours: 6)),
        driverName: 'Sarah Johnson',
        driverEmployeeId: 'EMP002',
        driverPhone: '+1-555-0102',
        driverEmail: 'sarah.johnson@company.com',
      ),
    ];
  }

  List<Driver> _getMockDrivers() {
    final now = DateTime.now();
    return [
      Driver(
        id: 'mock-driver-1',
        name: 'John Smith',
        employeeId: 'EMP001',
        phone: '+1-555-0101',
        email: 'john.smith@company.com',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
      Driver(
        id: 'mock-driver-2',
        name: 'Sarah Johnson',
        employeeId: 'EMP002',
        phone: '+1-555-0102',
        email: 'sarah.johnson@company.com',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
      Driver(
        id: 'mock-driver-3',
        name: 'Mike Davis',
        employeeId: 'EMP003',
        phone: '+1-555-0103',
        email: 'mike.davis@company.com',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
      Driver(
        id: 'mock-driver-4',
        name: 'Alex Wilson',
        employeeId: 'EMP004',
        phone: '+1-555-0104',
        email: 'alex.wilson@company.com',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  List<VanImage> _getMockDriverImages(String driverId) {
    final now = DateTime.now();
    return [
      VanImage(
        id: 'mock-driver-img-1',
        vanId: 'mock-van-1',
        imageUrl:
            'https://images.unsplash.com/photo-1570993492881-25240ce854f4?w=800',
        uploadedBy: 'John Smith',
        driverId: driverId,
        uploadedAt: now.subtract(const Duration(hours: 2)),
        description: 'Damage report for Van 92',
        damageType: 'Scratch',
        damageLevel: 2,
        location: 'left',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        driverName: 'John Smith',
        driverEmployeeId: 'EMP001',
        driverPhone: '+1-555-0101',
        driverEmail: 'john.smith@company.com',
        vanNumber: '92',
        vanModel: 'Ford Transit',
        vanYear: '2022',
        vanStatus: 'active',
        vanDriver: 'John Smith',
        vanMainImageUrl:
            'https://images.unsplash.com/photo-1570993492881-25240ce854f4?w=800',
      ),
      VanImage(
        id: 'mock-driver-img-2',
        vanId: 'mock-van-2',
        imageUrl:
            'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800',
        uploadedBy: 'John Smith',
        driverId: driverId,
        uploadedAt: now.subtract(const Duration(days: 1)),
        description: 'Weekly inspection for Van 87',
        damageType: 'None',
        damageLevel: 0,
        location: 'exterior',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
        driverName: 'John Smith',
        driverEmployeeId: 'EMP001',
        driverPhone: '+1-555-0101',
        driverEmail: 'john.smith@company.com',
        vanNumber: '87',
        vanModel: 'Mercedes Sprinter',
        vanYear: '2021',
        vanStatus: 'active',
        vanDriver: 'John Smith',
        vanMainImageUrl:
            'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800',
      ),
      VanImage(
        id: 'mock-driver-img-3',
        vanId: 'mock-van-3',
        imageUrl:
            'https://images.unsplash.com/photo-1586244439413-bc2288941dda?w=800',
        uploadedBy: 'John Smith',
        driverId: driverId,
        uploadedAt: now.subtract(const Duration(days: 2)),
        description: 'Front bumper dent on Van 45',
        damageType: 'Dent',
        damageLevel: 3,
        location: 'front',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
        driverName: 'John Smith',
        driverEmployeeId: 'EMP001',
        driverPhone: '+1-555-0101',
        driverEmail: 'john.smith@company.com',
        vanNumber: '45',
        vanModel: 'Ford Transit',
        vanYear: '2020',
        vanStatus: 'maintenance',
        vanDriver: 'John Smith',
        vanMainImageUrl:
            'https://images.unsplash.com/photo-1586244439413-bc2288941dda?w=800',
      ),
    ];
  }

  // Get all images uploaded by a specific driver with van information from the database
  Future<List<VanImage>> getDriverImages(String driverId) async {
    try {
      print('🖼️ Attempting to fetch images for driver $driverId...');

      // Use the view that includes van information
      final response = await _supabase
          .from('van_images_with_van')
          .select('*')
          .eq('driver_id', driverId)
          .order('updated_at', ascending: false);

      print(
          '✅ Successfully fetched ${response.length} images for driver $driverId');

      return response.map((json) => VanImage.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error fetching driver images: $e');

      // Fallback to mock data for testing
      if (!kIsWeb && Platform.isMacOS) {
        print('🌐 Returning mock driver image data for testing');
        return _getMockDriverImages(driverId);
      }

      rethrow;
    }
  }
}

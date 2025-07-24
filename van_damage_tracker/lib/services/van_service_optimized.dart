import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/van.dart';
import '../models/van_image.dart';
import '../models/driver.dart';

class VanServiceOptimized {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Helper method to normalize status from database format to display format
  String _normalizeStatus(String? status) {
    if (status == null) return 'Active';

    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'maintenance':
        return 'Maintenance';
      case 'out_of_service':
        return 'Out of Service';
      default:
        return status; // Return as-is for unknown statuses
    }
  }

  // Get all vans with timeout and fallback handling
  Future<List<Van>> getAllVans() async {
    try {
      print('🔍 Attempting optimized van fetch...');

      // Use timeout to prevent hanging - removed 'notes' column that doesn't exist
      final response = await _supabase
          .from('van_profiles')
          .select(
              'id, van_number, make, model, status, created_at, alerts, damage_caused_by')
          .order('van_number', ascending: true)
          .limit(20)
          .timeout(const Duration(seconds: 8));

      print('✅ Fetched ${response.length} vans successfully');

      // Get driver information for each van
      List<Van> vans = [];
      int alertCount = 0;
      for (final item in response) {
        String vanId = item['id']?.toString() ?? '';
        String vanNumber = item['van_number']?.toString() ?? 'Unknown';

        // Try to get the most recent driver from van_images
        String driverName = 'Not assigned';
        String damage = 'No damage reported';
        String damageDescription = 'No damage reported';
        String rating = '0';

        try {
          // Get the most recent image for this van to extract driver info
          final imageResponse = await _supabase
              .from('van_images')
              .select('uploaded_by, van_damage, van_rating, driver_name')
              .eq('van_id', vanId)
              .order('created_at', ascending: false)
              .limit(1)
              .timeout(const Duration(seconds: 3));

          if (imageResponse.isNotEmpty) {
            final imageData = imageResponse.first;
            driverName = imageData['driver_name']?.toString() ??
                imageData['uploaded_by']?.toString() ??
                'Not assigned';
            damage =
                imageData['van_damage']?.toString() ?? 'No damage reported';
            rating = imageData['van_rating']?.toString() ?? '0';
            damageDescription = damage;
            print('✅ Found driver for van $vanNumber: $driverName');
          }
        } catch (e) {
          print('⚠️ Could not fetch driver info for van $vanNumber: $e');
          // Continue with default values
        }

        final alertsValue = item['alerts']?.toString() ?? 'no';
        print('🚨 Van #$vanNumber alerts value: $alertsValue');
        if (alertsValue == 'yes') {
          alertCount++;
        }

        final van = Van(
          id: vanId,
          plateNumber: vanNumber,
          model: item['make']?.toString() ?? 'Unknown',
          year: item['model']?.toString() ?? 'Unknown',
          status: _normalizeStatus(item['status']?.toString()),
          alerts: alertsValue, // Alert flag for damage level 2/3
          damageCausedBy: item['damage_caused_by']?.toString(),
          lastInspection:
              DateTime.tryParse(item['created_at']?.toString() ?? '') ??
                  DateTime.now(),
          notes: 'No notes available', // Default value since column not queried
          url: '',
          driverName: driverName,
          damage: damage,
          damageDescription: damageDescription,
          rating: rating,
          images: [],
          maintenanceHistory: [],
        );

        vans.add(van);
      }

      print('🚨 Total vans with alerts: $alertCount out of ${vans.length}');
      return vans;
    } catch (e) {
      print('❌ Optimized query failed: $e');
      print('🔄 Using mock van data as fallback');

      // Return mock data as fallback
      return _getMockVans();
    }
  }

  // Get van images separately to avoid complex joins
  Future<List<VanImage>> getVanImages(String vanId) async {
    try {
      print('🖼️ Fetching images for van $vanId...');

      final response = await _supabase
          .from('van_images')
          .select('*')
          .eq('van_id', vanId)
          .order('created_at', ascending: false)
          .limit(10)
          .timeout(const Duration(seconds: 5));

      print('✅ Found ${response.length} images for van $vanId');

      return response.map<VanImage>((item) {
        String imageUrl = '';

        // Handle base64 data
        if (item['image_data'] != null &&
            item['image_data'].toString().isNotEmpty) {
          if (item['image_data'].toString().startsWith('data:')) {
            imageUrl = item['image_data'].toString();
          } else {
            imageUrl =
                'data:${item['content_type'] ?? 'image/jpeg'};base64,${item['image_data']}';
          }
        } else if (item['image_url'] != null) {
          imageUrl = item['image_url'].toString();
        }

        return VanImage(
          id: item['id']?.toString() ?? '',
          vanId: vanId,
          imageUrl: imageUrl,
          driverId: item['driver_id']?.toString(),
          damageType: item['van_damage']?.toString() ?? 'Unknown',
          damageLevel: int.tryParse(item['van_rating']?.toString() ?? '0') ?? 0,
          location:
              item['location']?.toString() ?? item['van_side']?.toString(),
          vanSide: item['van_side']?.toString(),
          uploadedAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ??
              DateTime.now(),
          createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ??
              DateTime.now(),
          updatedAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ??
              DateTime.now(),
          description: item['van_damage']?.toString() ?? '',
          uploadedBy: item['uploaded_by']?.toString() ?? 'Unknown',
          driverName: item['driver_name']?.toString() ??
              item['uploaded_by']?.toString() ??
              'Unknown',
        );
      }).toList();
    } catch (e) {
      print('❌ Error fetching van images: $e');
      return [];
    }
  }

  // Get drivers separately
  Future<List<Driver>> getAllDrivers() async {
    try {
      print('👥 Fetching drivers...');

      final response = await _supabase
          .from('driver_profiles')
          .select('*')
          .eq('status', 'active')
          .order('driver_name', ascending: true)
          .limit(50)
          .timeout(const Duration(seconds: 5));

      print('✅ Found ${response.length} drivers');
      return response.map<Driver>((json) => Driver.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error fetching drivers: $e');
      return _getMockDrivers();
    }
  }

  // Delete a van
  Future<bool> deleteVan(String vanId) async {
    try {
      await _supabase.from('van_profiles').delete().eq('id', vanId);
      return true;
    } catch (e) {
      print('❌ Error deleting van: $e');
      return false;
    }
  }

  // Mock data for fallback
  List<Van> _getMockVans() {
    print('🔄 Using mock van data as fallback');
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
      Van(
        id: 'mock-2',
        plateNumber: '88',
        model: 'Mercedes Sprinter',
        status: 'Active',
        year: '2021',
        mileage: 22000,
        lastInspection: DateTime.now().subtract(const Duration(days: 15)),
        driverName: 'Sarah Johnson',
        rating: '1',
        damage: 'No damage',
        damageDescription: 'Vehicle in good condition',
        notes: 'Recently serviced',
        url: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800',
      ),
      Van(
        id: 'mock-3',
        plateNumber: '99',
        model: 'Ford Transit',
        status: 'Active',
        year: '2023',
        mileage: 8000,
        lastInspection: DateTime.now().subtract(const Duration(days: 5)),
        driverName: 'Mike Wilson',
        rating: '3',
        damage: 'Dent on side',
        damageDescription: 'Small dent on passenger side',
        notes: 'Needs repair scheduling',
        url: 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=800',
      ),
    ];
  }

  List<Driver> _getMockDrivers() {
    print('🔄 Using mock driver data as fallback');
    return [
      Driver(
        id: 'mock-driver-1',
        name: 'John Smith',
        email: 'john@example.com',
        phone: '555-0101',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Driver(
        id: 'mock-driver-2',
        name: 'Sarah Johnson',
        email: 'sarah@example.com',
        phone: '555-0102',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }
}

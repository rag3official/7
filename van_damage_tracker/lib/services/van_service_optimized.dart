import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/van.dart';
import '../models/van_image.dart';
import '../models/driver.dart';

class VanServiceOptimized {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Van>? _cachedVans;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  // Primary method using original approach with optimizations
  Future<List<Van>> getAllVans() async {
    try {
      // Check cache first
      if (_cachedVans != null && _lastCacheTime != null) {
        final timeSinceCache = DateTime.now().difference(_lastCacheTime!);
        if (timeSinceCache < _cacheValidDuration) {
          print('📦 Returning cached vans (${_cachedVans!.length} vans)');
          return _cachedVans!;
        }
      }

      print('🚀 Fetching vans using optimized original method...');
      print('🌐 Running on: ${kIsWeb ? 'web' : Platform.operatingSystem}');

      // Use the original method with optimizations and timeout
      return await _getVansWithOptimizedOriginalMethod().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏰ Van loading timed out, returning empty list');
          return <Van>[];
        },
      );
    } catch (e) {
      print('❌ Error fetching vans: $e');
      print('🔧 Error type: ${e.runtimeType}');

      // Return cached data if available and error is network-related
      if (_cachedVans != null &&
          (e.toString().contains('timeout') ||
              e.toString().contains('57014') ||
              e.toString().contains('canceling statement') ||
              e.toString().contains('network'))) {
        print('⏱️ Network error detected - returning cached data');
        return _cachedVans!;
      }

      // Check if this is a network/permission error on macOS
      if (!kIsWeb &&
          Platform.isMacOS &&
          e.toString().contains('Operation not permitted')) {
        print('🚫 macOS network blocked - try running in Chrome instead');
        print('💡 Run: flutter run -d chrome');
        return _getMockVans();
      }

      // If all else fails, return cached data or empty list
      if (_cachedVans != null) {
        print('🔄 Returning cached data due to error');
        return _cachedVans!;
      }

      print('⚠️ No cached data available, returning empty list');
      return [];
    }
  }

  // Optimized original method with batch loading
  Future<List<Van>> _getVansWithOptimizedOriginalMethod() async {
    try {
      print('🔄 Using optimized original method...');

      // Step 1: Get all van profiles in one query with only essential columns
      print('🔍 Querying van_profiles table...');
      final vanProfilesResponse =
          await _supabase.from('van_profiles').select('''
            id,
            van_number,
            make,
            model,
            year,
            status,
            notes,
            created_at,
            updated_at
          ''').order('created_at', ascending: false).limit(50).timeout(
                const Duration(seconds: 8),
                onTimeout: () {
                  print('⏰ Van profiles query timed out');
                  return <Map<String, dynamic>>[];
                },
              );

      print(
          '✅ Fetched ${vanProfilesResponse.length} van profiles from database');

      if (vanProfilesResponse.isNotEmpty) {
        print('📝 First van data: ${vanProfilesResponse.first}');
      }

      if (vanProfilesResponse.isEmpty) {
        print('⚠️ No van profiles found in database - this might be the issue');
        print('🔍 Checking if van_profiles table exists and has data...');

        // Try a simple query to see if the table exists
        try {
          final testResponse =
              await _supabase.from('van_profiles').select('count').limit(1);
          print('✅ van_profiles table exists and is accessible');
        } catch (e) {
          print('❌ Error accessing van_profiles table: $e');
          return _getMockVans();
        }

        // If table exists but is empty, return empty list instead of mock data
        print('📝 van_profiles table is empty - returning empty list');
        return [];
      }

      // Step 2: Get all van numbers for batch image query
      final vanNumbers = vanProfilesResponse
          .map((profile) => profile['van_number']?.toString() ?? '')
          .where((number) => number.isNotEmpty)
          .toList();

      print(
          '🔍 Found ${vanNumbers.length} van numbers: ${vanNumbers.join(', ')}');

      // Step 3: Batch load all images for all vans in one query
      List<Map<String, dynamic>> allImagesResponse = [];
      if (vanNumbers.isNotEmpty) {
        try {
          print(
              '🔍 Querying van_images table for ${vanNumbers.length} vans...');
          allImagesResponse = await _supabase
              .from('van_images')
              .select('''
                id,
                van_number,
                image_url,
                image_data,
                van_damage,
                van_rating,
                van_side,
                damage_type,
                damage_severity,
                damage_location,
                created_at,
                uploaded_by
              ''')
              .inFilter('van_number', vanNumbers)
              .order('created_at', ascending: false)
              .limit(200)
              .timeout(
                const Duration(seconds: 8),
                onTimeout: () {
                  print('⏰ Van images query timed out');
                  return <Map<String, dynamic>>[];
                },
              );

          print(
              '📷 Batch loaded ${allImagesResponse.length} images for all vans');
        } catch (e) {
          print('⚠️ Could not batch load images: $e');
          allImagesResponse = [];
        }
      }

      // Step 4: Group images by van number for efficient lookup
      final Map<String, List<VanImage>> imagesByVanNumber = {};
      for (final imageData in allImagesResponse) {
        final vanNumber = imageData['van_number']?.toString() ?? '';
        if (vanNumber.isNotEmpty) {
          try {
            final vanImage = VanImage.fromJson(imageData);
            imagesByVanNumber.putIfAbsent(vanNumber, () => []).add(vanImage);
          } catch (e) {
            print('⚠️ Error processing image for van $vanNumber: $e');
          }
        }
      }

      // Step 5: Create van objects with optimized damage calculation
      List<Van> vans = [];
      for (final vanProfile in vanProfilesResponse) {
        try {
          final vanNumber = vanProfile['van_number']?.toString() ?? '';
          final vanImages = imagesByVanNumber[vanNumber] ?? [];

          // Optimized damage calculation
          String aggregatedDamageDescription = 'No damage reported';
          int maxDamageRating = 0;

          if (vanImages.isNotEmpty) {
            // Find the highest damage rating
            maxDamageRating = vanImages
                .map((img) => img.damageLevel ?? 0)
                .reduce((a, b) => a > b ? a : b);

            // Get the most recent damage description
            final latestImage = vanImages
                .reduce((a, b) => a.uploadedAt.isAfter(b.uploadedAt) ? a : b);

            if (latestImage.vanDamage != null &&
                latestImage.vanDamage!.isNotEmpty) {
              aggregatedDamageDescription = latestImage.vanDamage!;
            } else if (maxDamageRating > 0) {
              // Create generic damage description based on rating
              switch (maxDamageRating) {
                case 1:
                  aggregatedDamageDescription = 'Minor damage detected';
                  break;
                case 2:
                  aggregatedDamageDescription = 'Moderate damage detected';
                  break;
                case 3:
                  aggregatedDamageDescription = 'Major damage detected';
                  break;
              }
            }
          }

          final van = Van(
            id: vanProfile['id']?.toString() ?? '',
            plateNumber: vanNumber,
            model: vanProfile['model']?.toString() ??
                vanProfile['make']?.toString() ??
                'Unknown',
            year: vanProfile['year']?.toString() ??
                vanProfile['model']?.toString() ??
                'Unknown',
            status: vanProfile['status']?.toString() ?? 'active',
            lastInspection:
                DateTime.tryParse(vanProfile['created_at']?.toString() ?? '') ??
                    DateTime.now(),
            notes: vanProfile['notes']?.toString() ?? '',
            url: '',
            driverName: '', // No driver name column in your table
            damage: aggregatedDamageDescription,
            damageDescription: aggregatedDamageDescription,
            rating: maxDamageRating.toString(),
            images: vanImages,
            maintenanceHistory: [],
          );

          vans.add(van);
          print('✅ Processed van: ${van.plateNumber} (${van.model})');
        } catch (e) {
          print('❌ Error processing van profile: $e');
        }
      }

      // Cache the results
      _cachedVans = vans;
      _lastCacheTime = DateTime.now();

      print(
          '✅ Successfully processed ${vans.length} vans with optimized original method');
      print('📊 Cache updated with ${vans.length} vans');
      print('⚡ Performance: Batch loading instead of N+1 queries');

      return vans;
    } catch (e) {
      print('❌ Optimized original method failed: $e');
      print('🔧 Error type: ${e.runtimeType}');
      print('🔧 Error details: ${e.toString()}');
      return _getMockVans();
    }
  }

  // Clear cache when data is updated
  void clearCache() {
    _cachedVans = null;
    _lastCacheTime = null;
    print('🗑️ Van cache cleared');
  }

  // Ultra fast loading method for initial app launch
  Future<List<Van>> getVansFast() async {
    try {
      print('⚡ Ultra fast loading vans...');

      // Minimal query with timeout
      final vanProfilesResponse = await _supabase
          .from('van_profiles')
          .select('van_number, status')
          .limit(10)
          .timeout(const Duration(seconds: 5));

      if (vanProfilesResponse.isEmpty) {
        print('⚠️ No van profiles found in ultra fast query');
        return [];
      }

      final vans = <Van>[];
      for (final vanProfile in vanProfilesResponse) {
        try {
          final vanNumber = vanProfile['van_number']?.toString() ?? '';
          if (vanNumber.isEmpty) continue;

          final van = Van(
            id: vanNumber,
            plateNumber: vanNumber,
            model: 'Van',
            year: '2024',
            status: vanProfile['status']?.toString() ?? 'active',
            lastInspection: DateTime.now(),
            notes: '',
            url: '',
            driverName: '',
            damage: 'No damage reported',
            damageDescription: 'No damage reported',
            rating: '0',
            images: [],
            maintenanceHistory: [],
          );

          vans.add(van);
        } catch (e) {
          print('❌ Error processing van in ultra fast query: $e');
        }
      }

      print('⚡ Ultra fast loading completed: ${vans.length} vans');
      return vans;
    } catch (e) {
      print('❌ Error in ultra fast loading: $e');
      return [];
    }
  }

  // Mock data for testing
  List<Van> _getMockVans() {
    return [
      Van(
        id: '1',
        plateNumber: 'VAN001',
        model: 'Ford Transit',
        year: '2022',
        status: 'active',
        lastInspection: DateTime.now(),
        notes: 'Mock van for testing',
        url: '',
        driverName: 'Test Driver',
        damage: 'No damage reported',
        damageDescription: 'No damage reported',
        rating: '0',
        images: [],
        maintenanceHistory: [],
      ),
    ];
  }
}

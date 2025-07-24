import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/van.dart';

class SupabaseService {
  final _client = Supabase.instance.client;
  StreamSubscription<List<Van>>? _vanSubscription;

  // Initialize the database
  Future<bool> initializeDatabase() async {
    try {
      // Check if we can connect to Supabase using new schema
      await _client.from('van_profiles').select().limit(1);
      return true;
    } catch (e) {
      debugPrint('Error initializing database: $e');
      return false;
    }
  }

  // Subscribe to van updates using new schema
  void subscribeToVans(Function(List<Van>) onVansUpdated) {
    debugPrint('Setting up van subscription...');

    // Unsubscribe from any existing subscription
    _vanSubscription?.cancel();

    // Set up new subscription using stream for van_profiles table
    _vanSubscription = _client
        .from('van_profiles')
        .stream(primaryKey: ['id'])
        .map((data) => data.map((json) => Van.fromNewSchema(json)).toList())
        .listen(
          onVansUpdated,
          onError: (error) {
            debugPrint('Error in van subscription: $error');
          },
        );
  }

  // Unsubscribe from van updates
  void unsubscribeFromVans() {
    _vanSubscription?.cancel();
    _vanSubscription = null;
  }

  // Fetch vans from Supabase using new schema
  Future<List<Van>> fetchVans({bool forceRefresh = false}) async {
    try {
      final response = await _client.from('van_profiles').select('''
            *,
            van_images(*),
            driver_profiles!van_profiles_current_driver_id_fkey(*)
          ''').order('created_at', ascending: false);

      return (response as List).map((json) => Van.fromNewSchema(json)).toList();
    } catch (e) {
      debugPrint('Error fetching vans: $e');
      throw Exception('Failed to fetch vans');
    }
  }

  Future<List<Van>> getVans() async {
    try {
      final response = await _client.from('van_profiles').select('''
            *,
            van_images(*),
            driver_profiles!van_profiles_current_driver_id_fkey(*)
          ''').order('van_number');

      return (response as List).map((van) => Van.fromNewSchema(van)).toList();
    } catch (e) {
      debugPrint('Error getting vans: $e');
      rethrow;
    }
  }

  Future<Van?> getVan(String id) async {
    try {
      final response = await _client.from('van_profiles').select('''
            *,
            van_images(*),
            driver_profiles!van_profiles_current_driver_id_fkey(*)
          ''').eq('id', id).single();

      return Van.fromNewSchema(response);
    } catch (e) {
      debugPrint('Error getting van: $e');
      rethrow;
    }
  }

  Future<Van> createVan(
      String name, String status, String? maintenanceNotes) async {
    try {
      final van = {
        'van_number': name, // Assuming name is van_number
        'status': status,
        'notes': maintenanceNotes,
        'make': 'Unknown',
        'model': 'Unknown',
      };

      final response = await _client.from('van_profiles').insert(van).select('''
            *,
            van_images(*),
            driver_profiles!van_profiles_current_driver_id_fkey(*)
          ''').single();

      return Van.fromNewSchema(response);
    } catch (e) {
      debugPrint('Error creating van: $e');
      rethrow;
    }
  }

  Future<Van> updateVan(String id, Map<String, dynamic> data) async {
    try {
      final response = await _client
          .from('van_profiles')
          .update(data)
          .eq('id', id)
          .select('''
            *,
            van_images(*),
            driver_profiles!van_profiles_current_driver_id_fkey(*)
          ''').single();

      return Van.fromNewSchema(response);
    } catch (e) {
      debugPrint('Error updating van: $e');
      rethrow;
    }
  }

  Future<Van> saveVan(Van van) async {
    try {
      final data = van.toNewSchemaJson();
      final response =
          await _client.from('van_profiles').upsert(data).select('''
            *,
            van_images(*),
            driver_profiles!van_profiles_current_driver_id_fkey(*)
          ''').single();

      return Van.fromNewSchema(response);
    } catch (e) {
      debugPrint('Error saving van: $e');
      rethrow;
    }
  }

  Future<void> deleteVan(String vanId) async {
    try {
      await _client.from('van_profiles').delete().eq('id', vanId);
    } catch (e) {
      debugPrint('Error deleting van: $e');
      rethrow;
    }
  }

  Future<String> uploadImage(String vanId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = 'van_images/$vanId/$fileName';

      // Note: This will still fail due to storage constraints
      // The bot handles image uploads differently by storing base64 in database
      await _client.storage.from('van-images').upload(filePath, imageFile);

      final imageUrl =
          _client.storage.from('van-images').getPublicUrl(filePath);

      await _client.from('van_images').insert({
        'van_id': vanId,
        'image_url': imageUrl,
        'file_path': filePath,
      });

      return imageUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  Future<void> deleteImage(String vanId, String imageUrl) async {
    try {
      await _client.from('van_images').delete().eq('image_url', imageUrl);
    } catch (e) {
      debugPrint('Error deleting image: $e');
      rethrow;
    }
  }
}

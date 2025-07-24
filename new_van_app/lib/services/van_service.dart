import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/van.dart';

class VanService {
  final _supabase = Supabase.instance.client;

  Future<List<Van>> getVans() async {
    final response = await _supabase
        .from('vans')
        .select('*, van_images(*)')
        .order('created_at', ascending: false);

    return (response as List).map((json) => Van.fromJson(json)).toList();
  }

  Future<Van> getVan(String id) async {
    final response = await _supabase
        .from('vans')
        .select('*, van_images(*)')
        .eq('id', id)
        .single();

    return Van.fromJson(response);
  }

  Future<Van> createVan(
      String name, String status, String? maintenanceNotes) async {
    final response = await _supabase
        .from('vans')
        .insert({
          'name': name,
          'status': status,
          'maintenance_notes': maintenanceNotes,
        })
        .select('*, van_images(*)')
        .single();

    return Van.fromJson(response);
  }

  Future<Van> updateVan(String id, Map<String, dynamic> data) async {
    final response = await _supabase
        .from('vans')
        .update(data)
        .eq('id', id)
        .select('*, van_images(*)')
        .single();

    return Van.fromJson(response);
  }

  Future<void> deleteVan(String id) async {
    await _supabase.from('vans').delete().eq('id', id);
  }

  Future<String> uploadImage(String vanId, File imageFile) async {
    final fileExt = imageFile.path.split('.').last;
    final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
    final filePath = 'van-images/$vanId/$fileName';

    await _supabase.storage.from('van-images').upload(filePath, imageFile);

    final imageUrl =
        _supabase.storage.from('van-images').getPublicUrl(filePath);

    await _supabase.from('van_images').insert({
      'van_id': vanId,
      'url': imageUrl,
    });

    return imageUrl;
  }

  Future<void> deleteImage(String vanId, String imageUrl) async {
    final filePath = imageUrl.split('van-images/').last;
    await _supabase.storage.from('van-images').remove([filePath]);
    await _supabase
        .from('van_images')
        .delete()
        .eq('van_id', vanId)
        .eq('url', imageUrl);
  }
}

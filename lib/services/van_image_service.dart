import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class VanImageService {
  final SupabaseClient supabase;
  static const int pageSize = 20;

  VanImageService({required this.supabase});

  Future<List<VanImage>> getVanImages(int vanNumber, {int page = 0}) async {
    try {
      final response = await supabase.rpc('get_van_images_batch', params: {
        'p_van_numbers': [vanNumber],
        'p_limit': pageSize,
        'p_offset': page * pageSize,
      });

      if (response.error != null) {
        throw Exception('Failed to get van images: ${response.error!.message}');
      }

      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => VanImage.fromJson(json)).toList();
    } catch (e) {
      print('❌ Failed to get van images: $e');
      rethrow;
    }
  }

  Future<List<VanImage>> getLatestVanImages(List<int> vanNumbers) async {
    try {
      // Split van numbers into chunks of 10 to avoid timeout
      final chunks = <List<int>>[];
      for (var i = 0; i < vanNumbers.length; i += 10) {
        chunks.add(vanNumbers.sublist(
            i, i + 10 > vanNumbers.length ? vanNumbers.length : i + 10));
      }

      final allImages = <VanImage>[];
      for (final chunk in chunks) {
        final response = await supabase.rpc('get_van_images_batch', params: {
          'p_van_numbers': chunk,
          'p_limit': 1,
          'p_offset': 0,
        });

        if (response.error != null) {
          print(
              '⚠️ Failed to get images for vans $chunk: ${response.error!.message}');
          continue;
        }

        final List<dynamic> data = response.data as List<dynamic>;
        allImages.addAll(data.map((json) => VanImage.fromJson(json)));
      }

      return allImages;
    } catch (e) {
      print('❌ Failed to get latest van images: $e');
      rethrow;
    }
  }

  Future<String> uploadVanImage({
    required int vanNumber,
    required Uint8List imageBytes,
    required String contentType,
    String? vanDamage,
    int? vanRating,
    String vanSide = 'unknown',
    String? damageType,
    String? damageSeverity,
    String? damageLocation,
    String? driverName,
  }) async {
    try {
      // Convert image to base64
      final base64Image = base64Encode(imageBytes);

      // Call the process_van_image function
      final response = await supabase.rpc('save_van_image', params: {
        'p_van_number': vanNumber,
        'p_image_data': base64Image,
        'p_content_type': contentType,
        'p_van_damage': vanDamage,
        'p_van_rating': vanRating,
        'p_van_side': vanSide,
        'p_damage_type': damageType,
        'p_damage_severity': damageSeverity,
        'p_damage_location': damageLocation,
        'p_driver_name': driverName,
      });

      if (response.error != null) {
        throw Exception('Failed to upload image: ${response.error!.message}');
      }

      return response.data as String;
    } catch (e) {
      print('❌ Failed to upload van image: $e');
      rethrow;
    }
  }
}

class VanImage {
  final String id;
  final int vanNumber;
  final String imageUrl;
  final String? imageData;
  final String? contentType;
  final String? vanDamage;
  final int? vanRating;
  final String vanSide;
  final String? damageType;
  final String? damageSeverity;
  final String? damageLocation;
  final DateTime createdAt;
  final DateTime? uploadedAt;
  final String? uploadedBy;
  final String? driverName;
  final String storageType;

  VanImage({
    required this.id,
    required this.vanNumber,
    required this.imageUrl,
    this.imageData,
    this.contentType,
    this.vanDamage,
    this.vanRating,
    this.vanSide = 'unknown',
    this.damageType,
    this.damageSeverity,
    this.damageLocation,
    required this.createdAt,
    this.uploadedAt,
    this.uploadedBy,
    this.driverName,
    required this.storageType,
  });

  factory VanImage.fromJson(Map<String, dynamic> json) {
    return VanImage(
      id: json['id'],
      vanNumber: json['van_number'],
      imageUrl: json['image_url'],
      imageData: json['image_data'],
      contentType: json['content_type'],
      vanDamage: json['van_damage'],
      vanRating: json['van_rating'],
      vanSide: json['van_side'] ?? 'unknown',
      damageType: json['damage_type'],
      damageSeverity: json['damage_severity'],
      damageLocation: json['damage_location'],
      createdAt: DateTime.parse(json['created_at']),
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'])
          : null,
      uploadedBy: json['uploaded_by'],
      driverName: json['driver_name'],
      storageType: json['storage_type'] ?? 'storage-url',
    );
  }

  String getDisplayUrl() {
    if (imageData != null && contentType != null) {
      return 'data:$contentType;base64,$imageData';
    }
    return imageUrl;
  }
}

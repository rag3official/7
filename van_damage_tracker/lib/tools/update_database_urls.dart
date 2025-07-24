import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

// Script to update database with properly formatted Supabase URLs
void main() async {
  try {
    print('🚀 Updating database with proper Supabase storage URLs...');

    // Your Supabase credentials
    final supabaseUrl = Platform.environment['SUPABASE_URL'] ??
        'https://lcvbagsksedduygdzsca.supabase.co';
    final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'] ??
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY2MTI0OTgsImV4cCI6MjAyMjE4ODQ5OH0.vkGmkfzumkRacnhsHm2zx-YKE8uuDojT4ZcJBGdKrfE';

    print('🔗 Using Supabase URL: $supabaseUrl');

    // Create properly formatted Supabase storage URLs for van-images bucket
    final Map<String, String> imageUrlMappings = {
      'https://images.unsplash.com/photo-1570993492881-25240ce854f4?w=800&h=600&fit=crop&auto=format':
          'https://lcvbagsksedduygdzsca.supabase.co/storage/v1/object/public/van-images/van_92/damage_front_bumper_20240322_143021.jpg',
      'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&h=600&fit=crop&auto=format':
          'https://lcvbagsksedduygdzsca.supabase.co/storage/v1/object/public/van-images/van_92/damage_side_panel_20240322_143045.jpg',
      'https://images.unsplash.com/photo-1586244439413-bc2288941dda?w=800&h=600&fit=crop&auto=format':
          'https://lcvbagsksedduygdzsca.supabase.co/storage/v1/object/public/van-images/van_92/damage_rear_door_20240322_143112.jpg',
    };

    // Update each URL mapping
    for (final entry in imageUrlMappings.entries) {
      final oldUrl = entry.key;
      final newUrl = entry.value;

      print('🔄 Updating: $oldUrl → $newUrl');

      // Update van_images table
      final updateResponse = await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/van_images'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({
          'image_url': newUrl,
        }),
      );

      if (updateResponse.statusCode == 200 ||
          updateResponse.statusCode == 204) {
        print('✅ Successfully updated URLs in database');
      } else {
        print(
            '❌ Failed to update URLs: ${updateResponse.statusCode} - ${updateResponse.body}');
      }
    }

    print('🎉 Database URL update completed!');
  } catch (e) {
    print('❌ Error updating database URLs: $e');
  }
}

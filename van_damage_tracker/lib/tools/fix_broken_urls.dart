import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

// Simple script to fix broken image URLs in the database
void main() async {
  try {
    // Load environment variables
    final supabaseUrl = Platform.environment['SUPABASE_URL'];
    final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseKey == null) {
      print('❌ Missing environment variables');
      return;
    }

    // Initialize Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );

    final supabase = Supabase.instance.client;

    print('🔧 Fixing broken image URLs...');

    // Update broken Supabase storage URLs to working placeholders
    final response = await supabase
        .from('van_images')
        .update({
          'image_url':
              'https://images.unsplash.com/photo-1570993492881-25240ce854f4?w=800&h=600&fit=crop&auto=format'
        })
        .like('image_url', '%supabase.co%')
        .select();

    print('✅ Updated ${response.length} image URLs');

    // Verify the update
    final verifyResponse = await supabase
        .from('van_images')
        .select('id, image_url, damage_type, damage_level')
        .limit(5);

    print('📋 Sample updated records:');
    for (var record in verifyResponse) {
      print(
          '  ID: ${record['id']}, URL: ${record['image_url']?.substring(0, 50)}...');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  try {
    print('🔍 Checking van_images database table...');

    // Initialize Supabase
    await dotenv.load(fileName: '.env');

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ??
          'https://lcvbagsksedduygdzsca.supabase.co',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ??
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY2MTI0OTgsImV4cCI6MjAyMjE4ODQ5OH0.vkGmkfzumkRacnhsHm2zx-YKE8uuDojT4ZcJBGdKrfE',
    );

    final supabase = Supabase.instance.client;

    // Check van_images table
    print('\n📊 Checking van_images table...');
    try {
      final imagesResponse = await supabase
          .from('van_images')
          .select(
              'id, van_id, image_url, driver_id, damage_type, damage_level, created_at')
          .limit(10);

      print('✅ Found ${imagesResponse.length} records in van_images table');

      for (int i = 0; i < imagesResponse.length; i++) {
        final image = imagesResponse[i];
        print(
            '   📷 Image ${i + 1}: Van=${image['van_id']}, URL=${image['image_url']}, Damage=${image['damage_type']}');
      }

      if (imagesResponse.isEmpty) {
        print('⚠️ No images found in database - table is empty');
      }
    } catch (e) {
      print('❌ Error querying van_images: $e');
    }

    // Check vans table
    print('\n🚐 Checking vans table...');
    try {
      final vansResponse = await supabase
          .from('vans')
          .select('id, van_number, type, main_image_url')
          .limit(5);

      print('✅ Found ${vansResponse.length} records in vans table');

      for (int i = 0; i < vansResponse.length; i++) {
        final van = vansResponse[i];
        print(
            '   🚐 Van ${i + 1}: #${van['van_number']}, Type=${van['type']}, MainImage=${van['main_image_url']}');
      }
    } catch (e) {
      print('❌ Error querying vans: $e');
    }

    print('\n✅ Database check completed!');
  } catch (e) {
    print('❌ Error during database check: $e');
  }
}

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  final supabase = Supabase.instance.client;
  
  print('🔍 Testing database connection...');
  
  try {
    // Test driver_profiles table
    print('\n📋 Checking driver_profiles...');
    final drivers = await supabase.from('driver_profiles').select().limit(5);
    print('Found ${drivers.length} drivers:');
    for (final driver in drivers) {
      print('  - ${driver['driver_name']} (ID: ${driver['id']})');
    }
    
    // Test van_images table
    print('\n📷 Checking van_images...');
    final images = await supabase.from('van_images').select().limit(5);
    print('Found ${images.length} images:');
    for (final image in images) {
      print('  - Van ${image['van_number']}, Driver: ${image['driver_id']}, Has data: ${image['image_data'] != null}');
    }
    
    // Test van_profiles table
    print('\n🚐 Checking van_profiles...');
    final vans = await supabase.from('van_profiles').select().limit(5);
    print('Found ${vans.length} van profiles:');
    for (final van in vans) {
      print('  - Van ${van['van_number']}: ${van['make']} ${van['model']}');
    }
    
    // Test specific driver query
    if (drivers.isNotEmpty) {
      final testDriverId = drivers.first['id'];
      print('\n🔍 Testing images for driver: $testDriverId');
      
      final driverImages = await supabase
          .from('van_images')
          .select('''
            id,
            van_number,
            van_id,
            image_data,
            image_url,
            van_damage,
            van_rating,
            created_at,
            uploaded_by,
            file_size,
            content_type,
            van_profiles!van_images_van_id_fkey (
              id,
              van_number,
              make,
              model,
              status
            )
          ''')
          .eq('driver_id', testDriverId);
          
      print('Found ${driverImages.length} images for this driver');
      for (final img in driverImages) {
        print('  - Van ${img['van_number']}: ${img['van_damage'] ?? 'No damage'}, has_data: ${img['image_data'] != null}');
      }
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\n✅ Database test complete');
}

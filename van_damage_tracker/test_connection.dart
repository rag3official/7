import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  print('🔌 Testing Supabase connection...');

  // Initialize Supabase
  final supabaseUrl = Platform.environment['SUPABASE_URL'] ??
      'https://lcvbagsksedduygdzsca.supabase.co';
  final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI0MDM0NDMsImV4cCI6MjA0Nzk3OTQ0M30.iSKhBnL9lGqJmDKzjjFSBQgmfNbCMOOjSYzGQ3jqzpQ';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  final supabase = Supabase.instance.client;

  try {
    print('📊 Testing database tables...');

    // Test driver_profiles table
    print('🔍 Checking driver_profiles table...');
    final driversResponse =
        await supabase.from('driver_profiles').select('*').limit(5);
    print('✅ driver_profiles: ${driversResponse.length} records found');

    // Test van_profiles table
    print('🔍 Checking van_profiles table...');
    final vansResponse =
        await supabase.from('van_profiles').select('*').limit(5);
    print('✅ van_profiles: ${vansResponse.length} records found');

    // Test van_images table
    print('🔍 Checking van_images table...');
    final imagesResponse =
        await supabase.from('van_images').select('*').limit(5);
    print('✅ van_images: ${imagesResponse.length} records found');

    // Test join query (what the Flutter app will do)
    print('🔍 Testing join query...');
    final joinResponse = await supabase.from('van_profiles').select('''
          *,
          driver_profiles!van_profiles_current_driver_id_fkey(driver_name),
          van_images(id, image_url, van_damage, van_rating, created_at)
        ''').limit(3);

    print('✅ Join query successful: ${joinResponse.length} records');

    if (joinResponse.isNotEmpty) {
      print('📋 Sample data:');
      for (var van in joinResponse) {
        print('  Van #${van['van_number']}: ${van['make']} ${van['model']}');
        if (van['driver_profiles'] != null) {
          print('    Driver: ${van['driver_profiles']['driver_name']}');
        }
        if (van['van_images'] != null && van['van_images'].isNotEmpty) {
          print('    Images: ${van['van_images'].length}');
        }
      }
    }

    print('');
    print('🎉 All tests passed! The Flutter app should work correctly.');
    print('');
    print('Next steps:');
    print('1. Run: cd van_damage_tracker && flutter run -d chrome');
    print('2. Test the Slack bot: python database_only_bot.py');
  } catch (e) {
    print('❌ Error: $e');
    print('');
    print('🔧 Troubleshooting:');
    print('1. Make sure the unified_database_schema.sql has been applied');
    print(
        '2. Check your SUPABASE_URL and SUPABASE_ANON_KEY environment variables');
    print('3. Verify the tables exist in your Supabase dashboard');
  }
}

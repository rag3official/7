import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/environment.dart';

// Simple tool to run database migrations
void main() async {
  print('🔧 Starting database migration...');

  // Initialize Supabase
  await Supabase.initialize(
    url: Environment.supabaseUrl,
    anonKey: Environment.supabaseAnonKey,
  );

  final client = Supabase.instance.client;

  try {
    // Read the migration SQL file
    final migrationFile =
        File('migrations/20240322000020_fix_van_images_structure.sql');
    if (!await migrationFile.exists()) {
      print('❌ Migration file not found: ${migrationFile.path}');
      exit(1);
    }

    final migrationSQL = await migrationFile.readAsString();
    print('📄 Loaded migration SQL (${migrationSQL.length} characters)');

    // Execute the migration
    print('🚀 Executing migration...');
    final result = await client.rpc('exec_sql', params: {'sql': migrationSQL});

    print('✅ Migration completed successfully!');
    print('📊 Result: $result');

    // Test the van_images query to verify the fix
    print('🧪 Testing van_images query...');
    final testResult = await client
        .from('van_images')
        .select(
            'id, van_id, image_url, driver_id, damage_type, damage_level, location, created_at, updated_at, uploaded_at, description, driver_name')
        .limit(5);

    print('✅ Test query successful! Found ${testResult.length} records');
    for (int i = 0; i < testResult.length; i++) {
      final record = testResult[i];
      print(
          '  Image $i: ${record['damage_type']} (Level ${record['damage_level']}) by ${record['driver_name']}');
    }
  } catch (e) {
    print('❌ Migration failed: $e');
    exit(1);
  }

  print('🎉 Database migration completed successfully!');
  exit(0);
}

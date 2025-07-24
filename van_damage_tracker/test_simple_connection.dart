import 'dart:io';

void main() async {
  print('🔌 Testing Supabase connection...');

  final supabaseUrl = Platform.environment['SUPABASE_URL'] ??
      'https://lcvbagsksedduygdzsca.supabase.co';
  final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI0MDM0NDMsImV4cCI6MjA0Nzk3OTQ0M30.iSKhBnL9lGqJmDKzjjFSBQgmfNbCMOOjSYzGQ3jqzpQ';

  print('📡 Supabase URL: $supabaseUrl');
  print('🔑 Using anon key: ${supabaseKey.substring(0, 20)}...');

  print('');
  print('⚠️  Current Issue:');
  print('   The Flutter app is trying to fetch from "vans" table');
  print('   But the database has "van_profiles" table instead');
  print('');
  print('🔧 Solutions:');
  print('   1. Apply the quick_fix_schema.sql in Supabase Dashboard');
  print('   2. Or update Flutter app to use "van_profiles" table');
  print('');
  print('📋 To apply the schema:');
  print('   1. Open Supabase Dashboard → SQL Editor');
  print('   2. Copy contents of quick_fix_schema.sql');
  print('   3. Run the SQL to create the tables');
  print('');
  print('🚀 After applying schema, the Flutter app should work!');
}

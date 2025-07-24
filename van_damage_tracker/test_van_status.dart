import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Simple test script to debug van status issues
// Run this to check if van #215 exists and can be updated

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (replace with your actual credentials)
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  await testVanStatusUpdate();
}

Future<void> testVanStatusUpdate() async {
  final supabase = Supabase.instance.client;
  const vanNumber = 215;

  print('🔍 Testing van status update for van #$vanNumber');

  try {
    // 1. Check if van exists
    print('1. Checking if van #$vanNumber exists...');
    final existingVan = await supabase
        .from('van_profiles')
        .select('id, van_number, status, make, model')
        .eq('van_number', vanNumber)
        .maybeSingle();

    if (existingVan == null) {
      print('❌ Van #$vanNumber NOT FOUND in database');

      // List all vans to see what's available
      print('\n📋 Available vans in database:');
      final allVans = await supabase
          .from('van_profiles')
          .select('van_number, status, make, model')
          .order('van_number');

      for (final van in allVans) {
        print(
            '   Van #${van['van_number']}: ${van['make']} ${van['model']} - Status: ${van['status']}');
      }
      return;
    }

    print('✅ Van #$vanNumber found:');
    print('   ID: ${existingVan['id']}');
    print('   Make/Model: ${existingVan['make']} ${existingVan['model']}');
    print('   Current Status: ${existingVan['status']}');

    // 2. Test status constraint
    print('\n2. Checking status constraint...');
    final validStatuses = ['active', 'maintenance', 'out_of_service'];
    final currentStatus = existingVan['status']?.toString() ?? 'unknown';

    if (!validStatuses.contains(currentStatus)) {
      print(
          '⚠️ Current status "$currentStatus" is not in valid list: $validStatuses');
    }

    // 3. Try to update status (toggle between active and maintenance)
    print('\n3. Testing status update...');
    final newStatus = currentStatus == 'active' ? 'maintenance' : 'active';

    print('   Attempting to update from "$currentStatus" to "$newStatus"...');

    final updateResponse = await supabase
        .from('van_profiles')
        .update({
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
          'notes': 'Test update from debug script',
        })
        .eq('van_number', vanNumber)
        .select();

    if (updateResponse.isNotEmpty) {
      print('✅ Status update successful!');
      print('   New status: ${updateResponse.first['status']}');
      print('   Updated at: ${updateResponse.first['updated_at']}');

      // Revert back to original status
      await supabase.from('van_profiles').update({
        'status': currentStatus,
        'updated_at': DateTime.now().toIso8601String(),
        'notes': null,
      }).eq('van_number', vanNumber);

      print('   Reverted back to original status: $currentStatus');
    } else {
      print('❌ Status update failed - no rows affected');
    }
  } catch (e) {
    print('❌ Error during test: $e');
    if (e is PostgrestException) {
      print('   PostgrestException details:');
      print('   Message: ${e.message}');
      print('   Code: ${e.code}');
      print('   Details: ${e.details}');
      print('   Hint: ${e.hint}');
    }
  }
}

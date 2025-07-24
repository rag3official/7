// Simple test script to debug van status update
// Run this to test status updates directly

import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
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
    // 1. Check current status
    print('\n1. Getting current van data...');
    final currentVan = await supabase
        .from('van_profiles')
        .select('van_number, status, id, updated_at')
        .eq('van_number', vanNumber)
        .maybeSingle();

    if (currentVan == null) {
      print('❌ Van #$vanNumber not found!');
      return;
    }

    print('✅ Current van data: $currentVan');
    final currentStatus = currentVan['status'];
    final vanId = currentVan['id'];

    // 2. Try to update status
    print('\n2. Attempting to update status...');
    final newStatus = currentStatus == 'active' ? 'maintenance' : 'active';

    print('   Changing from "$currentStatus" to "$newStatus"');

    final updateResponse = await supabase
        .from('van_profiles')
        .update({
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', vanId)
        .select('van_number, status, updated_at');

    print('✅ Update response: $updateResponse');

    if (updateResponse.isEmpty) {
      print('❌ Update failed - no rows returned');
      return;
    }

    // 3. Verify the change
    print('\n3. Verifying the change...');
    final verifyResponse = await supabase
        .from('van_profiles')
        .select('van_number, status, updated_at')
        .eq('van_number', vanNumber)
        .single();

    print('✅ Verification: $verifyResponse');

    if (verifyResponse['status'] != newStatus) {
      print(
          '❌ PROBLEM: Status should be "$newStatus" but is "${verifyResponse['status']}"');
    } else {
      print('✅ SUCCESS: Status correctly updated to "$newStatus"');
    }

    // 4. Revert back
    print('\n4. Reverting back to original status...');
    await supabase.from('van_profiles').update({
      'status': currentStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('van_number', vanNumber);

    print('✅ Reverted back to original status: $currentStatus');
  } catch (e) {
    print('❌ Error during test: $e');
    if (e is PostgrestException) {
      print('   Message: ${e.message}');
      print('   Code: ${e.code}');
      print('   Details: ${e.details}');
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:van_damage_tracker/services/supabase_service.dart';
import 'package:van_damage_tracker/config/environment.dart';

void main() {
  group('Supabase Connection Test', () {
    late SupabaseService supabaseService;

    setUpAll(() async {
      // Initialize environment before tests
      await Environment.initialize();
    });

    setUp(() {
      supabaseService = SupabaseService();
    });

    test('should connect to database and fetch van profiles', () async {
      try {
        // Test fetching vans from new schema
        final vans = await supabaseService.fetchVans();

        print('✅ Successfully connected to database');
        print('📊 Found ${vans.length} van profiles');

        if (vans.isNotEmpty) {
          final firstVan = vans.first;
          print('🚐 First van: ${firstVan.plateNumber} (${firstVan.model})');
          print('👤 Driver: ${firstVan.driverName ?? 'No driver'}');
          print('📸 Images: ${firstVan.images.length}');
        }

        // Test should pass if no exception is thrown
        expect(vans, isA<List>());
      } catch (e) {
        print('❌ Database connection failed: $e');

        // If it's the old "relation public.vans does not exist" error,
        // this means the service is still trying to use the old schema
        if (e.toString().contains('relation "public.vans" does not exist')) {
          fail(
              'Service is still using old schema - needs to be updated to use van_profiles');
        }

        // Re-throw other errors
        rethrow;
      }
    });

    test('should get dashboard stats from new schema', () async {
      try {
        final stats = await supabaseService.getDashboardStats();

        print('📈 Dashboard stats:');
        print('   Total vans: ${stats['total_vans']}');
        print('   Active vans: ${stats['active_vans']}');
        print('   Total images: ${stats['total_images']}');
        print('   Total drivers: ${stats['total_drivers']}');

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('total_vans'), isTrue);
      } catch (e) {
        print('❌ Dashboard stats failed: $e');
        rethrow;
      }
    });
  });
}

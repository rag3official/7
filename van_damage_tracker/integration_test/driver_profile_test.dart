import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:van_damage_tracker/models/driver_profile.dart';
import 'package:van_damage_tracker/services/driver_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('DriverProfile Model', () {
    test('should create DriverProfile from JSON', () {
      final json = {
        'id': '123',
        'user_id': '456',
        'name': 'John Doe',
        'license_number': 'ABC123',
        'license_expiry': '2025-01-01',
        'phone_number': '123-456-7890',
        'email': 'john@example.com',
        'medical_check_date': '2024-01-01',
        'certifications': ['Class A', 'Class B'],
        'status': 'active',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      final profile = DriverProfile.fromJson(json);

      expect(profile.id, '123');
      expect(profile.userId, '456');
      expect(profile.name, 'John Doe');
      expect(profile.licenseNumber, 'ABC123');
      expect(profile.licenseExpiry.year, 2025);
      expect(profile.phoneNumber, '123-456-7890');
      expect(profile.email, 'john@example.com');
      expect(profile.medicalCheckDate?.year, 2024);
      expect(profile.certifications, ['Class A', 'Class B']);
      expect(profile.status, 'active');
    });

    test('should convert DriverProfile to JSON', () {
      final profile = DriverProfile(
        id: '123',
        userId: '456',
        name: 'John Doe',
        licenseNumber: 'ABC123',
        licenseExpiry: DateTime(2025, 1, 1),
        phoneNumber: '123-456-7890',
        email: 'john@example.com',
        medicalCheckDate: DateTime(2024, 1, 1),
        certifications: ['Class A', 'Class B'],
        status: 'active',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final json = profile.toJson();

      expect(json['id'], '123');
      expect(json['user_id'], '456');
      expect(json['name'], 'John Doe');
      expect(json['license_number'], 'ABC123');
      expect(json['license_expiry'], '2025-01-01T00:00:00.000');
      expect(json['phone_number'], '123-456-7890');
      expect(json['email'], 'john@example.com');
      expect(json['medical_check_date'], '2024-01-01T00:00:00.000');
      expect(json['certifications'], ['Class A', 'Class B']);
      expect(json['status'], 'active');
    });
  });

  group('DriverService', () {
    late DriverService driverService;
    late SupabaseClient supabase;

    setUpAll(() async {
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
        debug: true,
      );
      supabase = Supabase.instance.client;
      driverService = DriverService();
    });

    tearDownAll(() async {
      await Supabase.instance.dispose();
    });

    test('should initialize database', () async {
      final result = await driverService.initializeDatabase();
      expect(result, true);
    });

    test('should get current user profile when authenticated', () async {
      // Sign in first (you'll need to create a test user)
      const email = 'testdriver@test.com';
      const password = 'testpassword123';

      try {
        await supabase.auth.signUp(
          email: email,
          password: password,
        );
      } catch (e) {
        // If user already exists, just sign in
        if (e is AuthException && e.statusCode == 400) {
          print('User already exists, signing in...');
        } else {
          rethrow;
        }
      }

      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final profile = await driverService.getCurrentUserProfile();
      expect(profile, isNull); // Initially null as no profile exists
    });

    test('should create and retrieve driver profile', () async {
      final user = supabase.auth.currentUser;
      expect(user, isNotNull);

      final newDriver = DriverProfile(
        id: 'new_id',
        userId: user!.id,
        name: 'Test Driver',
        licenseNumber: 'TEST123',
        licenseExpiry: DateTime.now().add(const Duration(days: 365)),
        phoneNumber: '555-0123',
        email: 'testdriver@test.com',
        status: 'active',
        certifications: ['Test Cert'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createdDriver = await driverService.createDriver(newDriver);
      expect(createdDriver.name, 'Test Driver');

      final retrievedDriver = await driverService.getDriver(createdDriver.id);
      expect(retrievedDriver?.name, 'Test Driver');
    });
  });
}

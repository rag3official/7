import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Environment configuration for the app
class Environment {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await dotenv.load(fileName: '.env');
      _initialized = true;
    } catch (e) {
      debugPrint('Error loading environment variables: $e');
      rethrow;
    }
  }

  // Supabase configuration
  static String get supabaseUrl {
    _checkInitialization();
    return dotenv.env['SUPABASE_URL'] ?? '';
  }

  static String get supabaseAnonKey {
    _checkInitialization();
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  static bool get isValid {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }

  static void _checkInitialization() {
    if (!_initialized) {
      throw StateError(
          'Environment not initialized. Call Environment.initialize() first.');
    }
  }
}

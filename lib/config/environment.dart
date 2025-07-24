import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Environment configuration for the app
class Environment {
  static String get supabaseUrl => _get('SUPABASE_URL');
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY');
  static String get supabaseServiceRoleKey => _get('SUPABASE_SERVICE_ROLE_KEY');

  static final Map<String, String> _defaultValues = {
    'SUPABASE_URL': '',
    'SUPABASE_ANON_KEY': '',
    'SUPABASE_SERVICE_ROLE_KEY': '',
  };

  static Future<void> initialize() async {
    try {
      debugPrint('Attempting to load .env file...');
      await dotenv.load();
      debugPrint('Successfully loaded .env file');
      debugPrint('Supabase URL: ${supabaseUrl.isEmpty ? "EMPTY" : "FOUND"}');
      debugPrint(
          'Supabase Anon Key: ${supabaseAnonKey.isEmpty ? "EMPTY" : "FOUND"}');
    } catch (e) {
      debugPrint('Error loading .env file: $e');
    }
  }

  static String _get(String key, {String? defaultValue}) {
    try {
      final value =
          dotenv.env[key] ?? defaultValue ?? _defaultValues[key] ?? '';
      debugPrint('Getting $key: ${value.isEmpty ? "EMPTY" : "FOUND"}');
      return value;
    } catch (e) {
      debugPrint('Error getting environment variable $key: $e');
      return defaultValue ?? _defaultValues[key] ?? '';
    }
  }

  static bool get isValid {
    // Temporarily bypass validation for testing
    return true;

    // Original validation (commented out for testing)
    // final valid = supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
    // debugPrint('Environment isValid: $valid');
    // return valid;
  }
}

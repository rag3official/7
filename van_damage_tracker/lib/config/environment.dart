import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Environment configuration for the app
class Environment {
  static bool _initialized = false;

  // TODO: Replace these values with your actual Supabase credentials
  // To get these values:
  // 1. Go to https://supabase.com and log in
  // 2. Open your project (or create a new one)
  // 3. Go to Project Settings -> API
  // 4. Copy the "Project URL" and "anon/public" key
  static final Map<String, String> _defaultValues = {
    'SUPABASE_URL': kDebugMode
        ? 'https://lcvbagsksedduygdzsca.supabase.co' // Replace with your Project URL (e.g., https://abcdefg.supabase.co)
        : '',
    'SUPABASE_ANON_KEY': kDebugMode
        ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ4NTY5NzEsImV4cCI6MjA2MDQzMjk3MX0.4zHHqDOCFjIyHjKSWnJP_QF5J6gKJfvl5CzHYnKj7lE' // Replace with your anon/public key (starts with 'eyJ...')
        : '',
    'SUPABASE_SERVICE_KEY': '',
    'APP_NAME': 'Van Damage Tracker',
  };

  // Supabase configuration
  static String get supabaseUrl {
    _checkInitialization();
    final url = _getEnvValue('SUPABASE_URL');
    if (url.isEmpty && kDebugMode) {
      throw Exception(
          'Please set a valid SUPABASE_URL in the Environment class');
    }
    return url;
  }

  static String get supabaseAnonKey {
    _checkInitialization();
    final key = _getEnvValue('SUPABASE_ANON_KEY');
    if (key.isEmpty && kDebugMode) {
      throw Exception(
          'Please set a valid SUPABASE_ANON_KEY in the Environment class');
    }
    return key;
  }

  static String get storageBucket {
    _checkInitialization();
    return _getEnvValue('SUPABASE_STORAGE_BUCKET', defaultValue: 'van-images');
  }

  static String get supabaseServiceKey {
    _checkInitialization();
    return _getEnvValue('SUPABASE_SERVICE_KEY');
  }

  // Google Sheets configuration
  static const String sheetsApiKey = 'YOUR_SHEETS_API_KEY';
  static const String sheetsClientId = 'YOUR_SHEETS_CLIENT_ID';
  static const String spreadsheetsId = 'YOUR_SPREADSHEET_ID';

  // Feature flags
  static const bool enableRealTimeUpdates = true;
  static const bool enableOfflineMode = false;

  // App configuration
  static String get appName {
    _checkInitialization();
    return _getEnvValue('APP_NAME', defaultValue: 'Van Damage Tracker');
  }

  static const String appVersion = '1.0.0';
  static const int cacheExpiryMinutes = 60;

  static Future<void> initialize() async {
    try {
      if (!kDebugMode) {
        await dotenv.load();
        debugPrint('Environment variables loaded successfully');
      } else {
        debugPrint('Running in debug mode with development configuration');
      }
    } catch (e) {
      debugPrint('Warning: .env file not found, using default values');
    }
    _initialized = true;
  }

  static String _getEnvValue(String key, {String? defaultValue}) {
    if (!_initialized) {
      throw StateError(
          'Environment not initialized. Call Environment.initialize() first.');
    }

    try {
      if (kDebugMode) {
        // In debug mode, always use default values
        return defaultValue ?? _defaultValues[key] ?? '';
      }

      // In production, try to get from .env first
      final value =
          dotenv.env[key] ?? defaultValue ?? _defaultValues[key] ?? '';
      if (value.isEmpty) {
        debugPrint('Warning: Environment variable $key is empty');
      }
      return value;
    } catch (e) {
      debugPrint('Error getting environment variable $key: $e');
      return defaultValue ?? _defaultValues[key] ?? '';
    }
  }

  static void _checkInitialization() {
    if (!_initialized) {
      throw StateError(
          'Environment not initialized. Call Environment.initialize() first.');
    }
  }

  static bool get isValid {
    try {
      return supabaseUrl.isNotEmpty &&
          supabaseAnonKey.isNotEmpty &&
          supabaseUrl != 'https://xyzcompany.supabase.co';
    } catch (e) {
      return false;
    }
  }

  // Method to update environment values at runtime (for development/testing)
  static void setEnvironmentValue(String key, String value) {
    if (kDebugMode) {
      _defaultValues[key] = value;
    }
  }
}
